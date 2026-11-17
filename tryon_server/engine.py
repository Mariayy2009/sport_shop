"""Обёртка над открытой моделью FASHN VTON v1.5 (Apache-2.0).

Модель работает локально на процессоре: фотографии не покидают ноутбук.
"""
from __future__ import annotations

import logging
import os
import threading
import time
from typing import Callable, Optional

from PIL import Image

log = logging.getLogger("tryon.engine")

CATEGORIES = ("tops", "bottoms", "one-pieces")
GARMENT_TYPES = ("flat-lay", "model")


class Cancelled(Exception):
    """Пользователь отменил генерацию."""


class TryOnEngine:
    """Загружает модель один раз и генерирует примерки по очереди."""

    def __init__(self, weights_dir: str, threads: Optional[int] = None):
        self.weights_dir = weights_dir
        self.threads = threads
        self.pipeline = None
        self.device = "cpu"
        self.load_error: Optional[str] = None
        self.loading = False
        # Среднее время шага по завершённым генерациям — для прогноза.
        self.seconds_per_step: Optional[float] = None
        self._lock = threading.Lock()

    @property
    def ready(self) -> bool:
        return self.pipeline is not None

    def load(self) -> None:
        """Загрузка весов в память (около минуты на ноутбуке)."""
        if self.ready or self.loading:
            return
        self.loading = True
        try:
            import torch
            from fashn_vton import TryOnPipeline

            if self.threads:
                torch.set_num_threads(self.threads)
            self.device = "cuda" if torch.cuda.is_available() else "cpu"
            started = time.time()
            self.pipeline = TryOnPipeline(weights_dir=self.weights_dir, device=self.device)
            log.info("Модель загружена за %.0f с, устройство: %s, потоков: %s",
                     time.time() - started, self.device, torch.get_num_threads())
            self.load_error = None
        except FileNotFoundError as error:
            self.load_error = ("Веса модели не найдены. Запустите download_weights "
                               f"(см. README). Подробности: {error}")
            log.error(self.load_error)
        except Exception as error:  # noqa: BLE001 — причину показываем в /health
            self.load_error = f"Не удалось загрузить модель: {error}"
            log.exception("Ошибка загрузки модели")
        finally:
            self.loading = False

    def run(
        self,
        person: Image.Image,
        garment: Image.Image,
        category: str,
        garment_type: str,
        steps: int,
        seed: int,
        on_step: Callable[[int, int], None],
        is_cancelled: Callable[[], bool],
        segmentation_free: Optional[bool] = None,
    ) -> Image.Image:
        """Одна примерка. on_step(шаг, всего) вызывается после каждого шага."""
        if not self.ready:
            raise RuntimeError(self.load_error or "Модель ещё загружается")

        import fashn_vton.pipeline as pipeline_module

        def progress(iterable, total=None, **_):
            # Подмена индикатора tqdm: так сервер узнаёт номер шага.
            for index, item in enumerate(iterable):
                if is_cancelled():
                    raise Cancelled()
                yield item
                on_step(index + 1, total or steps)

        with self._lock:  # модель одна — генерации идут строго по очереди
            original = pipeline_module.tqdm
            pipeline_module.tqdm = progress
            started = time.time()
            try:
                result = self.pipeline(
                    person_image=person,
                    garment_image=garment,
                    category=category,
                    garment_photo_type=garment_type,
                    num_timesteps=steps,
                    seed=seed,
                    segmentation_free=(
                        use_segmentation_free(category)
                        if segmentation_free is None else segmentation_free
                    ),
                )
            finally:
                pipeline_module.tqdm = original
            elapsed = time.time() - started
            per_step = elapsed / max(steps, 1)
            self.seconds_per_step = (
                per_step if self.seconds_per_step is None
                else 0.5 * self.seconds_per_step + 0.5 * per_step
            )
            log.info("Примерка готова: %d шагов за %.0f с", steps, elapsed)
            return result.images[0]


def use_segmentation_free(category: str) -> bool:
    """Режим без маски лучше сохраняет фигуру, но не умеет убирать
    исходную одежду, если новая короче (брюки → шорты). Для низа и
    комплектов исходную одежду сначала закрашиваем маской."""
    return category == "tops"


def default_weights_dir() -> str:
    return os.environ.get(
        "TRYON_WEIGHTS",
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "weights"),
    )
