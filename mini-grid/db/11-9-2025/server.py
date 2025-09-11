# server.py — clean version with /test
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
import sqlite3, os, subprocess, pathlib, time
from datetime import datetime, timezone
from pathlib import Path

DB_PATH = os.environ.get("LS_MINI_DB_PATH", "mini.db")
BAT_PATH = os.environ.get("LS_SYNC_BAT", r"E:\the new Bat\life-support-mini\tools\import_export_sync.bat")
WORK_DIR = os.environ.get("LS_SYNC_CWD", str(pathlib.Path(BAT_PATH).parent))

def get_db():
    return sqlite3.connect(pathlib.Path(DB_PATH))

def iso_now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

app = FastAPI(title="Life-Support Mini API", version="1.0.0")
# ---------- Printable Prospect page ----------
from fastapi.responses import HTMLResponse

@app.get("/prospect/{gat_id}/{city_id}/{company_id}", response_class=HTMLResponse)
def prospect_view(gat_id: str, city_id: str, company_id: str):
    conn = get_db()
    conn.row_factory = sqlite3.Row
    p = conn.execute(
        "SELECT * FROM prospects WHERE gat_id=? AND city_id=? AND company_id=?",
        (gat_id, city_id, company_id)
    ).fetchone()
    contacts = conn.execute(
        "SELECT contact_name, role_title, email, phone, COALESCE(notes,'') AS notes "
        "FROM contact_grid WHERE gat_id=? AND city_id=? AND company_id=? "
        "ORDER BY contact_id DESC",
        (gat_id, city_id, company_id)
    ).fetchall()
    conn.close()

    if not p:
        raise HTTPException(status_code=404, detail="Prospect not found")

    def esc(x):  # tiny HTML escaper
        return (x or "").replace("&","&amp;").replace("<","&lt;").replace(">","&gt;")

    contact_rows = "".join(
        f"<tr><td>{esc(c['contact_name'])}</td>"
        f"<td>{esc(c['role_title'])}</td>"
        f"<td>{esc(c['email'])}</td>"
        f"<td>{esc(c['phone'])}</td>"
        f"<td>{esc(c['notes'])}</td></tr>"
        for c in contacts
    ) or "<tr><td colspan='5' style='text-align:center;color:#666'>No contacts yet</td></tr>"

    html = f"""<!doctype html>
<meta charset="utf-8">
<title>Prospect • {esc(p['prospect_name'])}</title>
<style>
  body{{font:14px system-ui,Segoe UI,Arial; margin:24px; color:#111}}
  h1{{margin:0 0 6px}}
  .meta{{color:#555; margin:0 0 18px}}
  table{{border-collapse:collapse; width:100%; margin-top:10px}}
  th,td{{border:1px solid #ddd; padding:8px; vertical-align:top}}
  th{{background:#f6f6f6; text-align:left}}
  .actions{{margin:14px 0 6px}}
  .btn{{padding:8px 12px; border:1px solid #888; border-radius:6px; background:#fafafa; cursor:pointer}}
  #msg{{margin-left:10px}}
  @media print{{ .noprint{{display:none}} body{{margin:12mm}} }}
</style>

<h1>Prospect</h1>
<p class="meta">
  <b>GAT</b> {esc(p['gat_id'])} •
  <b>City</b> {esc(p['city_id'])} •
  <b>Company</b> {esc(p['company_id'])}<br>
  <b>Name</b> {esc(p['prospect_name'])}<br>
  <b>Status</b> {esc(p['lifecycle_status'] or '')} •
  <b>Created</b> {esc(p['created_at'] or '')} •
  <b>Updated</b> {esc(p['updated_at'] or '')}
</p>

<h3>Contacts</h3>
<table>
  <thead><tr><th>Name</th><th>Role</th><th>Email</th><th>Phone</th><th>Notes</th></tr></thead>
  <tbody>{contact_rows}</tbody>
</table>

<div class="actions noprint">
  <button class="btn" id="promote">Promote to Sponsor</button>
  <button class="btn" onclick="window.print()">Print</button>
  <span id="msg"></span>
</div>

<script>
  const trio = {{gat_id: {gat_id!r}, city_id: {city_id!r}, company_id: {company_id!r}}};
  const btn = document.getElementById('promote');
  const msg = document.getElementById('msg');
  btn.onclick = async () => {{
    msg.textContent = 'Promoting...';
    try {{
      const r = await fetch('/api/promote', {{
        method: 'POST',
        headers: {{'Content-Type':'application/json'}},
        body: JSON.stringify(trio)
      }});
      const data = await r.json();
      msg.textContent = r.ok ? `OK — contract: ${'{'}data.contract_date{'}'}, expires: ${'{'}data.expiration_date{'}'}` 
                             : `Error ${'{'}r.status{'}'}: ${'{'}data.detail || JSON.stringify(data){'}'}`;
    }} catch(e) {{
      msg.textContent = 'Network error: ' + e;
    }}
  }};
</script>
"""
    return HTMLResponse(html)

# Dev-friendly CORS (ok for local use)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------- Test page (same origin) ----------
@app.get("/test", response_class=HTMLResponse)
def test_page():
    return """<!doctype html>
<meta charset="utf-8">
<title>Mini API Test (Same Origin)</title>
<button id="b1">Health (/api/health)</button>
<button id="b2">Promote (POST /api/promote)</button>
<pre id="out" style="white-space:pre-wrap;border:1px solid #ccc;padding:8px;margin-top:10px;border-radius:6px;">Output…</pre>
<script>
const out = document.getElementById('out');
function show(x){ out.textContent = typeof x==='string' ? x : JSON.stringify(x,null,2); }
async function call(url, opts){
  show('Fetching ' + url + ' ...');
  try{ const r = await fetch(url, opts); show({status:r.status, body: await r.json()}); }
  catch(e){ show(String(e)); }
}
document.getElementById('b1').onclick = () => call('/api/health');
document.getElementById('b2').onclick = () => call('/api/promote', {
  method:'POST',
  headers:{'Content-Type':'application/json'},
  body: JSON.stringify({ gat_id:'GAT001', city_id:'DE-BER-1101', company_id:'COMP123' })
});
</script>"""

# ---------- Promote ----------
class PromoteIn(BaseModel):
    gat_id: str
    city_id: str
    company_id: str

@app.post("/api/promote")
def promote(payload: PromoteIn):
    conn = get_db()
    try:
        conn.isolation_level = None  # manual transaction
        conn.execute("BEGIN")
        cur = conn.execute("""SELECT prospect_name FROM prospects
                              WHERE gat_id=? AND city_id=? AND company_id=?""",
                              (payload.gat_id, payload.city_id, payload.company_id))
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Prospect not found")
        prospect_name = row[0]

        conn.execute("""INSERT OR IGNORE INTO sponsors
            (gat_id, city_id, company_id, sponsor_name, contract_date, expiration_date)
            VALUES (?, ?, ?, ?, DATE('now'), DATE('now','+1 year'))""",
            (payload.gat_id, payload.city_id, payload.company_id, prospect_name))

        conn.execute("""UPDATE prospects
                        SET lifecycle_status='archived', archived_at=DATE('now'), updated_at=CURRENT_TIMESTAMP
                        WHERE gat_id=? AND city_id=? AND company_id=?""",
                        (payload.gat_id, payload.city_id, payload.company_id))

        dates = conn.execute("""SELECT contract_date, expiration_date
                                FROM sponsors WHERE gat_id=? AND city_id=? AND company_id=?""",
                                (payload.gat_id, payload.city_id, payload.company_id)).fetchone()
        conn.execute("COMMIT")
        return {"contract_date": dates[0], "expiration_date": dates[1]}
    except Exception:
        conn.execute("ROLLBACK")
        raise
    finally:
        conn.close()

# ---------- Sync (logs + rotation) ----------
LOG_BASE = Path(os.environ.get("LS_LOG_DIR", Path.cwd() / "logs" / "sync"))
RETAIN_DAYS = int(os.environ.get("LS_SYNC_RETAIN_DAYS", "30"))

def ensure_dir(p: Path): p.mkdir(parents=True, exist_ok=True)

def cleanup_old_logs():
    cutoff = time.time() - RETAIN_DAYS*24*3600
    if not LOG_BASE.exists(): return
    for day_dir in LOG_BASE.iterdir():
        try:
            ts = time.mktime(time.strptime(day_dir.name + "T00:00:00Z", "%Y-%m-%dT%H:%M:%SZ"))
            if ts < cutoff:
                for child in day_dir.glob("*"):
                    try: child.unlink()
                    except: pass
                try: day_dir.rmdir()
                except: pass
        except: pass

@app.post("/api/sync")
def sync():
    ensure_dir(LOG_BASE)
    cleanup_old_logs()
    day_dir = LOG_BASE / datetime.now(timezone.utc).strftime("%Y-%m-%d")
    ensure_dir(day_dir)
    log_path = day_dir / f"sync_{datetime.now(timezone.utc).strftime('%Y-%m-%d_%H%M%S')}.log"

    conn = get_db()
    conn.execute("""CREATE TABLE IF NOT EXISTS sync_runs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        started_at TEXT NOT NULL,
        ended_at   TEXT,
        status     TEXT NOT NULL,
        exit_code  INTEGER,
        bytes_written INTEGER NOT NULL DEFAULT 0,
        log_path   TEXT NOT NULL,
        summary    TEXT
    )""")
    conn.commit()
    started_at = iso_now()
    run_id = conn.execute(
        "INSERT INTO sync_runs (started_at, status, log_path, summary) VALUES (?, 'error', ?, 'running')",
        (started_at, str(log_path))
    ).lastrowid
    conn.commit()

    with open(log_path, "wb") as f:
        f.write(f"[SYNC START] {started_at}\nBAT: {BAT_PATH}\nCWD: {WORK_DIR}\n\n".encode())
        try:
            proc = subprocess.Popen(f'"{BAT_PATH}"', shell=True, cwd=WORK_DIR,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        except Exception as e:
            f.write(f"[spawn error] {e}\n".encode())
            conn.execute("UPDATE sync_runs SET ended_at=?, status='error', exit_code=-1, bytes_written=?, summary='spawn error' WHERE id=?",
                         (iso_now(), f.tell(), run_id))
            conn.commit(); conn.close()
            raise HTTPException(status_code=500, detail=str(e))

        out_bytes = 0
        for chunk in iter(lambda: proc.stdout.readline(), b""):
            if not chunk: break
            f.write(chunk); out_bytes += len(chunk)
        code = proc.wait()
        ended_at = iso_now()
        f.write(f"\n[SYNC END] {ended_at}  exit={code}\n".encode())

    status = "ok" if code == 0 else "error"
    conn.execute("""UPDATE sync_runs
                    SET ended_at=?, status=?, exit_code=?, bytes_written=?, summary=?
                    WHERE id=?""",
                 (ended_at, status, code, (log_path.stat().st_size if log_path.exists() else out_bytes), status, run_id))
    conn.commit(); conn.close()
    return {"ok": status == "ok", "code": code, "run_id": run_id, "log_path": str(log_path)}

@app.get("/api/sync/last")
def sync_last():
    conn = get_db(); conn.row_factory = sqlite3.Row
    row = conn.execute("""SELECT id, started_at, ended_at, status, exit_code, bytes_written, log_path, summary
                          FROM sync_runs ORDER BY started_at DESC LIMIT 1""").fetchone()
    conn.close()
    return dict(row) if row else None

@app.get("/api/health")
def health():
    return {"ok": True, "db_path": str(pathlib.Path(DB_PATH).resolve())}
