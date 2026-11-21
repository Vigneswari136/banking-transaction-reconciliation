@echo off
echo ===================================================
echo   FINRECON - Bank Finance & Reconciliation App
echo ===================================================
echo.

echo [1/2] Starting Spring Boot Backend (Port 8080)...
start "FINRECON Backend (Spring Boot)" cmd /k "cd /d "%~dp0backend" && mvnw.cmd spring-boot:run"

echo [2/2] Starting Frontend Vite Dev Server (Port 5173)...
start "FINRECON Frontend (Vite React)" cmd /k "cd /d "%~dp0frontend" && npm run dev"

echo.
echo Both servers are starting up:
echo   - Backend API: http://localhost:8080
echo   - Frontend UI:  http://localhost:5173
echo   - Default Login: admin / Password@123
echo.
timeout /t 5 >nul
start http://localhost:5173
