@echo off
title Forgeron - Serveur Reco3D Scan 3D
echo ========================================================
echo   DEMARRAGE DU SERVEUR DE CALCUL SCAN 3D FORGERON
echo ========================================================
echo Port HTTP       : 8765
echo Port UDP (Auto) : 8766
echo.

set PYTHON="C:\Users\CITT Unipod\AppData\Local\Programs\Python\Python312\python.exe"
if not exist %PYTHON% (
    set PYTHON=python
)

%PYTHON% -m uvicorn service:app --app-dir tool/reco3d --host 0.0.0.0 --port 8765
pause
