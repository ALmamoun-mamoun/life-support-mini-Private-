
#!/usr/bin/env python3
"""Life-Support API CLI v2 (timezone fix + list command)"""
import argparse, json, os, sqlite3, sys, zipfile
from datetime import datetime, UTC
from pathlib import Path

def load_config(path: str):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

def connect_db(cfg):
    dbp = cfg["db"]["path"]
    Path(dbp).parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(dbp)
    conn.row_factory = sqlite3.Row
    return conn

def run_sql_file(conn, schema_path):
    with open(schema_path, "r", encoding="utf-8") as f:
        sql = f.read()
    conn.executescript(sql)
    conn.commit()

def ensure_inbox_outbox(cfg):
    inbox = Path(cfg["paths"]["inbox"])
    outbox = Path(cfg["paths"]["outbox"])
    inbox.mkdir(parents=True, exist_ok=True)
    outbox.mkdir(parents=True, exist_ok=True)
    return inbox, outbox

def now_iso():
    return datetime.now(UTC).strftime("%Y-%m-%dT%H-%M-%SZ")

def export_bundle(conn, cfg, out_path: Path):
    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    cur = conn.cursor()
    def dump_jsonl(query, params=()):
        cur.execute(query, params)
        rows = cur.fetchall()
        lines = [json.dumps(dict(r)) for r in rows]
        return "\n".join(lines)

    records = dump_jsonl("SELECT * FROM records")
    notes = dump_jsonl("SELECT * FROM record_notes")
    hist = dump_jsonl("SELECT * FROM record_history")
    rdoc = dump_jsonl("SELECT * FROM record_doctors")

    manifest = {
        "bundle_guid": f"bundle-{now_iso()}",
        "direction": "auto",
        "producer": cfg.get("agent", {}).get("id", cfg.get("role", "unknown")),
        "created_at": datetime.now(UTC).isoformat().replace("+00:00","Z"),
        "schema_version": "1.0.0",
        "entities": {
            "records": 0 if not records else len(records.splitlines()),
            "record_notes": 0 if not notes else len(notes.splitlines()),
            "record_history": 0 if not hist else len(hist.splitlines()),
            "record_doctors": 0 if not rdoc else len(rdoc.splitlines()),
        },
        "encryption": {"alg": "none"}
    }

    with zipfile.ZipFile(out_path, "w", compression=zipfile.ZIP_DEFLATED) as z:
        z.writestr("manifest.json", json.dumps(manifest, indent=2))
        z.writestr("records.jsonl", records)
        z.writestr("record_notes.jsonl", notes)
        z.writestr("record_history.jsonl", hist)
        z.writestr("record_doctors.jsonl", rdoc)

    print(f"Exported: {out_path}")

def upsert_record(conn, rec: dict):
    cur = conn.cursor()
    cur.execute("SELECT * FROM records WHERE guid = ?", (rec["guid"],))
    existing = cur.fetchone()
    if existing is None:
        fields = ", ".join(rec.keys())
        qmarks = ", ".join(["?"]*len(rec))
        cur.execute(f"INSERT INTO records ({fields}) VALUES ({qmarks})", tuple(rec.values()))
        return "insert"
    else:
        ev = existing["version"]
        iv = rec.get("version", 0)
        if iv > ev:
            cols = [k for k in rec.keys() if k != "id"]
            sets = ", ".join([f"{k}=?" for k in cols])
            values = [rec[k] for k in cols]
            values.append(existing["id"])
            cur.execute(f"UPDATE records SET {sets} WHERE id=?", values)
            return "update"
        elif iv == ev:
            try:
                if rec.get("updated_at","") > (existing["updated_at"] or ""):
                    cols = [k for k in rec.keys() if k != "id"]
                    sets = ", ".join([f"{k}=?" for k in cols])
                    values = [rec[k] for k in cols]
                    values.append(existing["id"])
                    cur.execute(f"UPDATE records SET {sets} WHERE id=?", values)
                    return "update"
            except Exception:
                pass
        return "skip"

def import_bundle(conn, cfg, in_path: Path):
    in_path = Path(in_path)
    assert in_path.exists(), f"file not found: {in_path}"
    with zipfile.ZipFile(in_path, "r") as z:
        _ = json.loads(z.read("manifest.json").decode("utf-8"))
        def iter_jsonl(name):
            if name in z.namelist():
                data = z.read(name).decode("utf-8").strip()
                if data:
                    for line in data.splitlines():
                        yield json.loads(line)

        cur = conn.cursor()
        applied = {"insert":0,"update":0,"skip":0}
        for rec in iter_jsonl("records.jsonl"):
            action = upsert_record(conn, rec)
            applied[action]+=1

        for note in iter_jsonl("record_notes.jsonl"):
            cur.execute("SELECT 1 FROM record_notes WHERE guid=?", (note["guid"],))
            if cur.fetchone() is None:
                fields = ", ".join(note.keys())
                qmarks = ", ".join(["?"]*len(note))
                cur.execute(f"INSERT INTO record_notes ({fields}) VALUES ({qmarks})", tuple(note.values()))

        for h in iter_jsonl("record_history.jsonl"):
            cur.execute("SELECT 1 FROM record_history WHERE guid=?", (h["guid"],))
            if cur.fetchone() is None:
                fields = ", ".join(h.keys())
                qmarks = ", ".join(["?"]*len(h))
                cur.execute(f"INSERT INTO record_history ({fields}) VALUES ({qmarks})", tuple(h.values()))

        for rd in iter_jsonl("record_doctors.jsonl"):
            cur.execute("SELECT 1 FROM record_doctors WHERE guid=?", (rd["guid"],))
            if cur.fetchone() is None:
                fields = ", ".join(rd.keys())
                qmarks = ", ".join(["?"]*len(rd))
                cur.execute(f"INSERT INTO record_doctors ({fields}) VALUES ({qmarks})", tuple(rd.values()))

        conn.commit()
        print(f"Imported bundle {in_path.name}: {applied}")

def cmd_init(args):
    cfg = load_config(args.config)
    conn = connect_db(cfg)
    run_sql_file(conn, args.schema)
    conn.execute("CREATE TABLE IF NOT EXISTS meta (k TEXT PRIMARY KEY, v TEXT)")
    conn.commit()
    print(f"Initialized DB at {cfg['db']['path']} with schema {args.schema}")

def cmd_export(args):
    cfg = load_config(args.config)
    conn = connect_db(cfg)
    export_bundle(conn, cfg, Path(args.out))

def cmd_import(args):
    cfg = load_config(args.config)
    conn = connect_db(cfg)
    import_bundle(conn, cfg, Path(args.file))

def cmd_sync_auto(args):
    cfg = load_config(args.config)
    conn = connect_db(cfg)
    inbox, outbox = ensure_inbox_outbox(cfg)

    for p in sorted(inbox.glob("*.lsx")):
        try:
            import_bundle(conn, cfg, p)
            p.unlink()
        except Exception as e:
            print(f"ERROR importing {p.name}: {e}")

    ts = now_iso()
    out = outbox / f"bundle_{ts}.lsx"
    try:
        export_bundle(conn, cfg, out)
    except Exception as e:
        print(f"ERROR exporting: {e}")

    shared = cfg["paths"].get("shared_main_inbox")
    if shared and os.path.exists(shared):
        try:
            import shutil
            shutil.copy2(out, shared)
            print(f"Copied {out.name} to {shared}")
        except Exception as e:
            print(f"NOTE: could not copy to shared inbox: {e}")

def cmd_seek(args):
    cfg = load_config(args.config)
    conn = connect_db(cfg)
    cur = conn.cursor()
    cur.execute("SELECT 1 FROM records WHERE guid=?", (args.guid,))
    if cur.fetchone() is None:
        print("Record not found:", args.guid)
        return
    sets = []
    params = []
    if args.on:
        sets.append("to_seek=?"); params.append(1)
        sets.append("seek_status=?"); params.append("queued")
    if args.off:
        sets.append("to_seek=?"); params.append(0)
        sets.append("seek_status=?"); params.append("paused")
    if args.priority is not None:
        sets.append("seek_priority=?"); params.append(int(args.priority))
    if args.status is not None:
        sets.append("seek_status=?"); params.append(args.status)
    sets.append("version=version+1")
    sets.append("updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now')")
    sql = f"UPDATE records SET {', '.join(sets)} WHERE guid=?"
    params.append(args.guid)
    cur.execute(sql, tuple(params))
    conn.commit()
    print("Updated seek:", args.guid)

def cmd_list(args):
    cfg = load_config(args.config)
    conn = connect_db(cfg)
    cur = conn.cursor()
    cur.execute("SELECT guid, source_name, to_seek, seek_priority, seek_status, version FROM records ORDER BY updated_at DESC LIMIT ?", (args.limit,))
    rows = cur.fetchall()
    if not rows:
        print("No records.")
        return
    for r in rows:
        print(f"{r['guid']}  | {r['source_name']} | seek={r['to_seek']} pri={r['seek_priority']} {r['seek_status']} | v{r['version']}")

def main():
    parser = argparse.ArgumentParser(prog="life-support-api", description="Life-Support API CLI")
    sub = parser.add_subparsers(dest="cmd")

    p_init = sub.add_parser("init")
    p_init.add_argument("--role", choices=["mini","main"], required=True)
    p_init.add_argument("--config", required=True)
    p_init.add_argument("--schema", required=True)
    p_init.set_defaults(func=cmd_init)

    p_export = sub.add_parser("export")
    p_export.add_argument("--scope", default="assigned")
    p_export.add_argument("--out", required=True)
    p_export.add_argument("--config", required=True)
    p_export.set_defaults(func=cmd_export)

    p_import = sub.add_parser("import")
    p_import.add_argument("--file", required=True)
    p_import.add_argument("--config", required=True)
    p_import.set_defaults(func=cmd_import)

    p_sync = sub.add_parser("sync")
    p_sync.add_argument("--auto", action="store_true")
    p_sync.add_argument("--config", required=True)
    p_sync.set_defaults(func=cmd_sync_auto)

    p_seek = sub.add_parser("seek")
    p_seek.add_argument("--guid", required=True)
    onoff = p_seek.add_mutually_exclusive_group()
    onoff.add_argument("--on", action="store_true")
    onoff.add_argument("--off", action="store_true")
    p_seek.add_argument("--priority", type=int)
    p_seek.add_argument("--status", choices=["queued","in_progress","paused","done"])
    p_seek.add_argument("--config", required=True)
    p_seek.set_defaults(func=cmd_seek)

    p_list = sub.add_parser("list")
    p_list.add_argument("--config", required=True)
    p_list.add_argument("--limit", type=int, default=10)
    p_list.set_defaults(func=cmd_list)

    args = parser.parse_args()
    if not hasattr(args, "func"):
        parser.print_help()
        sys.exit(1)
    args.func(args)

if __name__ == "__main__":
    main()
