# list_demo.py
# Show companies and contacts to verify the seed
# Usage:
#   set LS_MINI_DB_PATH=E:\life-support-mini\db\mini.db
#   python list_demo.py

import os, sqlite3, pathlib

db_path = os.environ.get("LS_MINI_DB_PATH") or "mini.db"
db_path = str(pathlib.Path(db_path).resolve())

conn = sqlite3.connect(db_path)
conn.row_factory = sqlite3.Row
try:
    print("\nALL_COMPANIES:")
    for row in conn.execute("SELECT * FROM ALL_COMPANIES ORDER BY company_type, company_name;"):
        print(dict(row))

    print("\nCONTACTS for GAT001 / DE-BER-1101 / COMP123:")
    for row in conn.execute("""
        SELECT contact_id, contact_name, role_title, email, phone
        FROM contact_grid
        WHERE gat_id='GAT001' AND city_id='DE-BER-1101' AND company_id='COMP123'
        ORDER BY contact_id DESC;
    """):
        print(dict(row))
finally:
    conn.close()
print("\nDone.")
