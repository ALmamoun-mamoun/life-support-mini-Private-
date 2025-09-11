# seed_demo.py
# Add one Prospect and one Contact to your mini.db
# Usage:
#   set LS_MINI_DB_PATH=E:\life-support-mini\db\mini.db
#   python seed_demo.py

import os, sqlite3, pathlib, datetime

db_path = os.environ.get("LS_MINI_DB_PATH") or "mini.db"
db_path = str(pathlib.Path(db_path).resolve())

trio = ("GAT001", "DE-BER-1101", "COMP123")

sqls = [
    # Prospect upsert
    ("""INSERT INTO prospects (gat_id, city_id, company_id, prospect_name)
        VALUES (?, ?, ?, 'Berlin Medical Supplies')
        ON CONFLICT(gat_id, city_id, company_id)
        DO UPDATE SET prospect_name=excluded.prospect_name;""", trio),
    # Contact insert
    ("""INSERT INTO contact_grid (gat_id, city_id, company_id, contact_name, role_title, email, phone, notes)
        VALUES (?, ?, ?, 'Dr. Anna Müller', 'Chief Medical Officer', 'anna.mueller@example.com', '+49-30-1234567', 'Prefers morning calls.');""", trio),
]

conn = sqlite3.connect(db_path)
try:
    for q, params in sqls:
        conn.execute(q, params)
    conn.commit()
    print("Seeded prospect + contact into", db_path)
finally:
    conn.close()
