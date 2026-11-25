"""API каталога Sport Shop (этап 1 перехода на PostgreSQL).

Ответы совпадают по полям с моделями приложения (Product.fromJson и т. д.),
поэтому приложению всё равно, откуда пришёл каталог — из SQLite на телефоне
или с этого сервера.
"""
import json
from typing import Optional

from fastapi import Depends, FastAPI, HTTPException, Query
from sqlalchemy import select, text
from sqlalchemy.orm import Session

from .db import get_session
from .search import matches
from .models import Category, Product, Sport

app = FastAPI(title="Sport Shop API", version="1.0")


def product_json(product: Product) -> dict:
    """Товар в формате приложения: как строка SQLite с JOIN."""
    return {
        "id": product.id,
        "name": product.name,
        "description": product.description,
        "price": float(product.price),
        "category_id": product.category_id,
        "sport_id": product.sport_id,
        "size": product.size,
        "stock": product.stock,
        "image_url": product.image_url,
        "gallery": [line for line in (product.gallery or "").split("\n") if line.strip()],
        "variants": json.loads(product.variants) if product.variants else [],
        "brand": product.brand,
        "material": product.material,
        "composition": product.composition,
        "rating": float(product.rating) if product.rating is not None else None,
        "reviews_count": product.reviews_count,
        "category_name": product.category.name,
        "sport_name": product.sport.name,
    }


@app.get("/health")
def health(session: Session = Depends(get_session)) -> dict:
    """Сервер и база доступны. Приложение проверяет это при подключении."""
    try:
        version = session.execute(text("SHOW server_version")).scalar_one()
        products = session.execute(select(Product.id)).all()
    except Exception as error:  # noqa: BLE001 — причину видно в приложении
        raise HTTPException(503, f"Нет связи с PostgreSQL: {error.__class__.__name__}") from None
    return {"status": "ok", "database": f"PostgreSQL {version}", "products": len(products)}


UNIVERSAL_SPORT = "Для всех видов спорта"


@app.get("/sports")
def sports(session: Session = Depends(get_session)) -> list[dict]:
    rows = session.scalars(select(Sport).order_by(Sport.id))
    return [{"id": s.id, "name": s.name, "description": s.description} for s in rows]


@app.get("/categories")
def categories(session: Session = Depends(get_session)) -> list[dict]:
    rows = session.scalars(select(Category).order_by(Category.id))
    return [{"id": c.id, "name": c.name, "sport_id": c.sport_id} for c in rows]


@app.get("/products")
def products(
    query: str = "",
    sport_id: Optional[int] = None,
    category_id: Optional[int] = None,
    size: Optional[str] = None,
    min_price: Optional[float] = Query(None, ge=0),
    max_price: Optional[float] = Query(None, ge=0),
    only_available: bool = False,
    session: Session = Depends(get_session),
) -> list[dict]:
    """Каталог с теми же фильтрами, что экран «Фильтры» в приложении."""
    statement = select(Product).order_by(Product.name)
    if sport_id is not None:
        # Товары «Для всех видов спорта» видны в каталоге каждого спорта.
        universal = select(Sport.id).where(Sport.name == UNIVERSAL_SPORT)
        statement = statement.where(
            (Product.sport_id == sport_id) | Product.sport_id.in_(universal)
        )
    if category_id is not None:
        statement = statement.where(Product.category_id == category_id)
    if min_price is not None:
        statement = statement.where(Product.price >= min_price)
    if max_price is not None:
        statement = statement.where(Product.price <= max_price)
    if only_available:
        statement = statement.where(Product.stock > 0)
    if size:
        # Размеры хранятся строкой «S,M,L» — ищем «,M,» внутри «,S,M,L,».
        statement = statement.where(
            text("(',' || REPLACE(COALESCE(products.size, ''), ' ', '') || ',') LIKE :size")
        ).params(size=f"%,{size},%")
    items = [product_json(p) for p in session.scalars(statement).unique()]

    # Поиск — в Python: без учёта регистра и языка («adidas» = «Адидас»),
    # одинаково при любой локали базы данных.
    if query.strip():
        items = [
            item for item in items
            if matches(query, [item[field] for field in
                               ("name", "brand", "description", "category_name", "sport_name")])
        ]
    return items


@app.get("/products/{product_id}")
def product(product_id: int, session: Session = Depends(get_session)) -> dict:
    found = session.get(Product, product_id)
    if found is None:
        raise HTTPException(404, "Товар не найден")
    return product_json(found)
