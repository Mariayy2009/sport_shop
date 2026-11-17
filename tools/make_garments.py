"""Генерирует низкополигональные 3D-модели одежды (GLB) для живой примерки.

Модели собственные, процедурные: лицензионных ограничений нет.
Каждая модель состоит из частей-«костей». Имя узла говорит приложению,
к какой части тела привязать часть одежды:

  torso            плечи → бёдра          (x, z в ширинах плеч; y в длинах торса)
  sleeve_l/r       плечо → локоть         (y в длинах плеча)
  forearm_l/r      локоть → запястье
  waist            пояс (от линии бёдер)
  leg_l/r          бедро → колено
  shin_l/r         колено → щиколотка

Запуск:  python tools/make_garments.py   (нужен только Python 3, без библиотек)
"""
import json
import math
import os
import struct

SEGMENTS = 14  # граней по окружности: мало полигонов — быстро на телефоне


def tube(rings):
    """rings: [(y, rx, rz, cx)] — сечения-эллипсы вдоль оси y."""
    positions, normals, indices = [], [], []
    for y, rx, rz, cx in rings:
        for s in range(SEGMENTS):
            a = 2 * math.pi * s / SEGMENTS
            x, z = math.cos(a) * rx, math.sin(a) * rz
            positions.append((cx + x, y, z))
            nx, nz = math.cos(a) / max(rx, 1e-6), math.sin(a) / max(rz, 1e-6)
            length = math.hypot(nx, nz) or 1.0
            normals.append((nx / length, 0.0, nz / length))
    for r in range(len(rings) - 1):
        for s in range(SEGMENTS):
            a = r * SEGMENTS + s
            b = r * SEGMENTS + (s + 1) % SEGMENTS
            c, d = a + SEGMENTS, b + SEGMENTS
            indices += [a, c, b, b, c, d]
    return positions, normals, indices


TORSO = [(0.10, 0.17, 0.13, 0), (0.03, 0.40, 0.17, 0), (-0.04, 0.57, 0.21, 0),
         (-0.25, 0.56, 0.25, 0), (-0.60, 0.51, 0.24, 0), (-0.90, 0.52, 0.24, 0),
         (-1.08, 0.54, 0.25, 0)]
JERSEY = [(0.08, 0.20, 0.13, 0), (0.02, 0.38, 0.17, 0), (-0.06, 0.50, 0.21, 0),
          (-0.25, 0.54, 0.25, 0), (-0.60, 0.51, 0.24, 0), (-0.90, 0.53, 0.25, 0),
          (-1.10, 0.55, 0.26, 0)]
SHORT_SLEEVE = [(-0.06, 0.19, 0.19, 0), (0.25, 0.17, 0.17, 0), (0.52, 0.16, 0.16, 0)]
LONG_SLEEVE = [(-0.06, 0.19, 0.19, 0), (0.5, 0.15, 0.15, 0), (1.04, 0.13, 0.13, 0)]
FOREARM = [(-0.04, 0.13, 0.13, 0), (0.5, 0.115, 0.115, 0), (0.96, 0.10, 0.10, 0)]
WAIST = [(0.20, 0.50, 0.23, 0), (0.0, 0.53, 0.25, 0), (-0.14, 0.52, 0.25, 0)]


def leg(side, y_end, r_end):
    # Штанина начинается шире и смещена к центру, чтобы сойтись с поясом.
    return [(-0.12, 0.27, 0.24, -side * 0.02), (0.25, 0.24, 0.22, 0),
            (y_end, r_end, r_end, 0)]


SHIN = [(-0.04, 0.18, 0.18, 0), (0.5, 0.15, 0.15, 0), (0.97, 0.125, 0.125, 0)]

MODELS = {
    'tshirt': {'torso': TORSO, 'sleeve_l': SHORT_SLEEVE, 'sleeve_r': SHORT_SLEEVE},
    'jersey': {'torso': JERSEY},
    'long_sleeve': {'torso': TORSO, 'sleeve_l': LONG_SLEEVE, 'sleeve_r': LONG_SLEEVE,
                    'forearm_l': FOREARM, 'forearm_r': FOREARM},
    'shorts': {'waist': WAIST, 'leg_l': leg(1, 0.56, 0.22), 'leg_r': leg(-1, 0.56, 0.22)},
    'pants': {'waist': WAIST, 'leg_l': leg(1, 1.03, 0.18), 'leg_r': leg(-1, 1.03, 0.18),
              'shin_l': SHIN, 'shin_r': SHIN},
}


def write_glb(path, parts):
    binary = bytearray()
    gltf = {'asset': {'version': '2.0', 'generator': 'sport_shop make_garments.py'},
            'scene': 0, 'scenes': [{'nodes': []}], 'nodes': [], 'meshes': [],
            'accessors': [], 'bufferViews': [], 'buffers': []}

    def add_view(data, target):
        while len(binary) % 4:
            binary.append(0)
        gltf['bufferViews'].append({'buffer': 0, 'byteOffset': len(binary),
                                    'byteLength': len(data), 'target': target})
        binary.extend(data)
        return len(gltf['bufferViews']) - 1

    def add_accessor(view, component, count, kind, **extra):
        gltf['accessors'].append({'bufferView': view, 'componentType': component,
                                  'count': count, 'type': kind, **extra})
        return len(gltf['accessors']) - 1

    for name, rings in parts.items():
        positions, normals, indices = tube(rings)
        flat = [value for vertex in positions for value in vertex]
        pos = add_accessor(
            add_view(struct.pack(f'<{len(flat)}f', *flat), 34962), 5126,
            len(positions), 'VEC3',
            min=[min(v[i] for v in positions) for i in range(3)],
            max=[max(v[i] for v in positions) for i in range(3)])
        flat = [value for vertex in normals for value in vertex]
        nor = add_accessor(add_view(struct.pack(f'<{len(flat)}f', *flat), 34962),
                           5126, len(normals), 'VEC3')
        idx = add_accessor(add_view(struct.pack(f'<{len(indices)}H', *indices), 34963),
                           5123, len(indices), 'SCALAR')
        gltf['meshes'].append({'name': name, 'primitives': [
            {'attributes': {'POSITION': pos, 'NORMAL': nor}, 'indices': idx}]})
        gltf['nodes'].append({'name': name, 'mesh': len(gltf['meshes']) - 1})
        gltf['scenes'][0]['nodes'].append(len(gltf['nodes']) - 1)

    while len(binary) % 4:
        binary.append(0)
    gltf['buffers'].append({'byteLength': len(binary)})
    text = json.dumps(gltf, separators=(',', ':')).encode()
    text += b' ' * (-len(text) % 4)
    total = 12 + 8 + len(text) + 8 + len(binary)
    with open(path, 'wb') as out:
        out.write(struct.pack('<4sII', b'glTF', 2, total))
        out.write(struct.pack('<I4s', len(text), b'JSON') + text)
        out.write(struct.pack('<I4s', len(binary), b'BIN\0') + bytes(binary))
    triangles = sum(len(tube(r)[2]) // 3 for r in parts.values())
    print(f'{os.path.basename(path)}: {len(parts)} частей, {triangles} треугольников, {total} байт')


if __name__ == '__main__':
    folder = os.path.join(os.path.dirname(__file__), '..', 'assets', 'models')
    os.makedirs(folder, exist_ok=True)
    for model, parts in MODELS.items():
        write_glb(os.path.join(folder, f'{model}.glb'), parts)
