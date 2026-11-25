"""Состав товара (спортивное питание и др.): products.composition.

Revision ID: 0004_product_composition
Revises: 0003_product_variants
"""
import sqlalchemy as sa
from alembic import op

revision = "0004_product_composition"
down_revision = "0003_product_variants"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("products", sa.Column("composition", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("products", "composition")
