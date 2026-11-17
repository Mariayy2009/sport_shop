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

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s", datefmt="%H:%M:%S")
log = logging.getLogger("tryon.server")

PORT = int(os.environ.get("TRYON_PORT", "8000"))
# Шагов генерации: меньше — быстрее, больше — аккуратнее детали.
DEFAULT_STEPS = int(os.environ.get("TRYON_STEPS", "20"))
MIN_STEPS, MAX_STEPS = 8, 50
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
    state: str = "queued"  # queued | running | done | failed
    stage: str = "В очереди"
    step: int = 0
    error: Optional[str] = None
    result: Optional[bytes] = None
    cancelled: bool = False
    started_at: Optional[float] = None
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
            continue
        job.state, job.stage, job.started_at = "running", "Подготовка фото", time.time()

        def on_step(step: int, total: int, job: Job = job) -> None:
            job.step, job.stage = step, "Генерация"

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
        except Cancelled:
            job.state, job.error = "failed", "Генерация отменена"
        except Exception as error:  # noqa: BLE001 — текст ошибки уходит в приложение
            log.exception("Ошибка генерации")
            job.state, job.error = "failed", f"Ошибка генерации: {error}"
        finally:
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
    )
    with jobs_lock:
        jobs[job.id] = job
    pending.put(job.id)
    return {"job_id": job.id, "total_steps": job.steps}


def find(job_id: str) -> Job:
    job = jobs.get(job_id)
    if job is None:
        raise HTTPException(404, "Задание не найдено или уже удалено")
    return job


@app.get("/jobs/{job_id}")
def job_status(job_id: str) -> dict:
    job = find(job_id)
    eta = None
    if job.state == "running" and job.step > 0 and job.started_at:
        per_step = (time.time() - job.started_at) / job.step
        eta = per_step * (job.steps - job.step)
    elif job.state in ("queued", "running") and engine.seconds_per_step:
        eta = engine.seconds_per_step * job.steps
    return {
        "state": job.state,
        "stage": job.stage if engine.ready else "Загрузка модели",
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
