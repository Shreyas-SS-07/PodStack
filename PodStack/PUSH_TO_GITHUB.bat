@echo off
echo ================================================
echo  PodStack – GitHub Upload Script
echo  Run this in Git Bash or WSL, NOT cmd/PowerShell
echo ================================================
echo.
echo Step 1: Open Git Bash (right-click Desktop -> "Git Bash Here")
echo         then paste the commands below:
echo.
echo cd /c/Users/KIIT/Downloads/PodStack
echo git init
echo git add .
echo git commit -m "feat: PodStack rootless container platform capstone"
echo git branch -M main
echo git remote add origin https://github.com/YOUR_USERNAME/PodStack.git
echo git push -u origin main
echo.
echo NOTE: Replace YOUR_USERNAME with your GitHub username!
pause
