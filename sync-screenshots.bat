@echo off
REM Auto-sync screenshots to git repository

echo Syncing screenshots...

REM Copy all screenshots from OneDrive to repo
xcopy "C:\Users\jimjj\OneDrive\Pictures\Screenshots\*.png" "C:\Users\jimjj\Documents\my-trading-work\screenshots\" /Y /I

REM Navigate to repo
cd /d "C:\Users\jimjj\Documents\my-trading-work"

REM Add all screenshots
git add screenshots\*.png

REM Commit if there are changes
git diff-index --quiet HEAD || git commit -m "Auto-sync screenshots"

REM Push to current branch
git push

echo Done!
pause
