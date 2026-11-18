"""Этап 1: каталог — виды спорта, категории, товары.

Revision ID: 0001_catalog
Revises:
"""
import sqlalchemy as sa
from alembic import op

revision = "0001_catalog"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "sports",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("name", sa.String(60), nullable=False, unique=True),
        sa.Column("description", sa.Text),
    )
    op.create_table(
        "categories",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("name", sa.String(60), nullable=False),
        sa.Column("sport_id", sa.Integer, sa.ForeignKey("sports.id", ondelete="SET NULL")),
    )
    op.create_table(
        "products",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("description", sa.Text),
        sa.Column("price", sa.Numeric(12, 2), nullable=False),
        sa.Column("category_id", sa.Integer,
                  sa.ForeignKey("categories.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("sport_id", sa.Integer,
                  sa.ForeignKey("sports.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("size", sa.String(120)),
        sa.Column("stock", sa.Integer, nullable=False, server_default="0"),
        sa.Column("image_url", sa.String(300)),
        sa.Column("brand", sa.String(60)),
        sa.Column("material", sa.String(120)),
        sa.Column("rating", sa.Numeric(2, 1)),
        sa.Column("reviews_count", sa.Integer, nullable=False, server_default="0"),
        sa.CheckConstraint("price >= 0", name="price_not_negative"),
        sa.CheckConstraint("stock >= 0", name="stock_not_negative"),
        sa.CheckConstraint("rating IS NULL OR rating BETWEEN 0 AND 5", name="rating_range"),
    )
    op.create_index("idx_products_sport", "products", ["sport_id"])
    op.create_index("idx_products_category", "products", ["category_id"])


def downgrade() -> None:
    op.drop_table("products")
    op.drop_table("categories")
    op.drop_table("sports")
