import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
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

    const body = await req.json();
    const puzzleId = String(body.puzzle_id ?? '').trim();
    const type = String(body.type ?? '').trim().toLowerCase();
    const clear = Boolean(body.clear ?? false);
    const elapsedSeconds = Number(body.elapsed_seconds ?? 0);
    const sessionState = body.session_state as Record<string, unknown> | null;
    const sessionUpdatedAtRaw = String(body.session_updated_at ?? '').trim();

    if (!puzzleId || !type) {
      return json(400, { error: 'Missing puzzle_id or type' });
    }

    if (!Number.isInteger(elapsedSeconds) || elapsedSeconds < 0 || elapsedSeconds > 864000) {
      return json(400, { error: 'Invalid elapsed_seconds' });
    }

    const sessionUpdatedAt = sessionUpdatedAtRaw
      ? new Date(sessionUpdatedAtRaw)
      : new Date();

    if (Number.isNaN(sessionUpdatedAt.getTime())) {
      return json(400, { error: 'Invalid session_updated_at' });
    }

    const adminClient = createClient(supabaseUrl, supabaseServiceRole);

    const { data: existingRow } = await adminClient
      .from('user_progress')
      .select('completed, best_seconds, hints_used, streak_days, session_updated_at')
      .eq('user_id', user.id)
      .eq('puzzle_id', puzzleId)
      .maybeSingle();

    const existingUpdatedAt = existingRow?.session_updated_at
      ? new Date(String(existingRow.session_updated_at))
      : null;

    if (existingUpdatedAt && existingUpdatedAt.getTime() > sessionUpdatedAt.getTime()) {
      return json(200, { ok: true, ignored: true, reason: 'older_session' });
    }

    const payload = {
      user_id: user.id,
      puzzle_id: puzzleId,
      type,
      completed: Boolean(existingRow?.completed ?? false),
      best_seconds: Number(existingRow?.best_seconds ?? 0),
      hints_used: Number(existingRow?.hints_used ?? 0),
      streak_days: Number(existingRow?.streak_days ?? 0),
      session_elapsed_seconds: clear ? 0 : elapsedSeconds,
      session_state: clear ? null : sessionState,
      session_updated_at: sessionUpdatedAt.toISOString(),
    };

    const { error: upsertError } = await adminClient
      .from('user_progress')
      .upsert(payload, { onConflict: 'user_id,puzzle_id' });

    if (upsertError) {
      return json(500, { error: 'Failed to save puzzle session' });
    }

    return json(200, { ok: true });
  } catch (error) {
    return json(500, {
      error: 'Unhandled error in save-puzzle-session',
      detail: error instanceof Error ? error.message : String(error),
    });
  }
});

function json(status: number, payload: Record<string, unknown>): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}
