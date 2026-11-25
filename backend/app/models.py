"""Таблицы каталога в PostgreSQL.

Повторяют схему SQLite из приложения (lib/data/database/database_schema.dart),
поэтому номера и поля совпадают. Остальные таблицы (пользователи, заказы,
корзина…) переедут на следующих этапах.
"""
from decimal import Decimal
from typing import Optional

from sqlalchemy import CheckConstraint, ForeignKey, Index, Numeric, String, Text
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class Sport(Base):
    __tablename__ = "sports"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(60), unique=True)
    description: Mapped[Optional[str]] = mapped_column(Text)


class Category(Base):
    __tablename__ = "categories"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(60))
    # NULL — категория общая для всех видов спорта.
    sport_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("sports.id", ondelete="SET NULL")
    )


class Product(Base):
    __tablename__ = "products"
    __table_args__ = (
        CheckConstraint("price >= 0", name="price_not_negative"),
        CheckConstraint("stock >= 0", name="stock_not_negative"),
        CheckConstraint("rating IS NULL OR rating BETWEEN 0 AND 5", name="rating_range"),
        Index("idx_products_sport", "sport_id"),
        Index("idx_products_category", "category_id"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(120))
    description: Mapped[Optional[str]] = mapped_column(Text)
    # Деньги — точным числом, без ошибок округления float.
    price: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    category_id: Mapped[int] = mapped_column(ForeignKey("categories.id", ondelete="RESTRICT"))
    sport_id: Mapped[int] = mapped_column(ForeignKey("sports.id", ondelete="RESTRICT"))
    # Размеры через запятую: «S,M,L» или «38,39,40».
    size: Mapped[Optional[str]] = mapped_column(String(120))
    stock: Mapped[int] = mapped_column(default=0)
    image_url: Mapped[Optional[str]] = mapped_column(String(300))
    # Дополнительные фото через перевод строки (как в базе телефона).
    gallery: Mapped[Optional[str]] = mapped_column(Text)
    # Варианты (цвет/модель) — JSON-список {name, image}, как в приложении.
    variants: Mapped[Optional[str]] = mapped_column(Text)
    brand: Mapped[Optional[str]] = mapped_column(String(60))
    material: Mapped[Optional[str]] = mapped_column(String(120))
    composition: Mapped[Optional[str]] = mapped_column(Text)
    diet: Mapped[Optional[str]] = mapped_column(Text)
    rating: Mapped[Optional[Decimal]] = mapped_column(Numeric(2, 1))
    reviews_count: Mapped[int] = mapped_column(default=0)

    category: Mapped[Category] = relationship(lazy="joined")
    sport: Mapped[Sport] = relationship(lazy="joined")
