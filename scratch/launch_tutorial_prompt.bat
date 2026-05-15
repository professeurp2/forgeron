REM Copier le meta-prompt dans le presse-papiers puis l'envoyer à gemini CLI
REM Usage : double-cliquer sur ce fichier OU lancer dans le terminal Forgeron

type "C:\Users\CITT Unipod\.gemini\antigravity\brain\174db762-67d6-40fd-a881-d9a58c503d59\meta_prompt_tutorial.md" | clip
echo [OK] Meta-prompt copié dans le presse-papiers.
echo.
echo Maintenant dans ton terminal Forgeron, tape :
echo.
echo   gemini -p "$(cat scratch/meta_prompt_tutorial.md)"
echo.
pause
