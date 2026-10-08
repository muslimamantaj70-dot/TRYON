@echo off
git add .
git commit -m "Auto update"
git pull origin main
git push origin main
echo Done!
pause