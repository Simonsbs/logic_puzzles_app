import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-admin-secret',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const expectedSecret = Deno.env.get('ADMIN_MANAGER_SECRET') ?? '';
    const providedSecret = req.headers.get('x-admin-secret') ?? '';
    if (!expectedSecret || providedSecret !== expectedSecret) {
      return json(401, { error: 'Invalid admin secret' });
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const serviceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!supabaseUrl || !serviceRole) {
      return json(500, { error: 'Missing Supabase env' });
    }

    const admin = createClient(supabaseUrl, serviceRole);
    const body = await req.json();
    const action = String(body.action ?? '').trim();

    switch (action) {
      case 'summary':
        return await summary(admin);
      case 'list_puzzles':
        return await listPuzzles(admin, body.type);
      case 'upsert_puzzle':
        return await upsertPuzzle(admin, body.puzzle);
      case 'delete_puzzle':
        return await deletePuzzle(admin, body.id);
      default:
        return json(400, { error: 'Unknown action' });
    }
  } catch (error) {
    return json(500, {
      error: 'Unhandled admin-manager error',
      detail: error instanceof Error ? error.message : String(error),
    });
  }
});

async function summary(admin: ReturnType<typeof createClient>): Promise<Response> {
  const [{ data: puzzles }, { data: progress }, { data: events }] = await Promise.all([
    admin.from('puzzles').select('id,type,difficulty,is_daily,published_at').order('published_at', { ascending: false }).limit(5000),
    admin.from('user_progress').select('completed,session_elapsed_seconds,type,user_id'),
    admin.from('score_submission_events').select('id,type,accepted,created_at').order('created_at', { ascending: false }).limit(5000),
  ]);

  const puzzleRows = Array.isArray(puzzles) ? puzzles : [];
  const progressRows = Array.isArray(progress) ? progress : [];
  const eventRows = Array.isArray(events) ? events : [];

  const puzzlesByType: Record<string, number> = {};
  const puzzlesByDifficulty: Record<string, number> = {};
  for (const p of puzzleRows) {
    const type = String((p as Record<string, unknown>).type ?? 'unknown');
    const diff = String((p as Record<string, unknown>).difficulty ?? 'Unknown');
    puzzlesByType[type] = (puzzlesByType[type] ?? 0) + 1;
    puzzlesByDifficulty[diff] = (puzzlesByDifficulty[diff] ?? 0) + 1;
  }

  let completedCount = 0;
  let inProgressCount = 0;
  const users = new Set<string>();
  for (const p of progressRows) {
    const row = p as Record<string, unknown>;
    const completed = Boolean(row.completed ?? false);
    const elapsed = Number(row.session_elapsed_seconds ?? 0);
    if (completed) {
      completedCount += 1;
    } else if (elapsed > 0) {
      inProgressCount += 1;
    }
    const uid = String(row.user_id ?? '');
    if (uid) {
      users.add(uid);
    }
  }

  const now = Date.now();
  const oneDayAgo = now - 24 * 60 * 60 * 1000;
  const sevenDaysAgo = now - 7 * 24 * 60 * 60 * 1000;
  let accepted24h = 0;
  let accepted7d = 0;
  const submissionsByType: Record<string, number> = {};
  for (const e of eventRows) {
    const row = e as Record<string, unknown>;
    const accepted = Boolean(row.accepted ?? false);
    const type = String(row.type ?? 'unknown');
    const ts = Date.parse(String(row.created_at ?? ''));
    if (!Number.isFinite(ts)) {
      continue;
    }
    submissionsByType[type] = (submissionsByType[type] ?? 0) + 1;
    if (accepted && ts >= oneDayAgo) {
      accepted24h += 1;
    }
    if (accepted && ts >= sevenDaysAgo) {
      accepted7d += 1;
    }
  }

  return json(200, {
    ok: true,
    usage: {
      total_puzzles: puzzleRows.length,
      puzzles_by_type: puzzlesByType,
      puzzles_by_difficulty: puzzlesByDifficulty,
      completed_runs: completedCount,
      in_progress_runs: inProgressCount,
      active_users: users.size,
      accepted_submissions_24h: accepted24h,
      accepted_submissions_7d: accepted7d,
      submissions_by_type: submissionsByType,
    },
  });
}

async function listPuzzles(admin: ReturnType<typeof createClient>, typeRaw: unknown): Promise<Response> {
  const type = String(typeRaw ?? '').trim().toLowerCase();
  let query = admin
    .from('puzzles')
    .select('id,type,title,difficulty,payload,is_daily,published_at,puzzle_hash')
    .order('published_at', { ascending: false })
    .limit(1000);
  if (type) {
    query = query.eq('type', type);
  }
  const { data, error } = await query;
  if (error) {
    return json(500, { error: 'Failed to list puzzles', detail: error.message });
  }
  return json(200, { ok: true, puzzles: data ?? [] });
}

async function upsertPuzzle(admin: ReturnType<typeof createClient>, puzzleRaw: unknown): Promise<Response> {
  if (!puzzleRaw || typeof puzzleRaw !== 'object') {
    return json(400, { error: 'Missing puzzle payload' });
  }
  const p = puzzleRaw as Record<string, unknown>;
  const id = String(p.id ?? '').trim();
  const type = String(p.type ?? '').trim().toLowerCase();
  const title = String(p.title ?? '').trim();
  const difficulty = String(p.difficulty ?? '').trim();
  const payload = p.payload;
  const isDaily = Boolean(p.is_daily ?? true);
  const publishedAt = String(p.published_at ?? '').trim() || new Date().toISOString();
  const puzzleHash = String(p.puzzle_hash ?? '').trim().toLowerCase();

  if (!id || !type || !title || !difficulty || !payload || typeof payload !== 'object') {
    return json(400, { error: 'Invalid puzzle fields' });
  }

  const { error } = await admin.from('puzzles').upsert(
    {
      id,
      type,
      title,
      difficulty,
      payload,
      is_daily: isDaily,
      published_at: publishedAt,
      puzzle_hash: puzzleHash || null,
    },
    { onConflict: 'id' },
  );

  if (error) {
    return json(500, { error: 'Failed to upsert puzzle', detail: error.message });
  }

  return json(200, { ok: true });
}

async function deletePuzzle(admin: ReturnType<typeof createClient>, idRaw: unknown): Promise<Response> {
  const id = String(idRaw ?? '').trim();
  if (!id) {
    return json(400, { error: 'Missing id' });
  }

  const { error } = await admin.from('puzzles').delete().eq('id', id);
  if (error) {
    return json(500, { error: 'Failed to delete puzzle', detail: error.message });
  }

  return json(200, { ok: true });
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
