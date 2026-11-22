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
            # Каталог уже есть: добавляем только новые товары из приложения
            # (с теми же номерами), ничего не удаляя.
            existing = set(session.scalars(select(Product.id)))
            new = [row for row in data["products"] if row["id"] not in existing]
            session.add_all(Product(**row) for row in new)
            for row in data["products"]:
                if row["id"] in existing and row.get("gallery"):
                    session.execute(text("UPDATE products SET gallery = :g WHERE id = :id AND gallery IS NULL"),
                                    {"g": row["gallery"], "id": row["id"]})
            session.flush()
            session.execute(text(
                "SELECT setval(pg_get_serial_sequence('products', 'id'), "
                "(SELECT COALESCE(MAX(id), 1) FROM products))"))
            print(f"Каталог уже заполнен ({count} товаров), добавлено новых: {len(new)}. "
                  "Для полной перезаливки: python seed.py --reset")
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
