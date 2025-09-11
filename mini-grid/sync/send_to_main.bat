@echo off
if not exist "E:\life-support-project\main-test\inbox" mkdir "E:\life-support-project\main-test\inbox"
copy /Y "E:\life-support-project\life-support-starter-mini-main\outbox\*.lsx" "E:\life-support-project\main-test\inbox\"
pause
