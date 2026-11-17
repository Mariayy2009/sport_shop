@echo off
chcp 65001 >nul
rem Запуск сервера примерки. Окно не закрывайте, пока пользуетесь примеркой.
cd /d "%~dp0"
if not exist .venv\Scripts\python.exe (
  echo Сначала запустите setup_windows.bat
  pause & exit /b 1
)
call .venv\Scripts\activate.bat
rem Шагов генерации: 6 — быстро и уже хорошо, 10–12 — аккуратнее мелкие надписи, но дольше.
if "%TRYON_STEPS%"=="" set TRYON_STEPS=6
python server.py
pause
