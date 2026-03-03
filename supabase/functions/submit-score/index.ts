import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const minReasonableSeconds: Record<string, number> = {
  sudoku: 60,
  queens: 30,
};

const maxSubmissionsPerFiveMinutes = 30;
const maxDailyAttemptsPerPuzzle = 80;
const maxBestSeconds = 24 * 60 * 60;
const hintPenaltySeconds = 20;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return json(401, { error: 'Missing Authorization header' });
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');
    const supabaseServiceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRole) {
      return json(500, { error: 'Server env is missing Supabase config' });
    }

    const authClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    });

    const {
      data: { user },
      error: userError,
    } = await authClient.auth.getUser();

    if (userError || !user) {
      return json(401, { error: 'Invalid user session' });
    }

    const adminClient = createClient(supabaseUrl, supabaseServiceRole);

    const body = await req.json();
    const puzzleId = String(body.puzzle_id ?? '').trim();
    const type = String(body.type ?? '').trim().toLowerCase();
    const completed = Boolean(body.completed ?? false);
    const bestSeconds = Number(body.best_seconds ?? 0);
    const streakDays = Number(body.streak_days ?? 0);
    const hintsUsed = Number(body.hints_used ?? 0);

    const reject = async (status: number, reasonCode: string, error: string): Promise<Response> => {
      await logSubmissionEvent(adminClient, {
        userId: user.id,
        puzzleId,
        type,
        completed,
        bestSeconds,
        streakDays,
        hintsUsed,
        accepted: false,
        reasonCode,
      });
      return json(status, { error, reason_code: reasonCode });
    };

    if (!puzzleId || !type) {
      return await reject(400, 'missing_fields', 'Missing puzzle_id or type');
    }

    if (!Number.isInteger(bestSeconds) || !Number.isInteger(streakDays) || !Number.isInteger(hintsUsed)) {
      return await reject(400, 'invalid_integer_fields', 'best_seconds, streak_days and hints_used must be integers');
    }

    if (bestSeconds < 0 || bestSeconds > maxBestSeconds || streakDays < 0 || streakDays > 36500 || hintsUsed < 0 || hintsUsed > 10000) {
      return await reject(400, 'invalid_ranges', 'Invalid range for score payload');
    }

    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000).toISOString();
    const { count: recentCount, error: recentCountError } = await adminClient
      .from('score_submission_events')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .gte('created_at', fiveMinutesAgo);

    if (recentCountError) {
      return json(500, { error: 'Failed to enforce rate limit' });
    }

    if ((recentCount ?? 0) >= maxSubmissionsPerFiveMinutes) {
      return await reject(429, 'rate_limit', 'Too many submissions. Try again shortly.');
    }

    const startOfDay = new Date();
    startOfDay.setUTCHours(0, 0, 0, 0);
    const { count: dailyPuzzleCount, error: dailyCountError } = await adminClient
      .from('score_submission_events')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .eq('puzzle_id', puzzleId)
      .gte('created_at', startOfDay.toISOString());

    if (dailyCountError) {
      return json(500, { error: 'Failed to enforce daily cap' });
    }

    if ((dailyPuzzleCount ?? 0) >= maxDailyAttemptsPerPuzzle) {
      return await reject(429, 'daily_cap', 'Daily attempt cap reached for this puzzle');
    }

    const minSeconds = minReasonableSeconds[type];
    if (completed && minSeconds && bestSeconds > 0 && bestSeconds < minSeconds) {
      return await reject(422, 'too_fast', 'Submitted completion time is not realistic');
    }

    const { data: puzzleRow, error: puzzleError } = await adminClient
      .from('puzzles')
      .select('id, type')
      .eq('id', puzzleId)
      .maybeSingle();

    if (puzzleError) {
      return json(500, { error: 'Failed to load puzzle metadata' });
    }

    if (!puzzleRow || puzzleRow.type !== type) {
      return await reject(400, 'puzzle_type_mismatch', 'Puzzle does not match submitted type');
    }

    const { data: existingRow } = await adminClient
      .from('user_progress')
      .select('completed, best_seconds, streak_days, hints_used')
      .eq('user_id', user.id)
      .eq('puzzle_id', puzzleId)
      .maybeSingle();

    const existingStreak = Number(existingRow?.streak_days ?? 0);
    if (streakDays > existingStreak + 1) {
      return await reject(422, 'streak_jump', 'Streak increase is too large for one submission');
    }

    const mergedCompleted = completed || Boolean(existingRow?.completed);

    const existingBestSeconds = Number(existingRow?.best_seconds ?? 0);
    const existingHintsUsed = Number(existingRow?.hints_used ?? 0);

    const mergedBest = pickBestResult(
      existingBestSeconds,
      existingHintsUsed,
      bestSeconds,
      hintsUsed,
      mergedCompleted,
    );

    const mergedStreakDays = Math.max(existingStreak, streakDays);

    const { error: upsertError } = await adminClient.from('user_progress').upsert(
      {
        user_id: user.id,
        puzzle_id: puzzleId,
        type,
        completed: mergedCompleted,
        best_seconds: mergedBest.bestSeconds,
        hints_used: mergedBest.hintsUsed,
        streak_days: mergedStreakDays,
      },
      { onConflict: 'user_id,puzzle_id' },
    );

    if (upsertError) {
      return json(500, { error: 'Failed to persist score' });
    }

    await logSubmissionEvent(adminClient, {
      userId: user.id,
      puzzleId,
      type,
      completed,
      bestSeconds,
      streakDays,
      hintsUsed,
      accepted: true,
      reasonCode: 'accepted',
    });

    return json(200, {
      ok: true,
      progress: {
        puzzle_id: puzzleId,
        completed: mergedCompleted,
        best_seconds: mergedBest.bestSeconds,
        hints_used: mergedBest.hintsUsed,
        streak_days: mergedStreakDays,
      },
    });
  } catch (error) {
    return json(500, {
      error: 'Unhandled error in submit-score',
      detail: error instanceof Error ? error.message : String(error),
    });
  }
});

type SubmissionLog = {
  userId: string;
  puzzleId: string;
  type: string;
  completed: boolean;
  bestSeconds: number;
  streakDays: number;
  hintsUsed: number;
  accepted: boolean;
  reasonCode: string;
};

type BestResult = {
  bestSeconds: number;
  hintsUsed: number;
};

async function logSubmissionEvent(
  adminClient: ReturnType<typeof createClient>,
  payload: SubmissionLog,
): Promise<void> {
  await adminClient.from('score_submission_events').insert({
    user_id: payload.userId,
    puzzle_id: payload.puzzleId,
    type: payload.type,
    completed: payload.completed,
    best_seconds: payload.bestSeconds,
    streak_days: payload.streakDays,
    hints_used: payload.hintsUsed,
    accepted: payload.accepted,
    reason_code: payload.reasonCode,
  });
}

function pickBestResult(
  existingSeconds: number,
  existingHints: number,
  submittedSeconds: number,
  submittedHints: number,
  completed: boolean,
): BestResult {
  if (!completed) {
    return {
      bestSeconds: Number.isInteger(existingSeconds) && existingSeconds > 0 ? existingSeconds : 0,
      hintsUsed: Number.isInteger(existingHints) && existingHints >= 0 ? existingHints : 0,
    };
  }

  if (!Number.isInteger(submittedSeconds) || submittedSeconds <= 0) {
    return {
      bestSeconds: Number.isInteger(existingSeconds) && existingSeconds > 0 ? existingSeconds : 0,
      hintsUsed: Number.isInteger(existingHints) && existingHints >= 0 ? existingHints : 0,
    };
  }

  const normalizedExistingSeconds = Number.isInteger(existingSeconds) && existingSeconds > 0 ? existingSeconds : 0;
  const normalizedExistingHints = Number.isInteger(existingHints) && existingHints >= 0 ? existingHints : 0;

  if (normalizedExistingSeconds == 0) {
    return { bestSeconds: submittedSeconds, hintsUsed: Math.max(0, submittedHints) };
  }

  const existingEffective = effectiveScore(normalizedExistingSeconds, normalizedExistingHints);
  const submittedEffective = effectiveScore(submittedSeconds, Math.max(0, submittedHints));

  if (submittedEffective < existingEffective) {
    return { bestSeconds: submittedSeconds, hintsUsed: Math.max(0, submittedHints) };
  }

  return { bestSeconds: normalizedExistingSeconds, hintsUsed: normalizedExistingHints };
}

function effectiveScore(seconds: number, hints: number): number {
  return seconds + hints * hintPenaltySeconds;
}

function json(status: number, payload: Record<string, unknown>): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}
