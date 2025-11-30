@echo off
echo Starting Redis Server...
start "" "C:\Program Files\Redis\redis-server.exe"
timeout /t 2 /nobreak >nul
echo Redis Server started!

