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
      return json(401, { error: 'Missing Authorization header', reason_code: 'invalid_user_session' });
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');
    const supabaseServiceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRole) {
      return json(500, { error: 'Server env is missing Supabase config', reason_code: 'server_error' });
    }

    const authClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: userError } = await authClient.auth.getUser();
    if (userError || !user) {
      return json(401, { error: 'Invalid user session', reason_code: 'invalid_user_session' });
    }

    const body = await req.json();
    const logType = String(body.log_type ?? 'support').trim().toLowerCase();
    const message = String(body.message ?? '').trim();
    const payload = body.payload && typeof body.payload === 'object'
      ? body.payload as Record<string, unknown>
      : null;

    if (!message) {
      return json(400, { error: 'Missing message', reason_code: 'missing_message' });
    }

    const admin = createClient(supabaseUrl, supabaseServiceRole);
    const { error: insertError } = await admin.from('client_logs').insert({
      user_id: user.id,
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
