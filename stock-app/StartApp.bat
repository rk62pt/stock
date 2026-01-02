@echo off
setlocal
title Taiwan Stock App Launcher

echo ===========================================
echo Starting Taiwan Stock App...
echo ===========================================

:: Change to the project directory
cd /d "C:\Users\RyanYang\googleWorker\Stock\stock-app"

:: Open the browser (give it a few seconds to start)
echo Opening browser...
timeout /t 3 >nul
start "" "http://localhost:3300"

:: Start the Next.js development server
echo Starting server...
npm run dev

endlocal
