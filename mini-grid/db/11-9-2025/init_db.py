# init_db.py
# Initialize SQLite DB using Python 3.12 (no Node native modules required)
# Usage:
#   set LS_MINI_DB_PATH=E:\life-support-mini\db\mini.db
#   python init_db.py setup_mini.sql

import os, sys, sqlite3, pathlib

def main():
    db_path = os.environ.get("LS_MINI_DB_PATH") or "mini.db"
    sql_path = sys.argv[1] if len(sys.argv) > 1 else "setup_mini.sql"

    sql_path = str(pathlib.Path(sql_path).resolve())
    db_path = str(pathlib.Path(db_path).resolve())

    if not os.path.exists(sql_path):
        print("ERROR: SQL file not found:", sql_path)
        sys.exit(1)

    with open(sql_path, "r", encoding="utf-8") as f:
        sql = f.read()

    conn = sqlite3.connect(db_path)
    try:
        conn.executescript(sql)
        cur = conn.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;")
        tables = [row[0] for row in cur.fetchall()]
        print("Initialized DB at:", db_path)
        print("Tables:", ", ".join(tables))
    finally:
        conn.commit()
        conn.close()

if __name__ == "__main__":
    main()
