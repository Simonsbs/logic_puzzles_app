const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const dailyItems = [
  { kind: 'fact', text: 'Sudoku has about 6.67 sextillion valid completed grids.' },
  { kind: 'joke', text: 'I solved 99 puzzles today. None of them were my life choices.' },
  { kind: 'fact', text: 'The word Sudoku means “single number” in Japanese.' },
  { kind: 'joke', text: 'I asked for an easy puzzle. It asked for emotional growth.' },
  { kind: 'fact', text: 'Logic puzzles improve pattern recognition and working memory.' },
  { kind: 'joke', text: 'My timer and I have a complicated relationship.' },
  { kind: 'fact', text: 'A classic Sudoku grid is always 9 by 9 with 3 by 3 subgrids.' },
  { kind: 'joke', text: 'I paused for one minute. My streak called it betrayal.' },
];

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const now = new Date();
  const dayIndex = Math.floor(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()) / 86400000);
  const item = dailyItems[Math.abs(dayIndex) % dailyItems.length];

  return json(200, {
    date: now.toISOString().slice(0, 10),
    kind: item.kind,
    text: item.text,
  });
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
