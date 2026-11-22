import 'dart:math' as math;

/// Точка тела в кадре: x, y — доли ширины и высоты кадра (0..1),
/// z — глубина в тех же единицах, что x (меньше — ближе к камере).
class BodyPoint {
  const BodyPoint(this.x, this.y, [this.z = 0, this.confidence = 1]);

  final double x;
  final double y;
  final double z;

  /// Уверенность модели, что точка найдена (0..1).
  final double confidence;

  BodyPoint lerp(BodyPoint other, double t) => BodyPoint(
        x + (other.x - x) * t,
        y + (other.y - y) * t,
        z + (other.z - z) * t,
        other.confidence,
      );
}

/// Суставы, нужные для посадки одежды.
enum BodyJoint {
  /// Нос — положение головы (для игры с мячом).
  nose,
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
}

/// Поза человека в одном кадре камеры.
class BodyPose {
  const BodyPose(this.joints);

  final Map<BodyJoint, BodyPoint> joints;

  static const double minConfidence = 0.45;

  BodyPoint? operator [](BodyJoint joint) {
    final BodyPoint? point = joints[joint];
    return point == null || point.confidence < minConfidence ? null : point;
  }

  /// Видны плечи и бёдра — можно сажать верх.
  bool get hasTorso =>
      this[BodyJoint.leftShoulder] != null &&
      this[BodyJoint.rightShoulder] != null &&
      this[BodyJoint.leftHip] != null &&
      this[BodyJoint.rightHip] != null;

  /// Сглаживание между кадрами: одежда не дрожит вместе с шумом модели.
  /// [amount] — доля нового кадра (1 — без сглаживания).
  BodyPose smoothedFrom(BodyPose? previous, double amount) {
    if (previous == null) return this;
    return BodyPose({
      for (final MapEntry<BodyJoint, BodyPoint> entry in joints.entries)
        entry.key: previous.joints[entry.key]?.lerp(entry.value, amount) ??
            entry.value,
    });
  }
}

/// Трёхмерный вектор для расчёта посадки.
class Vec3 {
  const Vec3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double k) => Vec3(x * k, y * k, z * k);

  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;

  Vec3 cross(Vec3 o) =>
      Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);

  double get length => math.sqrt(dot(this));

  Vec3 get normalized {
    final double l = length;
    return l < 1e-9 ? const Vec3(0, 0, 1) : this * (1 / l);
  }
}

/// Положение одной части одежды: начало и три оси в пикселях экрана.
/// Вершина модели (x, y, z) попадает в точку origin + ax·x + ay·y + az·z.
class BoneFrame {
  const BoneFrame(this.origin, this.ax, this.ay, this.az);

  final Vec3 origin;
  final Vec3 ax;
  final Vec3 ay;
  final Vec3 az;

  Vec3 apply(double x, double y, double z) =>
      origin + ax * x + ay * y + az * z;

  /// Поворот нормали (без масштаба).
  Vec3 rotate(double x, double y, double z) =>
      (ax.normalized * x + ay.normalized * y + az.normalized * z).normalized;
}

/// Скелет для одежды: по позе считает, где и как повёрнута каждая часть.
///
/// Экранные оси: x вправо, y вниз, z к зрителю.
class BodyRig {
  BodyRig._();

  /// Глубина из модели позы шумная — учитываем её вполсилы.
  static const double _depthWeight = 0.5;

  /// Во сколько раз контур тела шире расстояния между суставами плеч.
  static const double _outlineFactor = 1.22;

  /// Положение частей одежды для кадра размером [width]×[height].
  /// Части, для которых суставы не видны, в результат не попадают.
  static Map<String, BoneFrame> frames(
    BodyPose pose,
    double width,
    double height,
  ) {
    Vec3? at(BodyJoint joint) {
      final BodyPoint? p = pose[joint];
      // Глубина ML Kit растёт от камеры; у нас z — к зрителю.
      return p == null
          ? null
          : Vec3(p.x * width, p.y * height, -p.z * width * _depthWeight);
    }

    final Vec3? ls = at(BodyJoint.leftShoulder);
    final Vec3? rs = at(BodyJoint.rightShoulder);
    final Vec3? lh = at(BodyJoint.leftHip);
    final Vec3? rh = at(BodyJoint.rightHip);
    final Map<String, BoneFrame> result = {};
    if (ls == null || rs == null) return result;

    // Ширина плеч — общий масштаб толщины всех частей. Суставы плеч
    // лежат внутри силуэта, поэтому одежда шире расстояния между ними.
    final Vec3 across = rs - ls;
    if (across.length < 4) return result;
    final double shoulderWidth = across.length * _outlineFactor;

    // Ось «вправо» всегда смотрит вправо по экрану, чтобы одежда
    // не выворачивалась, когда камера зеркалит изображение.
    Vec3 right = across.normalized;
    if (right.x < 0) right = right * -1;

    final Vec3 midShoulder = (ls + rs) * 0.5;
    if (lh != null && rh != null) {
      final Vec3 midHip = (lh + rh) * 0.5;
      final Vec3 spine = midShoulder - midHip; // от бёдер к плечам
      final double torsoLength = spine.length;
      if (torsoLength > 4) {
        final Vec3 up = spine.normalized;
        Vec3 forward = right.cross(up * -1).normalized;
        if (forward.z < 0) forward = forward * -1;
        // Ось «вправо» делаем строго перпендикулярной позвоночнику.
        final Vec3 side = (up * -1).cross(forward).normalized;
        final Vec3 sideAxis = (side.x < 0 ? side * -1 : side) * shoulderWidth;
        final Vec3 depthAxis = forward * shoulderWidth;
        result['torso'] =
            BoneFrame(midShoulder, sideAxis, up * torsoLength, depthAxis);
        result['waist'] =
            BoneFrame(midHip, sideAxis, up * torsoLength, depthAxis);
      }
    }

    /// Конечность: ось y — вдоль кости, толщина — от ширины плеч.
    void limb(String name, Vec3? from, Vec3? to) {
      if (from == null || to == null) return;
      final Vec3 bone = to - from;
      if (bone.length < 2) return;
      final Vec3 along = bone.normalized;
      Vec3 side = along.cross(const Vec3(0, 0, 1)).normalized;
      if (side.length < 0.5) side = const Vec3(1, 0, 0);
      final Vec3 depth = side.cross(along).normalized;
      result[name] = BoneFrame(
        from,
        side * shoulderWidth,
        bone,
        (depth.z < 0 ? depth * -1 : depth) * shoulderWidth,
      );
    }

    // «Левая» часть одежды садится на сустав, который левее на экране.
    final bool swapped = ls.x > rs.x;
    BodyJoint pick(BodyJoint left, BodyJoint right) => swapped ? right : left;

    final Vec3? shoulderA = at(pick(BodyJoint.leftShoulder, BodyJoint.rightShoulder));
    final Vec3? shoulderB = at(pick(BodyJoint.rightShoulder, BodyJoint.leftShoulder));
    final Vec3? elbowA = at(pick(BodyJoint.leftElbow, BodyJoint.rightElbow));
    final Vec3? elbowB = at(pick(BodyJoint.rightElbow, BodyJoint.leftElbow));
    limb('sleeve_l', shoulderA, elbowA);
    limb('sleeve_r', shoulderB, elbowB);
    limb('forearm_l', elbowA, at(pick(BodyJoint.leftWrist, BodyJoint.rightWrist)));
    limb('forearm_r', elbowB, at(pick(BodyJoint.rightWrist, BodyJoint.leftWrist)));

    final Vec3? hipA = at(pick(BodyJoint.leftHip, BodyJoint.rightHip));
    final Vec3? hipB = at(pick(BodyJoint.rightHip, BodyJoint.leftHip));
    final Vec3? kneeA = at(pick(BodyJoint.leftKnee, BodyJoint.rightKnee));
    final Vec3? kneeB = at(pick(BodyJoint.rightKnee, BodyJoint.leftKnee));
    limb('leg_l', hipA, kneeA);
    limb('leg_r', hipB, kneeB);
    limb('shin_l', kneeA, at(pick(BodyJoint.leftAnkle, BodyJoint.rightAnkle)));
    limb('shin_r', kneeB, at(pick(BodyJoint.rightAnkle, BodyJoint.leftAnkle)));
    return result;
  }
}
