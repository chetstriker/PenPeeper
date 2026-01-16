@echo off
echo Starting system monitoring for PenPeeper scans...
echo Logs will be saved to C:\temp\penpeeper_logs\
echo.

:loop
echo [%date% %time%] System Status:
echo Memory Usage:
tasklist /FI "IMAGENAME eq flutter.exe" /FO TABLE | findstr flutter.exe
echo.
echo Process Count:
tasklist | find /c ".exe"
echo.
echo Temp Files:
dir /b temp_scan_* 2>nul | find /c /v ""
echo.
echo WSL Processes:
wsl.exe -u root -- ps aux | grep nmap | wc -l 2>nul
echo.
echo ----------------------------------------
timeout /t 10 /nobreak >nul
goto loop