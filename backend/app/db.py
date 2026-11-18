"""Подключение к PostgreSQL."""
from collections.abc import Iterator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from .config import DATABASE_URL

# pool_pre_ping: если PostgreSQL перезапускали, соединение восстановится само.
engine = create_engine(DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


def get_session() -> Iterator[Session]:
    """Сессия на один запрос — закрывается после ответа."""
    with SessionLocal() as session:
        yield session
