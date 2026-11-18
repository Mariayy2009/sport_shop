@echo off
chcp 65001 >nul
rem Установка сервера магазина Sport Shop (один раз).
rem Перед запуском: установлен PostgreSQL и Python 3.10-3.12 (см. docs/postgresql.md).
cd /d "%~dp0"

if not exist .env (
  copy .env.example .env >nul
  echo Создан файл .env. Откройте его в Блокноте, впишите пароль PostgreSQL
  echo вместо ВАШ_ПАРОЛЬ, сохраните и запустите setup_windows.bat ещё раз.
  notepad .env
  pause & exit /b 1
)

echo === 1/4 Виртуальное окружение
py -3.12 -m venv .venv 2>nul || py -3.11 -m venv .venv 2>nul || py -3.10 -m venv .venv 2>nul || python -m venv .venv
if not exist .venv\Scripts\python.exe (
  echo Не найден Python 3.10-3.12. Установите его с python.org и запустите снова.
  pause & exit /b 1
)
call .venv\Scripts\activate.bat
python -m pip install --upgrade pip
pip install -r requirements.txt || goto :error

echo === 2/4 База данных sport_shop
python create_db.py || goto :error

echo === 3/4 Таблицы (миграции)
python -m alembic upgrade head || goto :error

echo === 4/4 Демо-каталог
python seed.py || goto :error

echo.
echo Готово. Запускайте сервер файлом run_server.bat
pause
exit /b 0

:error
echo.
echo Установка прервалась — текст ошибки выше. Пришлите его, если не понятно, что делать.
pause
exit /b 1
