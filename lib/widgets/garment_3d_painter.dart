import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/try_on/body_pose.dart';
import '../services/try_on/garment_mesh.dart';

/// Рисует 3D-модель одежды поверх кадра камеры.
///
/// Каждый кадр вершины модели переносятся в положение частей тела
/// ([frames] из BodyRig), треугольники освещаются и сортируются
/// по глубине — дальние рисуются первыми. Рендерер собственный,
/// на Canvas.drawVertices: без WebView и нативных 3D-движков.
class Garment3DPainter extends CustomPainter {
  Garment3DPainter({
    required this.mesh,
    required this.frames,
    required this.color,
    this.opacity = 0.96,
  });

  final GarmentMesh mesh;
  final Map<String, BoneFrame> frames;
  final Color color;
  final double opacity;

  /// Свет падает спереди, сверху и чуть слева.
  static final Vec3 _light = const Vec3(-0.35, -0.55, 0.76).normalized;
  static const double _ambient = 0.5;

  @override
  void paint(Canvas canvas, Size size) {
    final List<_Triangle> triangles = [];
    for (final GarmentPart part in mesh.parts) {
      final BoneFrame? frame = frames[part.name];
      if (frame == null) continue;

      final int count = part.vertexCount;
      final Float32List xs = Float32List(count);
      final Float32List ys = Float32List(count);
      final Float32List zs = Float32List(count);
      final Float32List shade = Float32List(count);
      final Float32List facing = Float32List(count);
      for (int i = 0; i < count; i++) {
        final Vec3 p = frame.apply(
          part.positions[i * 3],
          part.positions[i * 3 + 1],
          part.positions[i * 3 + 2],
        );
        final Vec3 n = frame.rotate(
          part.normals[i * 3],
          part.normals[i * 3 + 1],
          part.normals[i * 3 + 2],
        );
        xs[i] = p.x;
        ys[i] = p.y;
        zs[i] = p.z;
        facing[i] = n.z;
        // Изнанка (нормаль от зрителя) освещается с обратной стороны.
        final double lit = n.z >= 0 ? n.dot(_light) : -n.dot(_light) * 0.4;
        shade[i] = _ambient + (1 - _ambient) * lit.clamp(0, 1);
      }
      for (int t = 0; t < part.indices.length; t += 3) {
        final int a = part.indices[t];
        final int b = part.indices[t + 1];
        final int c = part.indices[t + 2];
        triangles.add(_Triangle(
          xs[a], ys[a], xs[b], ys[b], xs[c], ys[c],
          (zs[a] + zs[b] + zs[c]) / 3,
          shade[a], shade[b], shade[c],
          (facing[a] + facing[b] + facing[c]) < 0,
        ));
      }
    }
    if (triangles.isEmpty) return;
    triangles.sort((a, b) => a.depth.compareTo(b.depth));

    final Float32List positions = Float32List(triangles.length * 6);
    final Int32List colors = Int32List(triangles.length * 3);
    final int alpha = (opacity * 255).round();
    int shaded(double k, bool inside) {
      final double f = inside ? k * 0.55 : k;
      return ui.Color.fromARGB(
        alpha,
        (color.r * 255 * f).round().clamp(0, 255),
        (color.g * 255 * f).round().clamp(0, 255),
        (color.b * 255 * f).round().clamp(0, 255),
      ).toARGB32();
    }

    for (int i = 0; i < triangles.length; i++) {
      final _Triangle t = triangles[i];
      positions[i * 6] = t.ax;
      positions[i * 6 + 1] = t.ay;
      positions[i * 6 + 2] = t.bx;
      positions[i * 6 + 3] = t.by;
      positions[i * 6 + 4] = t.cx;
      positions[i * 6 + 5] = t.cy;
      colors[i * 3] = shaded(t.sa, t.inside);
      colors[i * 3 + 1] = shaded(t.sb, t.inside);
      colors[i * 3 + 2] = shaded(t.sc, t.inside);
    }
    canvas.drawVertices(
      ui.Vertices.raw(ui.VertexMode.triangles, positions, colors: colors),
      BlendMode.srcOver,
      Paint(),
    );
  }

  @override
  bool shouldRepaint(Garment3DPainter oldDelegate) =>
      oldDelegate.frames != frames ||
      oldDelegate.mesh != mesh ||
      oldDelegate.color != color;
}

class _Triangle {
  const _Triangle(
    this.ax, this.ay, this.bx, this.by, this.cx, this.cy,
    this.depth, this.sa, this.sb, this.sc, this.inside,
  );

  final double ax, ay, bx, by, cx, cy;
  final double depth;
  final double sa, sb, sc;

  /// Треугольник повёрнут от зрителя — это внутренняя сторона ткани.
  final bool inside;
}
