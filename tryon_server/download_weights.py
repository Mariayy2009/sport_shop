"""Скачивает веса FASHN VTON v1.5 (~2 ГБ) в папку weights рядом со скриптом.

Источник — официальные репозитории на Hugging Face (лицензия Apache-2.0).
Модель разбора фигуры (~244 МБ) скачается сама при первом запуске сервера.
"""
import os
import sys

from huggingface_hub import hf_hub_download

HERE = os.path.dirname(os.path.abspath(__file__))
WEIGHTS = os.environ.get("TRYON_WEIGHTS", os.path.join(HERE, "weights"))


def main() -> None:
    os.makedirs(os.path.join(WEIGHTS, "dwpose"), exist_ok=True)
    print("Скачиваю модель примерки (около 1,9 ГБ)…")
    hf_hub_download("fashn-ai/fashn-vton-1.5", "model.safetensors", local_dir=WEIGHTS)
    for name in ("yolox_l.onnx", "dw-ll_ucoco_384.onnx"):
        print(f"Скачиваю модель позы {name}…")
        hf_hub_download("fashn-ai/DWPose", name, local_dir=os.path.join(WEIGHTS, "dwpose"))
    print(f"Готово. Веса лежат в {WEIGHTS}")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(1)
