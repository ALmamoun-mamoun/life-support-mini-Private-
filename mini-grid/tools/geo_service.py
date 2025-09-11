import sys, json, sqlite3
DB = r"E:\life-support-mini\db\mini.db"

def countries():
    con = sqlite3.connect(DB)
    rows = [{"cc": cc, "name": name}
            for cc,name in con.execute("SELECT cc,name FROM country ORDER BY name")]
    con.close()
    print(json.dumps(rows, ensure_ascii=False))

def cities(cc):
    con = sqlite3.connect(DB)
    rows = [{"name": name, "abbr": abbr}
            for (name,abbr) in con.execute("""
              SELECT ci.name, ci.abbr
              FROM country c JOIN city ci ON ci.country_id=c.id
              WHERE UPPER(c.cc)=?
              ORDER BY ci.name
            """, (cc.upper(),))]
    con.close()
    print(json.dumps({"cc": cc.upper(), "cities": rows}, ensure_ascii=False))

if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1].lower() == "countries":
        countries()
    elif len(sys.argv) >= 3 and sys.argv[1].lower() == "cities":
        cities(sys.argv[2])
    else:
        sys.exit(2)
