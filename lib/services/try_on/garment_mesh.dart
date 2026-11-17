import 'dart:convert';
import 'dart:typed_data';

/// Часть 3D-модели одежды, привязанная к одной «кости» тела.
class GarmentPart {
  const GarmentPart({
    required this.name,
    required this.positions,
    required this.normals,
    required this.indices,
  });

  /// Имя узла в файле: torso, sleeve_l, leg_r и т. д.
  final String name;

  /// Координаты вершин: x, y, z подряд.
  final Float32List positions;
  final Float32List normals;

  /// Треугольники: по три номера вершин.
  final Uint32List indices;

  int get vertexCount => positions.length ~/ 3;
  int get triangleCount => indices.length ~/ 3;
}

/// 3D-модель одежды, загруженная из файла GLB (glTF 2.0).
class GarmentMesh {
  const GarmentMesh(this.parts);

  final List<GarmentPart> parts;

  int get triangleCount =>
      parts.fold(0, (sum, part) => sum + part.triangleCount);

  /// Разбор двоичного glTF: заголовок, блок JSON с описанием сцены
  /// и блок BIN с вершинами. Читаются узлы с мешами: позиции,
  /// нормали и индексы треугольников.
  factory GarmentMesh.fromGlb(Uint8List bytes) {
    final ByteData data = ByteData.sublistView(bytes);
    if (bytes.length < 20 || data.getUint32(0, Endian.little) != 0x46546C67) {
      throw const FormatException('Файл не является GLB');
    }
    Map<String, Object?>? gltf;
    Uint8List? binary;
    int offset = 12;
    while (offset + 8 <= bytes.length) {
      final int length = data.getUint32(offset, Endian.little);
      final int type = data.getUint32(offset + 4, Endian.little);
      final Uint8List chunk =
          Uint8List.sublistView(bytes, offset + 8, offset + 8 + length);
      if (type == 0x4E4F534A) {
        gltf = jsonDecode(utf8.decode(chunk)) as Map<String, Object?>;
      } else if (type == 0x004E4942) {
        binary = chunk;
      }
      offset += 8 + length;
    }
    if (gltf == null || binary == null) {
      throw const FormatException('В GLB нет описания сцены или данных');
    }

    final List<Object?> accessors = gltf['accessors']! as List<Object?>;
    final List<Object?> views = gltf['bufferViews']! as List<Object?>;
    final List<Object?> meshes = gltf['meshes']! as List<Object?>;
    final ByteData bin = ByteData.sublistView(binary);

    /// Числа одного аксессора: float32 или целые индексы.
    List<num> read(int accessorIndex) {
      final Map<String, Object?> accessor =
          accessors[accessorIndex]! as Map<String, Object?>;
      final Map<String, Object?> view =
          views[accessor['bufferView']! as int]! as Map<String, Object?>;
      final int start = ((view['byteOffset'] as int?) ?? 0) +
          ((accessor['byteOffset'] as int?) ?? 0);
      final int count = accessor['count']! as int;
      final int components = switch (accessor['type']) {
        'VEC3' => 3,
        'VEC2' => 2,
        _ => 1,
      };
      final int type = accessor['componentType']! as int;
      final int size = switch (type) { 5126 || 5125 => 4, 5123 => 2, _ => 1 };
      final int stride = (view['byteStride'] as int?) ?? size * components;
      final List<num> values = List<num>.filled(count * components, 0);
      for (int i = 0; i < count; i++) {
        for (int c = 0; c < components; c++) {
          final int at = start + i * stride + c * size;
          values[i * components + c] = switch (type) {
            5126 => bin.getFloat32(at, Endian.little),
            5125 => bin.getUint32(at, Endian.little),
            5123 => bin.getUint16(at, Endian.little),
            _ => bin.getUint8(at),
          };
        }
      }
      return values;
    }

    final List<GarmentPart> parts = [];
    for (final Object? rawNode in gltf['nodes']! as List<Object?>) {
      final Map<String, Object?> node = rawNode! as Map<String, Object?>;
      final int? meshIndex = node['mesh'] as int?;
      if (meshIndex == null) continue;
      final Map<String, Object?> mesh =
          meshes[meshIndex]! as Map<String, Object?>;
      for (final Object? rawPrimitive in mesh['primitives']! as List<Object?>) {
        final Map<String, Object?> primitive =
            rawPrimitive! as Map<String, Object?>;
        final Map<String, Object?> attributes =
            primitive['attributes']! as Map<String, Object?>;
        final Float32List positions = Float32List.fromList(
          read(attributes['POSITION']! as int).cast<double>(),
        );
        final int? normalAccessor = attributes['NORMAL'] as int?;
        final Float32List normals = normalAccessor == null
            ? Float32List(positions.length)
            : Float32List.fromList(read(normalAccessor).cast<double>());
        final int? indexAccessor = primitive['indices'] as int?;
        final Uint32List indices = indexAccessor == null
            ? Uint32List.fromList(
                List<int>.generate(positions.length ~/ 3, (i) => i),
              )
            : Uint32List.fromList(read(indexAccessor).cast<int>());
        parts.add(GarmentPart(
          name: (node['name'] as String?) ?? (mesh['name'] as String?) ?? '',
          positions: positions,
          normals: normals,
          indices: indices,
        ));
      }
    }
    if (parts.isEmpty) throw const FormatException('В GLB нет мешей');
    return GarmentMesh(parts);
  }
}
