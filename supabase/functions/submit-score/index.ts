import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const minReasonableSeconds: Record<string, number> = {
  sudoku: 60,
  queens: 30,
};

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

    if (!puzzleId || !type) {
      return json(400, { error: 'Missing puzzle_id or type' });
    }

    if (!Number.isInteger(bestSeconds) || !Number.isInteger(streakDays)) {
      return json(400, { error: 'best_seconds and streak_days must be integers' });
    }

    if (bestSeconds < 0 || streakDays < 0 || streakDays > 36500) {
      return json(400, { error: 'Invalid range for score payload' });
    }

    const minSeconds = minReasonableSeconds[type];
    if (completed && minSeconds && bestSeconds > 0 && bestSeconds < minSeconds) {
      return json(422, { error: 'Submitted completion time is not realistic' });
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
      return json(400, { error: 'Puzzle does not match submitted type' });
    }

    const { data: existingRow } = await adminClient
      .from('user_progress')
      .select('completed, best_seconds, streak_days')
      .eq('user_id', user.id)
      .eq('puzzle_id', puzzleId)
      .maybeSingle();

    const mergedCompleted = completed || Boolean(existingRow?.completed);
    const mergedBestSeconds = mergedCompleted
      ? pickBestSeconds(existingRow?.best_seconds, bestSeconds)
      : 0;
    const mergedStreakDays = Math.max(Number(existingRow?.streak_days ?? 0), streakDays);

    const { error: upsertError } = await adminClient.from('user_progress').upsert(
      {
        user_id: user.id,
        puzzle_id: puzzleId,
        type,
        completed: mergedCompleted,
        best_seconds: mergedBestSeconds,
        streak_days: mergedStreakDays,
      },
      { onConflict: 'user_id,puzzle_id' },
    );

    if (upsertError) {
      return json(500, { error: 'Failed to persist score' });
    }

    return json(200, {
      ok: true,
      progress: {
        puzzle_id: puzzleId,
        completed: mergedCompleted,
        best_seconds: mergedBestSeconds,
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

function pickBestSeconds(existing: unknown, submitted: number): number {
  const existingValue = Number(existing ?? 0);
  if (!Number.isInteger(submitted) || submitted <= 0) {
    return Number.isInteger(existingValue) && existingValue > 0 ? existingValue : 0;
  }
  if (!Number.isInteger(existingValue) || existingValue <= 0) {
    return submitted;
  }
  return Math.min(existingValue, submitted);
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
