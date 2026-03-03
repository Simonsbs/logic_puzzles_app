#!/usr/bin/env python3
import json
import os
from dataclasses import dataclass
from datetime import datetime, timezone
from hashlib import sha256
from typing import Any, Dict, List, Optional

import requests
from dotenv import load_dotenv
from flask import Flask, flash, redirect, render_template, request, url_for

load_dotenv(os.path.join(os.path.dirname(__file__), '..', '.env.admin_manager'))


@dataclass
class Config:
    supabase_url: str
    supabase_anon_key: str
    admin_secret: str


class ManagerClient:
    def __init__(self, cfg: Config) -> None:
        self.cfg = cfg
        self.endpoint = f"{cfg.supabase_url}/functions/v1/admin-manager"

    def call(self, action: str, **payload: Any) -> Dict[str, Any]:
        body = {'action': action, **payload}
        headers = {
            'Content-Type': 'application/json',
            'apikey': self.cfg.supabase_anon_key,
            'Authorization': f"Bearer {self.cfg.supabase_anon_key}",
            'x-admin-secret': self.cfg.admin_secret,
        }
        resp = requests.post(self.endpoint, headers=headers, json=body, timeout=30)
        if resp.status_code >= 400:
            raise RuntimeError(f"admin-manager {resp.status_code}: {resp.text}")
        return resp.json()


def load_config() -> Config:
    supabase_url = os.environ.get('SUPABASE_URL', '').strip()
    anon_key = os.environ.get('SUPABASE_ANON_KEY', '').strip()
    secret = os.environ.get('ADMIN_MANAGER_SECRET', '').strip()
    if not supabase_url or not anon_key or not secret:
        raise RuntimeError('Missing SUPABASE_URL / SUPABASE_ANON_KEY / ADMIN_MANAGER_SECRET in .env.admin_manager')
    return Config(supabase_url=supabase_url, supabase_anon_key=anon_key, admin_secret=secret)


cfg = load_config()
client = ManagerClient(cfg)
app = Flask(__name__)
app.secret_key = os.environ.get('ADMIN_MANAGER_FLASK_SECRET', 'change-me')


@app.get('/')
def dashboard() -> str:
    usage = client.call('summary').get('usage', {})
    puzzle_type = request.args.get('type', 'sudoku').strip().lower()
    puzzles = client.call('list_puzzles', type=puzzle_type).get('puzzles', [])
    return render_template('dashboard.html', usage=usage, puzzles=puzzles, selected_type=puzzle_type)


@app.post('/puzzles/save')
def save_puzzle() -> Any:
    puzzle_id = request.form.get('id', '').strip()
    puzzle_type = request.form.get('type', '').strip().lower()
    title = request.form.get('title', '').strip()
    difficulty = request.form.get('difficulty', '').strip()
    payload_raw = request.form.get('payload', '').strip()
    published_at = request.form.get('published_at', '').strip()
    is_daily = request.form.get('is_daily', 'on') == 'on'

    if not puzzle_id or not puzzle_type or not payload_raw:
        flash('id, type and payload are required', 'error')
        return redirect(url_for('dashboard', type=puzzle_type or 'sudoku'))

    try:
        payload = json.loads(payload_raw)
    except json.JSONDecodeError:
        flash('payload must be valid JSON', 'error')
        return redirect(url_for('dashboard', type=puzzle_type or 'sudoku'))

    hash_value = ''
    if puzzle_type == 'sudoku' and isinstance(payload, dict) and isinstance(payload.get('grid'), list):
        grid = payload.get('grid')
        try:
            raw = ''.join(str(int(cell)) for row in grid for cell in row)
            hash_value = sha256(raw.encode('ascii')).hexdigest()
        except Exception:
            hash_value = ''

    if not published_at:
        published_at = datetime.now(timezone.utc).isoformat()

    client.call(
        'upsert_puzzle',
        puzzle={
            'id': puzzle_id,
            'type': puzzle_type,
            'title': title or puzzle_id,
            'difficulty': difficulty or 'Medium',
            'payload': payload,
            'is_daily': is_daily,
            'published_at': published_at,
            'puzzle_hash': hash_value,
        },
    )

    flash(f'Saved puzzle {puzzle_id}', 'ok')
    return redirect(url_for('dashboard', type=puzzle_type or 'sudoku'))


@app.post('/puzzles/delete/<puzzle_id>')
def delete_puzzle(puzzle_id: str) -> Any:
    puzzle_type = request.args.get('type', 'sudoku').strip().lower()
    client.call('delete_puzzle', id=puzzle_id)
    flash(f'Deleted puzzle {puzzle_id}', 'ok')
    return redirect(url_for('dashboard', type=puzzle_type or 'sudoku'))


if __name__ == '__main__':
    host = os.environ.get('ADMIN_MANAGER_HOST', '127.0.0.1')
    port = int(os.environ.get('ADMIN_MANAGER_PORT', '8095'))
    app.run(host=host, port=port, debug=False)
