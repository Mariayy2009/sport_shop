"""Проверка API каталога на настоящем PostgreSQL.

Нужна отдельная тестовая база (она очищается!):
  TEST_DATABASE_URL=postgresql+psycopg://postgres:пароль@localhost:5432/sport_shop_test
  pytest
"""
import os
import subprocess
import sys

import pytest

TEST_URL = os.environ.get("TEST_DATABASE_URL")
if not TEST_URL:
    pytest.skip("Задайте TEST_DATABASE_URL — адрес отдельной тестовой базы",
                allow_module_level=True)
os.environ["DATABASE_URL"] = TEST_URL

from fastapi.testclient import TestClient  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


@pytest.fixture(scope="module")
def client():
    env = {**os.environ, "DATABASE_URL": TEST_URL}
    for command in (["create_db.py"], ["-m", "alembic", "upgrade", "head"], ["seed.py", "--reset"]):
        subprocess.run([sys.executable, *command], cwd=ROOT, env=env, check=True)
    from app.main import app
    with TestClient(app) as test_client:
        yield test_client


def names(response):
    return {item["name"] for item in response.json()}


def test_health(client):
    body = client.get("/health").json()
    assert body["status"] == "ok"
    assert body["database"].startswith("PostgreSQL")
    assert body["products"] == 38


def test_reference_data(client):
    sports = client.get("/sports").json()
    assert [s["name"] for s in sports][:2] == ["Волейбол", "Бег"]
    assert len(client.get("/categories").json()) == 5


def test_product_matches_app_format(client):
    product = client.get("/products/1").json()
    # Те же поля, что читает Product.fromJson в приложении.
    assert set(product) == {
        "id", "name", "description", "price", "category_id", "sport_id", "size",
        "stock", "image_url", "brand", "material", "rating", "reviews_count",
        "category_name", "sport_name",
    }
    assert product["name"] == "Волейбольная форма"
    assert product["category_name"] == "Одежда"
    assert isinstance(product["price"], float)
    assert client.get("/products/9999").status_code == 404


def test_filters(client):
    assert len(client.get("/products").json()) == 38
    volleyball = client.get("/products", params={"sport_id": 1}).json()
    assert {p["sport_name"] for p in volleyball} == {"Волейбол"}
    # Размер ищется целиком: «M» не совпадает с «XL» или «12oz».
    sized = client.get("/products", params={"size": "M"}).json()
    assert all("M" in p["size"].split(",") for p in sized)
    cheap = client.get("/products", params={"max_price": 2000}).json()
    assert cheap and all(p["price"] <= 2000 for p in cheap)
    assert client.get("/products", params={"min_price": -1}).status_code == 422


def test_search_cyrillic_any_case(client):
    assert names(client.get("/products", params={"query": "КРОССОВКИ"})) == names(
        client.get("/products", params={"query": "кроссовки"})
    )
    assert "Кроссовки для бега" in names(client.get("/products", params={"query": "кроссовки"}))
