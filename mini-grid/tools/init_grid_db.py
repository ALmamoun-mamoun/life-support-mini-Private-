import sqlite3, pathlib
db = r"E:\life-support-mini-grid\db\mini.db"
sql= pathlib.Path(r"E:\life-support-mini-grid\db\init_db.sql").read_text(encoding="utf-8")
con=sqlite3.connect(db); con.executescript(sql); con.commit(); con.close()
print("Initialized", db)
