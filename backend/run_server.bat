@echo off
chcp 65001 >nul
rem Запуск сервера магазина. Окно не закрывайте, пока пользуетесь приложением.
cd /d "%~dp0"
if not exist .venv\Scripts\python.exe (
  echo Сначала запустите setup_windows.bat
  pause & exit /b 1
)
call .venv\Scripts\activate.bat
rem Новые изменения структуры базы применяются сами, данные сохраняются.
python -m alembic upgrade head || (pause & exit /b 1)
python server.py
pause
