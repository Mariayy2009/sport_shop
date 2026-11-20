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

            self.device = "cuda" if torch.cuda.is_available() else "cpu"
            if self.threads:
                torch.set_num_threads(self.threads)
            elif self.device == "cpu":
                torch.set_num_threads(best_thread_count(torch))
            started = time.time()
            self.pipeline = TryOnPipeline(weights_dir=self.weights_dir, device=self.device)
            if self.device == "cpu":
                saved = save_memory(self.pipeline.tryon_model, torch)
                log.info("Экономия памяти: веса модели занимают на %.1f ГБ меньше", saved / 1e9)
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

        step_seconds: list = []

        def progress(iterable, total=None, **_):
            # Подмена индикатора tqdm: так сервер узнаёт номер шага.
            last = time.time()
            for index, item in enumerate(iterable):
                if is_cancelled():
                    raise Cancelled()
                yield item
                now = time.time()
                step_seconds.append(now - last)
                last = now
                on_step(index + 1, total or steps)

        with self._lock:  # модель одна — генерации идут строго по очереди
            self.pipeline.tryon_model.single_pass = (
                self.device == "cpu" and single_pass_for(category))
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
            # Время шага для прогноза — по медиане шагов, а не по общему
            # времени: если ноутбук на время уснул, один шаг растянется
            # на часы, и прогноз для следующих примерок испортится.
            # Подготовка фото (около одного шага) учтена прибавкой.
            if step_seconds:
                ordered = sorted(step_seconds)
                per_step = ordered[len(ordered) // 2] * (1 + 1 / max(steps, 1))
                self.seconds_per_step = (
                    per_step if self.seconds_per_step is None
                    else 0.5 * self.seconds_per_step + 0.5 * per_step
                )
            log.info("Примерка готова: %d шагов за %.0f с", steps, elapsed)
            return result.images[0]


def save_memory(model, torch) -> int:
    """Уменьшает память модели почти вдвое, не меняя результат заметно.

    1. Веса в файле модели хранятся в bfloat16 (2 байта на число), а для
       расчёта на процессоре PyTorch держит их в float32 (4 байта) —
       3,9 ГБ вместо 1,9. Храним веса больших слоёв в bfloat16 и
       переводим во float32 только на время расчёта одного слоя.
    2. Модель на каждом шаге считает два варианта (с вещью и без —
       classifier-free guidance) одной пачкой. Считаем их по очереди:
       так же быстро, но промежуточные данные вдвое меньше.

    На ноутбуке с 16 ГБ это важно: когда памяти не хватает, Windows
    сбрасывает её на диск, и один шаг идёт 5 минут вместо полутора.
    Возвращает, сколько байт сэкономлено.
    """
    import torch.nn.functional as F

    saved = 0
    for module in model.modules():
        if isinstance(module, torch.nn.Linear) and module.weight.numel() >= 65536:
            module.weight.data = module.weight.data.to(torch.bfloat16)
            saved += module.weight.numel() * 2

            def forward(x, module=module):
                return F.linear(x, module.weight.to(x.dtype), module.bias)

            module.forward = forward

    def forward_for_cfg(*args, **kwargs):
        kwargs = {k: v for k, v in kwargs.items() if v is not None}
        batch = args[0].shape[0]
        device = args[0].device
        with_garment = model.forward(
            *args, **kwargs, mask=torch.ones(batch, dtype=torch.bool, device=device))["x"]
        if getattr(model, "single_pass", False):
            # Без второго варианта: шаг вдвое быстрее (см. single_pass_for).
            return {"v_c": with_garment, "v_u": with_garment}
        without = model.forward(
            *args, **kwargs, mask=torch.zeros(batch, dtype=torch.bool, device=device))["x"]
        return {"v_c": with_garment, "v_u": without}

    model.forward_for_cfg = forward_for_cfg
    return saved


def single_pass_for(category: str) -> bool:
    """Считать ли шаг одним проходом модели вместо двух.

    Для верха второй проход (усиление вещи, classifier-free guidance)
    почти не меняет результат, а время шага сокращает вдвое — проверено
    на майке: цвет, фасон и надпись те же. Для низа без него ноги на фото
    размываются, поэтому шорты и штаны считаются полностью. Отключить:
    TRYON_FAST_TOPS=0.
    """
    return category == "tops" and os.environ.get("TRYON_FAST_TOPS", "1") != "0"


def best_thread_count(torch) -> int:
    """Сколько потоков процессора давать модели.

    По умолчанию PyTorch берёт все физические ядра. Но у новых Intel
    (как Core 5 210H) ядра разные: быстрые P и медленные E. Работа
    делится между потоками поровну, и быстрые ядра ждут медленные —
    иногда меньше потоков считают быстрее. Поэтому при запуске сервер
    за несколько секунд меряет умножение матриц (основа модели) с
    разным числом потоков и берёт самое быстрое.
    """
    default = torch.get_num_threads()
    logical = os.cpu_count() or default
    candidates = sorted({max(1, default // 2), max(1, default * 3 // 4), default, logical})
    a = torch.randn(1024, 1024)
    b = torch.randn(1024, 1024)
    results = {}
    for threads in candidates:
        torch.set_num_threads(threads)
        torch.mm(a, b)  # разогрев
        count, started = 0, time.perf_counter()
        while time.perf_counter() - started < 0.6:
            torch.mm(a, b)
            count += 1
        results[threads] = count / (time.perf_counter() - started)
    best = max(results, key=results.get)
    log.info("Потоки процессора: %s — выбрано %d",
             ", ".join(f"{t}: {r:.0f} оп/с" for t, r in sorted(results.items())), best)
    return best


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
