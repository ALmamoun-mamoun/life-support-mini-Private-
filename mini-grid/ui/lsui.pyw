
# lsui.pyw - Life-Support Mini UI (fixed path detection for PyInstaller onefile)
# Place this file inside your Mini folder:
#   E:\life-support-project\life-support-starter-mini-main\
# It will locate life-support-api.exe and config.mini.json in the same folder.

import subprocess, sys, os
import tkinter as tk
from tkinter import ttk, messagebox, simpledialog

def app_dir():
    # When frozen by PyInstaller, sys.executable is the path of the .exe on disk.
    if getattr(sys, "frozen", False):
        return os.path.dirname(sys.executable)
    # When running as .pyw script
    return os.path.dirname(os.path.abspath(__file__))

APP_DIR = app_dir()
EXE = os.path.join(APP_DIR, "life-support-api.exe")
CFG = os.path.join(APP_DIR, "config.mini.json")
SYNC_BAT = os.path.join(APP_DIR, "sync_mini.bat")

def run_cmd(args):
    try:
        p = subprocess.run(args, capture_output=True, text=True, cwd=APP_DIR, shell=False)
        return p.returncode, p.stdout.strip(), p.stderr.strip()
    except Exception as e:
        return 1, "", str(e)

def list_records():
    if not os.path.exists(EXE) or not os.path.exists(CFG):
        messagebox.showerror("Missing files", "life-support-api.exe or config.mini.json not found in this folder:\n" + APP_DIR)
        return []
    code, out, err = run_cmd([EXE, "list", "--config", CFG])
    if code != 0:
        messagebox.showerror("List error", (err or out or "Unknown error"))
        return []
    rows = []
    for line in out.splitlines():
        parts = [p.strip() for p in line.split("|")]
        if len(parts) < 4:
            continue
        guid = parts[0]; source = parts[1]; seek_part = parts[2]; version_part = parts[3]
        seek="0"; pri="0"; status=""
        for t in seek_part.replace("  "," ").split():
            if t.startswith("seek="): seek = t.split("=",1)[1]
            elif t.startswith("pri="): pri = t.split("=",1)[1]
            else: status = t
        rows.append((guid, source, seek, pri, status, version_part))
    return rows

def refresh():
    for i in tree.get_children(): tree.delete(i)
    for row in list_records(): tree.insert("", "end", values=row)

def get_selected():
    sel = tree.selection()
    if not sel:
        messagebox.showinfo("Select a record", "Please select a record first.")
        return None
    return tree.item(sel[0], "values")[0]  # guid

def toggle_seek():
    guid = get_selected()
    if not guid: return
    # read current from tree
    vals = tree.item(tree.selection()[0], "values")
    current = vals[2]
    args = [EXE, "seek", "--guid", guid, "--config", CFG]
    if current == "1":
        args.append("--off")
    else:
        args.append("--on")
    code, out, err = run_cmd(args)
    if code != 0:
        messagebox.showerror("Seek error", (err or out or "Unknown error"))
        return
    refresh()

def set_priority():
    guid = get_selected()
    if not guid: return
    try:
        val = simpledialog.askinteger("Set Priority", "Priority (0..5):", minvalue=0, maxvalue=5)
        if val is None: return
    except Exception:
        return
    code, out, err = run_cmd([EXE, "seek", "--guid", guid, "--priority", str(val), "--config", CFG])
    if code != 0:
        messagebox.showerror("Priority error", (err or out or "Unknown error"))
        return
    refresh()

def do_sync():
    if os.path.exists(SYNC_BAT):
        code, out, err = run_cmd([SYNC_BAT])
    else:
        code, out, err = run_cmd([EXE, "sync", "--auto", "--config", CFG])
    if code != 0:
        messagebox.showerror("Sync error", (err or out or "Unknown error"))
        return
    messagebox.showinfo("Sync", "Sync complete.")
    refresh()

# UI setup
root = tk.Tk()
root.title("Life-Support Mini")

frm = ttk.Frame(root, padding=10); frm.pack(fill="both", expand=True)
bar = ttk.Frame(frm); bar.pack(fill="x", pady=(0,8))
ttk.Button(bar, text="Refresh", command=refresh).pack(side="left")
ttk.Button(bar, text="Toggle Seek", command=toggle_seek).pack(side="left", padx=6)
ttk.Button(bar, text="Set Priority", command=set_priority).pack(side="left", padx=6)
ttk.Button(bar, text="Sync", command=do_sync).pack(side="left", padx=6)

cols = ("GUID","Source","Seek","Priority","Status","Version")
tree = ttk.Treeview(frm, columns=cols, show="headings", height=14)
for c in cols:
    tree.heading(c, text=c)
    tree.column(c, width=120 if c!="GUID" else 320, anchor="w")
tree.pack(fill="both", expand=True)

refresh()
root.mainloop()
