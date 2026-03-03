import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-builder-secret',
};

const allowedDifficulties = new Set(['Easy', 'Medium', 'Hard']);

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const secret = Deno.env.get('PUZZLE_BUILDER_SECRET') ?? '';
    const requestSecret = req.headers.get('x-builder-secret') ?? '';
    if (!secret || requestSecret !== secret) {
      return json(401, { error: 'Invalid builder secret' });
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!supabaseUrl || !supabaseServiceRole) {
      return json(500, { error: 'Server env is missing Supabase config' });
    }

    const adminClient = createClient(supabaseUrl, supabaseServiceRole);

    const body = await req.json();
    const puzzles = Array.isArray(body.puzzles) ? body.puzzles : [];
    if (puzzles.length === 0) {
      return json(400, { error: 'No puzzles provided' });
    }

    const validRows: Record<string, unknown>[] = [];
    const skipped: Record<string, unknown>[] = [];

    for (const item of puzzles) {
      const id = String(item.id ?? '').trim();
      const type = String(item.type ?? '').trim().toLowerCase();
      const title = String(item.title ?? '').trim();
      const difficulty = String(item.difficulty ?? '').trim();
      const payload = item.payload;
      const isDaily = Boolean(item.is_daily ?? true);
      const publishedAt = String(item.published_at ?? '').trim();
      const hash = String(item.puzzle_hash ?? '').trim().toLowerCase();

      if (!id || !title || !publishedAt || !hash) {
        skipped.push({ id, reason: 'missing_fields' });
        continue;
      }
      if (type !== 'sudoku') {
        skipped.push({ id, reason: 'unsupported_type' });
        continue;
      }
      if (!allowedDifficulties.has(difficulty)) {
        skipped.push({ id, reason: 'invalid_difficulty' });
        continue;
      }
      if (!isValidHash(hash)) {
        skipped.push({ id, reason: 'invalid_hash' });
        continue;
      }
      if (!isValidPayload(payload)) {
        skipped.push({ id, reason: 'invalid_payload' });
        continue;
      }

      validRows.push({
        id,
        type,
        title,
        difficulty,
        payload,
        is_daily: isDaily,
        published_at: publishedAt,
        puzzle_hash: hash,
      });
    }

    if (validRows.length === 0) {
      return json(200, { inserted: 0, skipped });
    }

    const ids = validRows.map((row) => String(row.id));
    const hashes = validRows.map((row) => String(row.puzzle_hash));

    const { data: existingById } = await adminClient
      .from('puzzles')
      .select('id')
      .in('id', ids);

    const { data: existingByHash } = await adminClient
      .from('puzzles')
      .select('puzzle_hash')
      .eq('type', 'sudoku')
      .in('puzzle_hash', hashes);

    const existingIds = new Set((existingById ?? []).map((row) => String(row.id)));
    const existingHashes = new Set((existingByHash ?? []).map((row) => String(row.puzzle_hash)));

    const toInsert = validRows.filter((row) => {
      const id = String(row.id);
      const hash = String(row.puzzle_hash);
      if (existingIds.has(id)) {
        skipped.push({ id, reason: 'id_exists' });
        return false;
      }
      if (existingHashes.has(hash)) {
        skipped.push({ id, reason: 'hash_exists' });
        return false;
      }
      return true;
    });

    if (toInsert.length > 0) {
      const { error } = await adminClient.from('puzzles').insert(toInsert);
      if (error) {
        return json(500, { error: 'Failed to insert generated puzzles', detail: error.message });
      }
    }

    return json(200, { inserted: toInsert.length, skipped });
  } catch (error) {
    return json(500, {
      error: 'Unhandled error in ingest-puzzles',
      detail: error instanceof Error ? error.message : String(error),
    });
  }
});

function isValidHash(hash: string): boolean {
  return /^[a-f0-9]{64}$/.test(hash);
}

function isValidPayload(payload: unknown): boolean {
  if (!payload || typeof payload !== 'object') {
    return false;
  }
  const grid = (payload as { grid?: unknown }).grid;
  if (!Array.isArray(grid) || grid.length !== 9) {
    return false;
  }
  for (const row of grid) {
    if (!Array.isArray(row) || row.length !== 9) {
      return false;
    }
    for (const cell of row) {
      if (typeof cell !== 'number' || !Number.isInteger(cell) || cell < 0 || cell > 9) {
        return false;
      }
    }
  }
  return true;
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
