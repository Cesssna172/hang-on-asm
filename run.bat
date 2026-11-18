@echo off
cd /d "%~dp0"
if not exist bin\hangon.exe (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File build.ps1
    if errorlevel 1 (pause & exit /b 1)
)
start "" "%~dp0bin\hangon.exe"
