@echo off
cd /d C:\Users\333\AndroidStudioProjects\glass_ui
git branch -M main
git remote add origin https://github.com/vietany/glass_ui_music
git add .
git commit -m "Auto update %date:~0,10% %time:~0,8%"
git push -u origin main
pause