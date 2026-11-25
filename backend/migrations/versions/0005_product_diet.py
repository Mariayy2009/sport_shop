"""Отметки спортпита (без лактозы, веган, без сахара): products.diet.

Revision ID: 0005_product_diet
Revises: 0004_product_composition
"""
import sqlalchemy as sa
from alembic import op

revision = "0005_product_diet"
down_revision = "0004_product_composition"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("products", sa.Column("diet", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("products", "diet")
