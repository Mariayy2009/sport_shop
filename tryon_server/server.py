"""Локальный сервер виртуальной примерки для приложения Sport Shop.

Запуск:  python server.py          (или run_server.bat в Windows)
Адрес:   http://<IP ноутбука>:8000 — его вводят в приложении.

Сервер работает только в вашей сети. Фотографии обрабатываются
в оперативной памяти и на диск не записываются; результат удаляется
через 30 минут или сразу по запросу приложения.
"""
from __future__ import annotations

import io
import logging
import os
import queue
import socket
import threading
import time
import uuid
from contextlib import asynccontextmanager
from dataclasses import dataclass, field
from typing import Dict, Optional

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import Response
from PIL import Image, ImageOps, UnidentifiedImageError

from engine import CATEGORIES, GARMENT_TYPES, Cancelled, TryOnEngine, default_weights_dir
import windows_power

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s", datefmt="%H:%M:%S")
log = logging.getLogger("tryon.server")

PORT = int(os.environ.get("TRYON_PORT", "8000"))
# Шагов генерации: меньше — быстрее, больше — аккуратнее детали.
# На процессоре один шаг занимает около минуты, а уже 6 шагов дают
# хорошее качество (проверено на футболке, майке и шортах), поэтому
# по умолчанию 6. Авторы модели советуют 20–30 — это для видеокарты.
DEFAULT_STEPS = int(os.environ.get("TRYON_STEPS", "6"))
MIN_STEPS, MAX_STEPS = 4, 50
MAX_UPLOAD_BYTES = 15 * 1024 * 1024
MIN_SIDE = 256
MAX_SIDE = 1536
RESULT_TTL_SECONDS = 30 * 60


@dataclass
class Job:
    id: str
    person: Optional[Image.Image]
    garment: Optional[Image.Image]
    category: str
    garment_type: str
    steps: int
    seed: int
    client: str = ""
    state: str = "queued"  # queued | running | done | failed
    stage: str = "В очереди"
    step: int = 0
    error: Optional[str] = None
    result: Optional[bytes] = None
    cancelled: bool = False
    started_at: Optional[float] = None
    step_times: list = field(default_factory=list)
    finished_at: Optional[float] = None
    created_at: float = field(default_factory=time.time)


engine = TryOnEngine(
    default_weights_dir(),
    threads=int(os.environ["TRYON_THREADS"]) if os.environ.get("TRYON_THREADS") else None,
)
jobs: Dict[str, Job] = {}
jobs_lock = threading.Lock()
pending: "queue.Queue[str]" = queue.Queue()
@asynccontextmanager
async def lifespan(_: FastAPI):
    windows_power.prepare_console()
    threading.Thread(target=worker, daemon=True).start()
    log.info("Сервер примерки запущен. Адрес для приложения: http://%s:%d", local_ip(), PORT)
    log.info("Модель загружается, это занимает около минуты…")
    yield


app = FastAPI(title="Sport Shop Try-On", version="1.0", lifespan=lifespan)


def worker() -> None:
    """Единственный поток генерации: задания выполняются по очереди."""
    engine.load()
    while True:
        job_id = pending.get()
        with jobs_lock:
            job = jobs.get(job_id)
        if job is None or job.cancelled:
            with jobs_lock:
                jobs.pop(job_id, None)
            continue
        job.state, job.stage, job.started_at = "running", "Подготовка фото", time.time()
        log.info("Примерка %s: начало (%d шагов). Подготовка фото…", job.id[:6], job.steps)
        # Пока идёт генерация, Windows не должна засыпать: сон ноутбука
        # останавливает примерку, а телефон теряет связь.
        windows_power.keep_awake(True)

        def on_step(step: int, total: int, job: Job = job) -> None:
            now = time.time()
            since = now - (job.step_times[-1] if job.step_times else job.started_at)
            job.step, job.stage = step, "Генерация"
            job.step_times.append(now)
            log.info("Примерка %s: шаг %d из %d (%.0f с)", job.id[:6], step, total, since)

        try:
            if not engine.ready:
                engine.load()
            image = engine.run(
                job.person, job.garment, job.category, job.garment_type,
                job.steps, job.seed, on_step, lambda job=job: job.cancelled,
            )
            buffer = io.BytesIO()
            image.convert("RGB").save(buffer, format="JPEG", quality=92)
            job.result, job.state, job.stage = buffer.getvalue(), "done", "Готово"
            log.info("Примерка %s: готово за %.0f с", job.id[:6], time.time() - job.started_at)
        except Cancelled:
            job.state, job.error = "failed", "Генерация отменена"
            log.info("Примерка %s: отменена", job.id[:6])
        except Exception as error:  # noqa: BLE001 — текст ошибки уходит в приложение
            log.exception("Ошибка генерации")
            job.state, job.error = "failed", f"Ошибка генерации: {error}"
        finally:
            windows_power.keep_awake(False)
            # Исходные фото больше не нужны — не держим их в памяти.
            job.person = job.garment = None
            job.finished_at = time.time()
            if job.cancelled:
                # Пользователь отказался — удаляем задание сразу.
                with jobs_lock:
                    jobs.pop(job.id, None)
            cleanup()


def cleanup() -> None:
    """Удаляет результаты старше получаса."""
    now = time.time()
    with jobs_lock:
        for job_id in [j.id for j in jobs.values()
                       if j.finished_at and now - j.finished_at > RESULT_TTL_SECONDS]:
            del jobs[job_id]


async def read_image(upload: UploadFile, title: str) -> Image.Image:
    data = await upload.read()
    if not data:
        raise HTTPException(400, f"{title}: файл пустой")
    if len(data) > MAX_UPLOAD_BYTES:
        raise HTTPException(413, f"{title}: файл больше 15 МБ")
    try:
        image = Image.open(io.BytesIO(data))
        image = ImageOps.exif_transpose(image).convert("RGB")
    except (UnidentifiedImageError, OSError):
        raise HTTPException(400, f"{title}: файл не является изображением") from None
    if min(image.size) < MIN_SIDE:
        raise HTTPException(400, f"{title}: изображение слишком маленькое (меньше {MIN_SIDE} px)")
    if max(image.size) > MAX_SIDE:
        image.thumbnail((MAX_SIDE, MAX_SIDE))
    return image


@app.get("/health")
def health() -> dict:
    waiting = sum(1 for job in jobs.values() if job.state in ("queued", "running"))
    message = engine.load_error
    if message is None and not engine.ready:
        message = "Модель загружается, подождите около минуты"
    return {
        "status": "ok",
        "model": "FASHN VTON v1.5",
        "model_ready": engine.ready,
        "device": engine.device,
        "default_steps": DEFAULT_STEPS,
        "seconds_per_step": engine.seconds_per_step,
        "jobs_waiting": waiting,
        "message": message,
    }


@app.post("/tryon")
async def create_job(
    person: UploadFile = File(...),
    garment: UploadFile = File(...),
    category: str = Form(...),
    garment_type: str = Form("flat-lay"),
    steps: Optional[int] = Form(None),
    seed: int = Form(42),
    client: str = Form(""),
) -> dict:
    if category not in CATEGORIES:
        raise HTTPException(400, f"Категория должна быть одной из: {', '.join(CATEGORIES)}")
    if garment_type not in GARMENT_TYPES:
        raise HTTPException(400, f"Тип фото вещи должен быть одним из: {', '.join(GARMENT_TYPES)}")
    if engine.load_error:
        raise HTTPException(503, engine.load_error)
    job = Job(
        id=uuid.uuid4().hex,
        person=await read_image(person, "Фото человека"),
        garment=await read_image(garment, "Фото вещи"),
        category=category,
        garment_type=garment_type,
        steps=max(MIN_STEPS, min(MAX_STEPS, steps or DEFAULT_STEPS)),
        seed=seed,
        client=client[:64],
    )
    with jobs_lock:
        if job.client:
            # Телефон начал новую примерку — прежние ему уже не нужны
            # (связь могла прерваться, а задание осталось в очереди).
            for old in jobs.values():
                if old.client == job.client and old.state in ("queued", "running"):
                    old.cancelled = True
                    log.info("Примерка %s: заменена новой от того же телефона", old.id[:6])
        jobs[job.id] = job
    pending.put(job.id)
    log.info("Примерка %s: получена, %s, в очереди перед ней: %d",
             job.id[:6], category, queue_ahead(job))
    return {"job_id": job.id, "total_steps": job.steps}


def queue_ahead(job: Job) -> int:
    """Сколько заданий выполнится раньше этого."""
    with jobs_lock:
        return sum(1 for other in jobs.values()
                   if other is not job and not other.cancelled
                   and other.state in ("queued", "running")
                   and other.created_at <= job.created_at)


def find(job_id: str) -> Job:
    job = jobs.get(job_id)
    if job is None:
        raise HTTPException(404, "Задание не найдено или уже удалено")
    return job


@app.get("/jobs/{job_id}")
def job_status(job_id: str) -> dict:
    job = find(job_id)
    eta = None
    remaining = job.steps - job.step
    if job.state == "running" and len(job.step_times) >= 2:
        # Скорость по уже сделанным шагам; минус время с последнего шага.
        times = job.step_times
        per_step = (times[-1] - times[0]) / (len(times) - 1)
        eta = max(per_step * remaining - (time.time() - times[-1]), 0)
    elif job.state in ("queued", "running") and engine.seconds_per_step:
        # Прогноз по прошлым примеркам на этом компьютере.
        spent = time.time() - job.started_at if job.started_at else 0
        eta = max(engine.seconds_per_step * job.steps - spent, 0)
    ahead = queue_ahead(job) if job.state == "queued" else 0
    if ahead and eta is not None:
        eta += ahead * (engine.seconds_per_step or 0) * job.steps
    stage = job.stage
    if not engine.ready:
        stage = "Загрузка модели"
    elif ahead:
        stage = f"В очереди: перед вами {ahead}"
    return {
        "state": job.state,
        "stage": stage,
        "queue_ahead": ahead,
        "step": job.step,
        "total_steps": job.steps,
        "eta_seconds": eta,
        "error": job.error,
    }


@app.get("/jobs/{job_id}/result")
def job_result(job_id: str) -> Response:
    job = find(job_id)
    if job.state != "done" or job.result is None:
        raise HTTPException(409, job.error or "Результат ещё не готов")
    return Response(content=job.result, media_type="image/jpeg")


@app.delete("/jobs/{job_id}")
def delete_job(job_id: str) -> dict:
    """Отмена генерации и удаление фото и результата с сервера."""
    job = find(job_id)
    job.cancelled = True
    if job.state != "running":
        with jobs_lock:
            jobs.pop(job_id, None)
    return {"deleted": True}


def local_ip() -> str:
    """IP ноутбука в домашней сети — его вводят в приложении."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
            probe.connect(("10.255.255.255", 1))
            return probe.getsockname()[0]
    except OSError:
        return "127.0.0.1"


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=PORT, log_level="warning")
