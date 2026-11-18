"""Создаёт базу sport_shop в PostgreSQL, если её ещё нет.

Подключается к служебной базе postgres тем же пользователем и паролем,
что указаны в .env.
"""
import sys

import psycopg
from sqlalchemy.engine import make_url

from app.config import DATABASE_URL


def main() -> None:
    url = make_url(DATABASE_URL)
    name = url.database
    try:
        with psycopg.connect(
            host=url.host or "localhost", port=url.port or 5432,
            user=url.username, password=url.password, dbname="postgres",
            autocommit=True,
        ) as connection:
            exists = connection.execute(
                "SELECT 1 FROM pg_database WHERE datname = %s", (name,)
            ).fetchone()
            if exists:
                print(f"База {name} уже есть")
            else:
                connection.execute(f'CREATE DATABASE "{name}" ENCODING \'UTF8\'')
                print(f"База {name} создана")
    except psycopg.OperationalError as error:
        print("Не удалось подключиться к PostgreSQL. Проверьте, что он запущен "
              "и пароль в файле .env верный.")
        print(f"Подробности: {error}")
        sys.exit(1)


if __name__ == "__main__":
    main()
