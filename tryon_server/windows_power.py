"""Настройки Windows, без которых примерка на ноутбуке может «зависнуть».

На других системах функции ничего не делают.

* Сон. Генерация на процессоре идёт несколько минут без нажатий
  клавиш, и Windows (особенно от батареи) усыпляет ноутбук: примерка
  останавливается, телефон теряет связь. Пока идёт генерация, просим
  систему не засыпать (экран при этом может погаснуть).
* Экономия энергии. Windows 11 переводит фоновые окна в режим
  «эффективности» и отдаёт их медленным ядрам процессора — генерация
  замедляется в разы. Отключаем это для сервера.
* Выделение в окне консоли. Если щёлкнуть мышью в чёрном окне сервера,
  Windows ставит программу на паузу, пока выделение не снято. Отключаем
  этот режим (QuickEdit) для окна сервера.
"""
from __future__ import annotations

import ctypes
import logging
import sys

log = logging.getLogger("tryon.power")

_IS_WINDOWS = sys.platform == "win32"

ES_CONTINUOUS = 0x80000000
ES_SYSTEM_REQUIRED = 0x00000001


def keep_awake(on: bool) -> None:
    """Запрещает (on=True) или снова разрешает сон Windows.
    Вызывать из одного и того же потока."""
    if not _IS_WINDOWS:
        return
    try:
        flags = ES_CONTINUOUS | (ES_SYSTEM_REQUIRED if on else 0)
        ctypes.windll.kernel32.SetThreadExecutionState(flags)
    except Exception as error:  # noqa: BLE001 — не мешаем примерке
        log.warning("Не удалось запретить сон: %s", error)


class _PowerThrottling(ctypes.Structure):
    _fields_ = [("Version", ctypes.c_ulong),
                ("ControlMask", ctypes.c_ulong),
                ("StateMask", ctypes.c_ulong)]


def prepare_console() -> None:
    """Отключает экономию энергии для процесса и паузу при выделении."""
    if not _IS_WINDOWS:
        return
    kernel32 = ctypes.windll.kernel32
    try:
        # PROCESS_POWER_THROTTLING_EXECUTION_SPEED: ControlMask=1, StateMask=0 —
        # «не замедлять этот процесс».
        state = _PowerThrottling(1, 1, 0)
        kernel32.SetProcessInformation(
            kernel32.GetCurrentProcess(), 4,  # ProcessPowerThrottling
            ctypes.byref(state), ctypes.sizeof(state),
        )
    except Exception as error:  # noqa: BLE001
        log.warning("Не удалось отключить экономию энергии: %s", error)
    try:
        handle = kernel32.GetStdHandle(-10)  # STD_INPUT_HANDLE
        mode = ctypes.c_ulong()
        if kernel32.GetConsoleMode(handle, ctypes.byref(mode)):
            ENABLE_QUICK_EDIT_MODE, ENABLE_EXTENDED_FLAGS = 0x0040, 0x0080
            kernel32.SetConsoleMode(
                handle, (mode.value & ~ENABLE_QUICK_EDIT_MODE) | ENABLE_EXTENDED_FLAGS,
            )
    except Exception as error:  # noqa: BLE001
        log.warning("Не удалось отключить паузу при выделении: %s", error)
