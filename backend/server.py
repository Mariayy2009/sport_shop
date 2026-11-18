"""Запуск сервера магазина: python server.py"""
import socket

import uvicorn

from app.config import SHOP_PORT


def local_ip() -> str:
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
            probe.connect(("10.255.255.255", 1))
            return probe.getsockname()[0]
    except OSError:
        return "127.0.0.1"


if __name__ == "__main__":
    print(f"Сервер магазина запущен. Адрес для приложения: http://{local_ip()}:{SHOP_PORT}")
    uvicorn.run("app.main:app", host="0.0.0.0", port=SHOP_PORT, log_level="warning")
