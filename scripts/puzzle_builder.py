#!/usr/bin/env python3
import argparse
import datetime as dt
import hashlib
import json
import os
import random
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from typing import Dict, List, Optional, Sequence, Set, Tuple

DIFFICULTY_CLUES: Dict[str, int] = {
    "easy": 40,
    "medium": 32,
    "hard": 26,
}


@dataclass(frozen=True)
class GeneratedPuzzle:
    puzzle_id: str
    title: str
    difficulty: str
    published_at: str
    grid: List[List[int]]
    puzzle_hash: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate and upload daily Sudoku puzzles.")
    parser.add_argument("--start-date", default=dt.date.today().isoformat(), help="UTC date YYYY-MM-DD")
    parser.add_argument("--days", type=int, default=1, help="Number of days to generate")
    parser.add_argument("--seed", type=int, default=None, help="Optional RNG seed")
    parser.add_argument("--max-attempts", type=int, default=300, help="Max generation attempts per puzzle")
    parser.add_argument("--dry-run", action="store_true", help="Generate/validate only; do not upload")
    parser.add_argument("--output", default="", help="Optional output JSON path")
    return parser.parse_args()


def flatten(grid: Sequence[Sequence[int]]) -> str:
    return "".join(str(cell) for row in grid for cell in row)


def puzzle_hash(grid: Sequence[Sequence[int]]) -> str:
    raw = flatten(grid)
    return hashlib.sha256(raw.encode("ascii")).hexdigest()


def copy_grid(grid: Sequence[Sequence[int]]) -> List[List[int]]:
    return [list(row) for row in grid]


def find_empty(grid: Sequence[Sequence[int]]) -> Optional[Tuple[int, int]]:
    for r in range(9):
        for c in range(9):
            if grid[r][c] == 0:
                return (r, c)
    return None


def can_place(grid: Sequence[Sequence[int]], row: int, col: int, value: int) -> bool:
    for i in range(9):
        if grid[row][i] == value or grid[i][col] == value:
            return False

    box_row = (row // 3) * 3
    box_col = (col // 3) * 3
    for r in range(box_row, box_row + 3):
        for c in range(box_col, box_col + 3):
            if grid[r][c] == value:
                return False

    return True


def solve_backtracking(grid: List[List[int]], rng: random.Random) -> bool:
    empty = find_empty(grid)
    if empty is None:
        return True

    row, col = empty
    options = list(range(1, 10))
    rng.shuffle(options)
    for value in options:
        if can_place(grid, row, col, value):
            grid[row][col] = value
            if solve_backtracking(grid, rng):
                return True
            grid[row][col] = 0

    return False


def count_solutions(grid: List[List[int]], limit: int = 2) -> int:
    count = 0

    def _search() -> None:
        nonlocal count
        if count >= limit:
            return

        empty = find_empty(grid)
        if empty is None:
            count += 1
            return

        row, col = empty
        for value in range(1, 10):
            if can_place(grid, row, col, value):
                grid[row][col] = value
                _search()
                grid[row][col] = 0
                if count >= limit:
                    return

    _search()
    return count


def make_solution(rng: random.Random) -> List[List[int]]:
    grid = [[0 for _ in range(9)] for _ in range(9)]
    if not solve_backtracking(grid, rng):
        raise RuntimeError("failed to generate solved Sudoku grid")
    return grid


def make_puzzle_from_solution(solution: Sequence[Sequence[int]], clue_target: int, rng: random.Random) -> Optional[List[List[int]]]:
    puzzle = copy_grid(solution)
    cells = [(r, c) for r in range(9) for c in range(9)]
    rng.shuffle(cells)

    for row, col in cells:
        remaining = sum(1 for rr in range(9) for cc in range(9) if puzzle[rr][cc] != 0)
        if remaining <= clue_target:
            break

        hold = puzzle[row][col]
        puzzle[row][col] = 0
        probe = copy_grid(puzzle)
        if count_solutions(probe, limit=2) != 1:
            puzzle[row][col] = hold

    remaining = sum(1 for rr in range(9) for cc in range(9) if puzzle[rr][cc] != 0)
    if remaining > clue_target:
        return None

    if not validate_sudoku_puzzle(puzzle):
        return None

    return puzzle


def validate_sudoku_puzzle(puzzle: Sequence[Sequence[int]]) -> bool:
    if len(puzzle) != 9 or any(len(row) != 9 for row in puzzle):
        return False
    for row in puzzle:
        for cell in row:
            if not isinstance(cell, int) or cell < 0 or cell > 9:
                return False

    probe = copy_grid(puzzle)
    return count_solutions(probe, limit=2) == 1


def fetch_existing_hashes(supabase_url: str, anon_key: str) -> Set[str]:
    endpoint = (
        f"{supabase_url}/rest/v1/puzzles?"
        + urllib.parse.urlencode({"select": "puzzle_hash,payload", "type": "eq.sudoku", "limit": "100000"})
    )
    req = urllib.request.Request(
        endpoint,
        headers={
            "apikey": anon_key,
            "Authorization": f"Bearer {anon_key}",
            "Accept": "application/json",
        },
        method="GET",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        rows = json.loads(resp.read().decode("utf-8"))

    hashes: Set[str] = set()
    for row in rows:
        p_hash = row.get("puzzle_hash")
        if isinstance(p_hash, str) and p_hash:
            hashes.add(p_hash)
            continue

        payload = row.get("payload")
        if isinstance(payload, dict) and isinstance(payload.get("grid"), list):
            try:
                grid = [list(map(int, rr)) for rr in payload["grid"]]
                if len(grid) == 9 and all(len(rr) == 9 for rr in grid):
                    hashes.add(puzzle_hash(grid))
            except Exception:
                continue

    return hashes


def upload_batch(supabase_url: str, anon_key: str, secret: str, puzzles: Sequence[GeneratedPuzzle]) -> Dict[str, object]:
    endpoint = f"{supabase_url}/functions/v1/ingest-puzzles"
    payload = {
        "puzzles": [
            {
                "id": p.puzzle_id,
                "type": "sudoku",
                "title": p.title,
                "difficulty": p.difficulty.title(),
                "payload": {"grid": p.grid},
                "is_daily": True,
                "published_at": p.published_at,
                "puzzle_hash": p.puzzle_hash,
            }
            for p in puzzles
        ]
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        endpoint,
        headers={
            "Content-Type": "application/json",
            "apikey": anon_key,
            "Authorization": f"Bearer {anon_key}",
            "x-builder-secret": secret,
        },
        data=data,
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        body = json.loads(resp.read().decode("utf-8"))
    return body


def generate_for_day(day: dt.date, known_hashes: Set[str], rng: random.Random, max_attempts: int) -> List[GeneratedPuzzle]:
    created: List[GeneratedPuzzle] = []
    for idx, (difficulty, clues) in enumerate(DIFFICULTY_CLUES.items()):
        attempt = 0
        picked: Optional[GeneratedPuzzle] = None
        while attempt < max_attempts:
            attempt += 1
            solution = make_solution(rng)
            puzzle = make_puzzle_from_solution(solution, clues, rng)
            if puzzle is None:
                continue

            p_hash = puzzle_hash(puzzle)
            if p_hash in known_hashes:
                continue

            puzzle_id = f"sudoku-{day.strftime('%Y%m%d')}-{difficulty}"
            published_at = (dt.datetime.combine(day, dt.time(0, idx, 0, tzinfo=dt.timezone.utc))).isoformat()
            picked = GeneratedPuzzle(
                puzzle_id=puzzle_id,
                title=f"Sudoku {difficulty.title()} {day.isoformat()}",
                difficulty=difficulty,
                published_at=published_at,
                grid=puzzle,
                puzzle_hash=p_hash,
            )
            break

        if picked is None:
            raise RuntimeError(f"failed to generate unique {difficulty} puzzle for {day.isoformat()}")

        known_hashes.add(picked.puzzle_hash)
        created.append(picked)

    return created


def ensure_env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise RuntimeError(f"missing required env var: {name}")
    return value


def main() -> int:
    args = parse_args()

    if args.days <= 0:
        raise RuntimeError("--days must be >= 1")

    start_date = dt.date.fromisoformat(args.start_date)
    rng = random.Random(args.seed)

    should_upload = not args.dry_run

    known_hashes: Set[str] = set()
    supabase_url = ""
    anon_key = ""
    secret = ""

    if should_upload:
        supabase_url = ensure_env("SUPABASE_URL")
        anon_key = ensure_env("SUPABASE_ANON_KEY")
        secret = ensure_env("PUZZLE_BUILDER_SECRET")
        known_hashes = fetch_existing_hashes(supabase_url, anon_key)

    all_puzzles: List[GeneratedPuzzle] = []
    for offset in range(args.days):
        day = start_date + dt.timedelta(days=offset)
        batch = generate_for_day(day, known_hashes, rng, args.max_attempts)
        all_puzzles.extend(batch)

    if args.output:
        export_rows = [
            {
                "id": p.puzzle_id,
                "difficulty": p.difficulty,
                "published_at": p.published_at,
                "puzzle_hash": p.puzzle_hash,
                "grid": p.grid,
            }
            for p in all_puzzles
        ]
        with open(args.output, "w", encoding="utf-8") as f:
            json.dump(export_rows, f, indent=2)

    if should_upload:
        result = upload_batch(supabase_url, anon_key, secret, all_puzzles)
        print(json.dumps({"generated": len(all_puzzles), "upload": result}, indent=2))
    else:
        print(json.dumps({"generated": len(all_puzzles), "dry_run": True}, indent=2))

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        print(f"HTTP {e.code}: {body}", file=sys.stderr)
        raise
    except Exception as e:
        print(str(e), file=sys.stderr)
        raise
