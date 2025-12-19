@echo off
echo Starting Redis Server...

REM 1) Try redis-server from PATH
where redis-server >nul 2>&1
if %ERRORLEVEL%==0 (
	start "" redis-server
	echo Started redis-server from PATH.
	goto :done
)

REM 2) Try common install path
if exist "C:\Program Files\Redis\redis-server.exe" (
	start "" "C:\Program Files\Redis\redis-server.exe"
	echo Started redis-server from C:\Program Files\Redis\
	goto :done
)

REM 3) Try searching common folders using PowerShell (first result)
set "FOUND="
for /f "usebackq delims=" %%p in (`powershell -NoProfile -Command "Get-ChildItem -Path 'C:\Program Files','C:\Program Files (x86)','C:\Tools','C:\Redis' -Filter redis-server.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName"`) do set "FOUND=%%p"
if defined FOUND (
	start "" "%FOUND%"
	echo Started redis-server from %FOUND%
	goto :done
)

echo.
echo Could not find redis-server.exe on PATH or in common locations.
echo Options:
echo  - Install Redis for Windows and place redis-server.exe under C:\Program Files\Redis\
echo  - Add Redis to PATH and re-run this script
echo  - Run Redis in Docker: docker run -d --name redis -p 6379:6379 redis:7
echo  - Install WSL and run: wsl sudo apt install redis-server
echo.
pause

:done
echo Redis start command issued.

