"""Варианты товара (цвет/модель): products.variants.

Revision ID: 0003_product_variants
Revises: 0002_product_gallery
"""
import sqlalchemy as sa
from alembic import op

revision = "0003_product_variants"
down_revision = "0002_product_gallery"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("products", sa.Column("variants", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("products", "variants")
