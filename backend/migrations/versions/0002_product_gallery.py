"""Несколько фото у товара: products.gallery.

Revision ID: 0002_product_gallery
Revises: 0001_catalog
"""
import sqlalchemy as sa
from alembic import op

revision = "0002_product_gallery"
down_revision = "0001_catalog"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("products", sa.Column("gallery", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("products", "gallery")
