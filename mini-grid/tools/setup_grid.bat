@echo off
set DB=E:\life-support-mini-grid\db\grid.db
set SQL=E:\life-support-mini-grid\db\setup_grid.sql

sqlite3.exe "%DB%" < "%SQL%"
echo ✅ Grid DB setup complete.
pause
