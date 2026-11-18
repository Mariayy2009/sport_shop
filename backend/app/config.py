"""Настройки сервера: берутся из переменных окружения или файла .env."""
import os

from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env"))

DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql+psycopg://postgres:postgres@localhost:5432/sport_shop",
)
SHOP_PORT = int(os.environ.get("SHOP_PORT", "8080"))
