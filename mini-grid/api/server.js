// --- imports ---
const express = require("express");
const cors = require("cors");
const path = require("path");
const fs = require("fs");
const { spawnSync } = require("child_process");

// --- app setup ---
const app = express();
app.use(cors());
app.use(express.json());

// --- config ---
const ROOT = path.join(__dirname, "..");
const DB_PATH_GRID =
  process.env.LS_GRID_DB_PATH || path.join(ROOT, "db", "grid.db");
const PYTHON = process.env.PYTHON || "python";

// HQ Main (unchanged)
const MAIN_URL = process.env.LS_MAIN_URL || "http://127.0.0.1:4011";

// Mini-Main (initial, before remote overrides)
let MINI_URL = process.env.LS_MINI_URL || "http://127.0.0.1:3001";

// Runtime files on Android
const DROP_DIR = "/sdcard/LifeSupport";

// --- helper: run inline Python for SQLite ops ---
function runPyCode(code, jsonInput) {
  return spawnSync(PYTHON, ["-c", code], {
    input: JSON.stringify(jsonInput || {}),
    env: { ...process.env, LS_GRID_DB_PATH: DB_PATH_GRID },
    encoding: "utf8",
    maxBuffer: 10 * 1024 * 1024,
  });
}

function ensureDropDir() {
  try { fs.mkdirSync(DROP_DIR, { recursive: true }); } catch {}
}

// Read list from /sdcard/LifeSupport/locators.txt (one URL per line)
function readLocatorFileList() {
  try {
    const txt = fs.readFileSync(path.join(DROP_DIR, "locators.txt"), "utf8");
    return txt.split(/\r?\n/).map(s => s.trim()).filter(Boolean);
  } catch { return []; }
}

// Read single domain URL from /sdcard/LifeSupport/domain.txt
function readDomainFromFile() {
  try {
    return fs.readFileSync(path.join(DROP_DIR, "domain.txt"), "utf8").trim();
  } catch { return ""; }
}

const LOCATOR_URLS = [
  process.env.LS_LOCATOR1,
  process.env.LS_LOCATOR2,
  process.env.LS_LOCATOR3,
  ...readLocatorFileList(),
].filter(Boolean);

// Final domain fallback endpoint
let DOMAIN_URL = (process.env.LS_DOMAIN_URL || readDomainFromFile() || "").trim();

// --- helpers: decoding and probing ---
function decodeUrlFromFilename(basename) {
  // Expect names like: http___10.100.159.247_3001.txt  → http://10.100.159.247:3001
  // or:                https___example.com_3001.txt    → https://example.com:3001
  const name = basename.replace(/\.txt$/i, "");
  let s = name.replace(/^http___/, "http://").replace(/^https___/, "https://");
  const i = s.lastIndexOf("_");
  if (i !== -1) s = s.slice(0, i) + ":" + s.slice(i + 1);
  return s;
}

async function probeMiniUrl(fetch) {
  try {
    const r = await fetch(`${MINI_URL}/health`, { method: "GET" });
    return r.ok;
  } catch { return false; }
}

function saveOverrideMarkerFileFromUrl(urlString) {
  try {
    ensureDropDir();
    // Turn http://a.b.c:3001 → http___a.b.c_3001.txt
    const u = new URL(urlString);
    const base = `${u.protocol.replace(":", "")}___${u.hostname}_${u.port || (u.protocol==="https:"?"443":"80")}.txt`;
    fs.writeFileSync(path.join(DROP_DIR, base), "");
  } catch {}
}

function extractFilenameFromResponse(r) {
  // 1) Content-Disposition
  const cd = r.headers.get("content-disposition");
  if (cd) {
    const m1 = /filename\*=(?:UTF-8''|)([^;]+)/i.exec(cd);
    const m2 = /filename=([^;]+)/i.exec(cd);
    let fn = (m1 && m1[1]) || (m2 && m2[1]);
    if (fn) return fn.replace(/['"]/g, "").trim();
  }
  // 2) Final URL path
  try {
    const u = new URL(r.url);
    return decodeURIComponent(path.basename(u.pathname));
  } catch { return ""; }
}

// --- remote fallbacks ---
async function tryLocatorsForMiniUrl(fetch) {
  for (const loc of LOCATOR_URLS) {
    try {
      const r = await fetch(loc, { redirect: "follow" });
      const filename = extractFilenameFromResponse(r);
      if (!filename) continue;
      const candidate = decodeUrlFromFilename(filename);
      if (candidate.startsWith("http")) {
        MINI_URL = candidate;
        console.log(`MINI_URL set via locator ${loc} → ${MINI_URL}`);
        saveOverrideMarkerFileFromUrl(MINI_URL);
        return true;
      }
    } catch {}
  }
  return false;
}

async function tryDomainForMiniUrl(fetch) {
  if (!DOMAIN_URL) return false;
  try {
    const r = await fetch(DOMAIN_URL, { redirect: "follow" });
    const filename = extractFilenameFromResponse(r);
    if (!filename) return false;
    const candidate = decodeUrlFromFilename(filename);
    if (candidate.startsWith("http")) {
      MINI_URL = candidate;
      console.log(`MINI_URL set via domain ${DOMAIN_URL} → ${MINI_URL}`);
      saveOverrideMarkerFileFromUrl(MINI_URL);
      return true;
    }
  } catch {}
  return false;
}

// --- health check ---
app.get("/health", (req, res) => {
  res.json({
    ok: true,
    db: DB_PATH_GRID,
    python: PYTHON,
    main_url: MAIN_URL,
    mini_url: MINI_URL,
    locators: LOCATOR_URLS,
    domain_url: DOMAIN_URL || null,
  });
});

// --- GRID companies list ---
app.get("/grid/companies", (req, res) => {
  const limit = Math.max(1, Math.min(parseInt(req.query.limit || "50", 10), 200));
  const offset = Math.max(0, parseInt(req.query.offset || "0", 10));
  const q = (req.query.q || "").trim();

  const py = `
import sys, json, sqlite3
d = json.load(sys.stdin)
db = d["db"]
q = (d.get("q","") or "").strip()
limit  = int(d.get("limit",50))
offset = int(d.get("offset",0))

con = sqlite3.connect(db)
con.row_factory = sqlite3.Row
cur = con.cursor()
base = "SELECT guid, company_name, website_url, email, phone, notes, main_id, cc, ccc FROM grid_companies"

if q:
    cur.execute(base + " WHERE company_name LIKE ? COLLATE NOCASE ORDER BY company_name COLLATE NOCASE LIMIT ? OFFSET ?", (f"%{q}%", limit, offset))
    items = [dict(r) for r in cur.fetchall()]
    cur.execute("SELECT COUNT(*) AS n FROM grid_companies WHERE company_name LIKE ? COLLATE NOCASE", (f"%{q}%",))
    total = cur.fetchone()[0]
else:
    cur.execute(base + " ORDER BY company_name COLLATE NOCASE LIMIT ? OFFSET ?", (limit, offset))
    items = [dict(r) for r in cur.fetchall()]
    cur.execute("SELECT COUNT(*) AS n FROM grid_companies")
    total = cur.fetchone()[0]

con.close()
print(json.dumps({"ok": True, "items": items, "total": total, "limit": limit, "offset": offset}))
`;
  const r = runPyCode(py, { db: DB_PATH_GRID, q, limit, offset });
  if (r.status !== 0)
    return res.status(500).json({ ok: false, error: "python_failed", stderr: r.stderr });
  try {
    return res.json(JSON.parse(r.stdout));
  } catch {
    return res
      .status(500)
      .json({ ok: false, error: "bad_python_output", stdout: r.stdout, stderr: r.stderr });
  }
});

// --- SYNC: fetch updates from Main ---
app.get("/sync/fetch", async (req, res) => {
  try {
    const fetch = (await import("node-fetch")).default;
    const r = await fetch(`${MAIN_URL}/sync/export`);
    const j = await r.json();
    if (!j.ok) return res.status(500).json(j);

    const py = `
import sys, json, sqlite3
d = json.load(sys.stdin)
db = d["db"]
updates = d.get("updates", [])

con = sqlite3.connect(db)
cur = con.cursor()

for u in updates:
    cur.execute("UPDATE grid_companies SET main_id=?, lobby_flag=0 WHERE guid=? AND cc=? AND ccc=?",
                (u.get("company_id"), u.get("guid"), u.get("cc"), u.get("ccc")))

con.commit()
con.close()
print(json.dumps({"ok": True, "updated": len(updates)}))
`;
    const r2 = runPyCode(py, { db: DB_PATH_GRID, updates: j.updates });
    if (r2.status !== 0)
      return res
        .status(500)
        .json({ ok: false, error: "python_failed", stderr: r2.stderr });
    return res.json(JSON.parse(r2.stdout));
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

// --- Proxy: phone → Mini-Grid → Mini-Main (allocate ID) ---
app.post("/grid/allocate", async (req, res) => {
  try {
    const fetch = (await import("node-fetch")).default;

    // 1) Probe current MINI_URL
    let ok = await probeMiniUrl(fetch);
    if (!ok) {
      // 2) Try locators
      ok = await tryLocatorsForMiniUrl(fetch);
      if (!ok) {
        // 3) Try final domain fallback
        ok = await tryDomainForMiniUrl(fetch);
        if (!ok) return res.status(502).json({ ok: false, error: "mini_unreachable_after_locators_and_domain" });
      }
    }

    const r = await fetch(`${MINI_URL}/mini/allocate`, { method: "POST" });
    const j = await r.json();
    if (!j.ok)
      return res.status(502).json({ ok: false, error: "mini_allocate_failed", j });
    res.json(j);
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

// --- Proxy: phone → Mini-Grid → Mini-Main (save company) ---
app.post("/grid/save", async (req, res) => {
  try {
    const fetch = (await import("node-fetch")).default;

    // 1) Probe current MINI_URL
    let ok = await probeMiniUrl(fetch);
    if (!ok) {
      // 2) Try locators
      ok = await tryLocatorsForMiniUrl(fetch);
      if (!ok) {
        // 3) Try final domain fallback
        ok = await tryDomainForMiniUrl(fetch);
        if (!ok) return res.status(502).json({ ok: false, error: "mini_unreachable_after_locators_and_domain" });
      }
    }

    const r = await fetch(`${MINI_URL}/mini/save`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(req.body || {}),
    });
    const j = await r.json();
    if (!j.ok)
      return res.status(502).json({ ok: false, error: "mini_save_failed", j });
    res.json(j);
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

// --- Auto-Flag state (stored in SQLite) ---
app.get("/auto-flag", (req, res) => {
  const py = `
import sys, json, sqlite3
d = json.load(sys.stdin)
db = d["db"]

con = sqlite3.connect(db)
cur = con.cursor()
cur.execute("SELECT value FROM grid_settings WHERE key='auto_flag'")
row = cur.fetchone()
con.close()

val = row[0] if row else '0'
print(json.dumps({"ok": True, "auto_flag": val == '1'}))
`;
  const r = runPyCode(py, { db: DB_PATH_GRID });
  if (r.status !== 0)
    return res.status(500).json({ ok: false, error: "python_failed", stderr: r.stderr });
  res.json(JSON.parse(r.stdout));
});

app.post("/auto-flag", (req, res) => {
  const py = `
import sys, json, sqlite3
d = json.load(sys.stdin)
db = d["db"]
val = '1' if d.get("auto_flag") else '0'

con = sqlite3.connect(db)
cur = con.cursor()
cur.execute("INSERT OR REPLACE INTO grid_settings (key, value) VALUES ('auto_flag', ?)", (val,))
con.commit()
con.close()

print(json.dumps({"ok": True, "auto_flag": val == '1'}))
`;
  const r = runPyCode(py, { db: DB_PATH_GRID, auto_flag: req.body.auto_flag });
  if (r.status !== 0)
    return res.status(500).json({ ok: false, error: "python_failed", stderr: r.stderr });
  res.json(JSON.parse(r.stdout));
});

// --- static files ---
app.use(express.static(path.join(ROOT, "ui")));
console.log("Serving static files from:", path.join(ROOT, "ui"));

// --- listen ---
app.listen(3011, () =>
  console.log(`Grid API on http://0.0.0.0:3011 (DB: ${DB_PATH_GRID})`)
);
