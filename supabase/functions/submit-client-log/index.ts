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
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');
    const supabaseServiceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRole) {
      return json(500, { error: 'Server env is missing Supabase config', reason_code: 'server_error' });
    }

    const authHeader = req.headers.get('Authorization');
    let userId: string | null = null;
    if (authHeader) {
      const authClient = createClient(supabaseUrl, supabaseAnonKey, {
        global: { headers: { Authorization: authHeader } },
      });
      const { data: { user } } = await authClient.auth.getUser();
      userId = user?.id ?? null;
    }

    const body = await req.json();
    const logType = String(body.log_type ?? 'support').trim().toLowerCase();
    const debugUserId = String(body.debug_user_id ?? '').trim();
    const message = String(body.message ?? '').trim();
    const payload = body.payload && typeof body.payload === 'object'
      ? body.payload as Record<string, unknown>
      : null;

    if (!debugUserId) {
      return json(400, { error: 'Missing debug_user_id', reason_code: 'missing_debug_user_id' });
    }

    if (!message) {
      return json(400, { error: 'Missing message', reason_code: 'missing_message' });
    }

    const admin = createClient(supabaseUrl, supabaseServiceRole);
    const { error: insertError } = await admin.from('client_logs').insert({
      user_id: userId,
      debug_user_id: debugUserId,
      log_type: logType || 'support',
      message,
      payload,
    });

    if (insertError) {
      return json(500, { error: 'Failed to save client log', reason_code: 'db_error' });
    }

    return json(200, { ok: true });
  } catch (error) {
    return json(500, {
      error: 'Unhandled error in submit-client-log',
      reason_code: 'server_error',
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
