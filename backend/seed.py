"""Заполняет каталог демо-данными из seed/catalog.json.

Файл выгружен из приложения (flutter test tools/export_seed_test.dart),
поэтому номера товаров совпадают с базой на телефоне.

  python seed.py           — заполнить, только если каталог пустой
  python seed.py --reset   — очистить каталог и заполнить заново
"""
import json
import os
import sys

from sqlalchemy import delete, func, select, text

from app.db import SessionLocal
from app.models import Category, Product, Sport

FIXTURE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "seed", "catalog.json")


def main(reset: bool) -> None:
    with open(FIXTURE, encoding="utf-8") as file:
        data = json.load(file)
    with SessionLocal() as session, session.begin():
        count = session.scalar(select(func.count()).select_from(Product))
        if count and not reset:
            print(f"Каталог уже заполнен ({count} товаров). Для перезаливки: python seed.py --reset")
            return
        for model in (Product, Category, Sport):
            session.execute(delete(model))
        session.add_all(Sport(**row) for row in data["sports"])
        session.flush()
        session.add_all(Category(**row) for row in data["categories"])
        session.flush()
        session.add_all(Product(**row) for row in data["products"])
        session.flush()
        # Номера заданы явно — двигаем счётчики, чтобы новые записи
        # получали следующие номера.
        for table in ("sports", "categories", "products"):
            session.execute(text(
                f"SELECT setval(pg_get_serial_sequence('{table}', 'id'), "
                f"(SELECT COALESCE(MAX(id), 1) FROM {table}))"
            ))
    print(f"Каталог заполнен: {len(data['sports'])} видов спорта, "
          f"{len(data['categories'])} категорий, {len(data['products'])} товаров")


if __name__ == "__main__":
    main(reset="--reset" in sys.argv)
