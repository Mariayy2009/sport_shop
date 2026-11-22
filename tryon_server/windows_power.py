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


class _MemoryStatus(ctypes.Structure):
    _fields_ = [("dwLength", ctypes.c_ulong), ("dwMemoryLoad", ctypes.c_ulong),
                ("ullTotalPhys", ctypes.c_ulonglong), ("ullAvailPhys", ctypes.c_ulonglong),
                ("ullTotalPageFile", ctypes.c_ulonglong), ("ullAvailPageFile", ctypes.c_ulonglong),
                ("ullTotalVirtual", ctypes.c_ulonglong), ("ullAvailVirtual", ctypes.c_ulonglong),
                ("ullAvailExtendedVirtual", ctypes.c_ulonglong)]


class _PowerStatus(ctypes.Structure):
    _fields_ = [("ACLineStatus", ctypes.c_ubyte), ("BatteryFlag", ctypes.c_ubyte),
                ("BatteryLifePercent", ctypes.c_ubyte), ("SystemStatusFlag", ctypes.c_ubyte),
                ("BatteryLifeTime", ctypes.c_ulong), ("BatteryFullLifeTime", ctypes.c_ulong)]


# Меньше этого свободной памяти — Windows начинает сбрасывать память
# модели на диск, и шаг идёт в разы дольше (проверено: 334 с вместо ~60).
LOW_MEMORY_BYTES = 2 * 1024 ** 3


def available_memory() -> int | None:
    """Свободная оперативная память в байтах (None — не удалось узнать)."""
    try:
        if _IS_WINDOWS:
            status = _MemoryStatus()
            status.dwLength = ctypes.sizeof(status)
            if ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(status)):
                return status.ullAvailPhys
            return None
        with open("/proc/meminfo") as meminfo:
            for line in meminfo:
                if line.startswith("MemAvailable:"):
                    return int(line.split()[1]) * 1024
    except Exception:  # noqa: BLE001
        pass
    return None


def on_battery() -> bool:
    if not _IS_WINDOWS:
        return False
    try:
        status = _PowerStatus()
        if ctypes.windll.kernel32.GetSystemPowerStatus(ctypes.byref(status)):
            return status.ACLineStatus == 0
    except Exception:  # noqa: BLE001
        pass
    return False


def slowdown_warnings(needed: int = 0) -> list:
    """Что сейчас замедляет примерку на ноутбуке — понятным текстом.

    [needed] — сколько памяти ещё понадобится модели сверх уже занятой.
    """
    warnings = []
    free = available_memory()
    if free is not None and free - needed < LOW_MEMORY_BYTES:
        warnings.append(
            f"На ноутбуке мало свободной памяти ({free / 1024 ** 3:.1f} ГБ). "
            "Закройте браузер и другие программы — иначе примерка идёт в разы дольше")
    if on_battery():
        warnings.append("Ноутбук работает от батареи — подключите зарядку, "
                        "так процессор считает в 2–3 раза быстрее")
    return warnings
