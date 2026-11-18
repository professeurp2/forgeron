@echo off
echo [Forgeron] Activation du point d'acces WiFi Professeur20...
powershell -ExecutionPolicy Bypass -File "%~dp0scratch\start_hotspot.ps1"
echo.
pause

