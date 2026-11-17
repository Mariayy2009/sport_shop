@echo off
chcp 65001 >nul
rem Установка сервера примерки Sport Shop (один раз).
rem Нужен Python 3.10, 3.11 или 3.12 с python.org (галочка "Add to PATH").
cd /d "%~dp0"

echo === 1/5 Виртуальное окружение
py -3.12 -m venv .venv 2>nul || py -3.11 -m venv .venv 2>nul || py -3.10 -m venv .venv 2>nul || python -m venv .venv
if not exist .venv\Scripts\python.exe (
  echo Не найден Python 3.10-3.12. Установите его с python.org и запустите снова.
  pause & exit /b 1
)
call .venv\Scripts\activate.bat
python -m pip install --upgrade pip

echo === 2/5 PyTorch для процессора (без видеокарты NVIDIA)
pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu || goto :error

echo === 3/5 Библиотеки сервера
pip install -r requirements.txt || goto :error

echo === 4/5 Модель FASHN VTON v1.5 (открытый код, Apache-2.0)
pip install --no-deps https://github.com/fashn-AI/fashn-vton-1.5/archive/refs/heads/main.zip || goto :error

echo === 5/5 Веса модели (около 2 ГБ)
python download_weights.py || goto :error

echo.
echo Готово. Запускайте сервер файлом run_server.bat
pause
exit /b 0

:error
echo.
echo Установка прервалась. Проверьте интернет и запустите setup_windows.bat ещё раз.
pause
exit /b 1
