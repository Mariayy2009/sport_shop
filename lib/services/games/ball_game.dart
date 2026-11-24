import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import '../try_on/body_pose.dart';

/// Режим игры: чем набивать мяч.
enum BallGameMode {
  football(
    'Чеканка',
    'Футбол',
    'Набивай мяч стопой, коленом или головой',
  ),
  volleyballLow(
    'Нижний приём',
    'Волейбол',
    'Руки вместе, предплечья — «площадка» ниже плеч',
  ),
  volleyballHigh(
    'Верхний приём',
    'Волейбол',
    'Встречай мяч ладонями над головой',
  ),
  basketball(
    'Дриблинг',
    'Баскетбол',
    'Веди мяч: бей ладонью вниз, когда он отскочит от пола',
  );

  const BallGameMode(this.title, this.sport, this.hint);

  final String title;
  final String sport;

  /// Как правильно бить в этом режиме — подсказка на экране.
  final String hint;

  bool get isVolleyball => this == volleyballLow || this == volleyballHigh;
}

enum BallGamePhase {
  /// Мяч висит вверху, ждём «Подбросить».
  ready,
  playing,

  /// Мяч упал.
  over,
}

/// Чем отбит мяч — для подсказки и отладки.
enum HitPart { foot, knee, head, forearms, hands, finger }

/// Касание мяча в этом кадре.
class BallHit {
  const BallHit(this.part, this.at);

  final HitPart part;

  /// Точка касания в координатах кадра.
  final Offset at;
}

/// Игра «набей мяч»: мяч летит под действием тяжести, его отбивают
/// частями тела, найденными камерой (ML Kit Pose).
///
/// Вся физика — в координатах кадра камеры (пиксели [size]),
/// без привязки к Flutter: класс проверяется обычными тестами.
class BallGame {
  BallGame({required this.size, this.mode = BallGameMode.football}) {
    reset();
  }

  /// Размер кадра (вертикальный, как на экране).
  Size size;
  BallGameMode mode;

  BallGamePhase phase = BallGamePhase.ready;
  Offset position = Offset.zero;
  Offset velocity = Offset.zero;

  /// Поворот мяча (рад) — мяч крутится от касаний.
  double angle = 0;
  double spin = 0;
  int score = 0;

  /// Последнее касание — для вспышки на экране.
  BallHit? lastHit;
  double _cooldown = 0;

  /// Положение частей тела в прошлом кадре позы — для их скорости.
  Map<HitPart, Offset> _previousParts = const {};
  double _sinceLastPose = 0;
  Map<HitPart, Offset> _partVelocity = const {};

  // Масштаб физики — от высоты кадра, чтобы на любом телефоне
  // мяч летел одинаково.
  /// Ускорение падения: доля высоты кадра за секунду².
  static const double gravity = 1.35;

  /// Скорость отскока: мяч взлетает примерно на 45% высоты кадра.
  static const double launch = 1.1;

  /// Радиус мяча — доля ширины кадра.
  static const double ballRadius = 0.075;

  /// После касания мяч какое-то время не отбивается повторно:
  /// одно касание — одно очко.
  static const double hitCooldown = 0.3;

  double get radius => size.width * ballRadius;
  double get _h => size.height;

  void reset() {
    phase = BallGamePhase.ready;
    position = Offset(size.width / 2, _h * 0.12);
    velocity = Offset.zero;
    angle = 0;
    spin = 0;
    score = 0;
    lastHit = null;
    _cooldown = 0;
  }

  /// Подбросить мяч — начать игру.
  void start() {
    reset();
    phase = BallGamePhase.playing;
    velocity = Offset(0, _h * 0.05);
    // Дриблинг начинается с мяча в руке — на уровне пояса.
    if (mode == BallGameMode.basketball) position = Offset(size.width / 2, _h * 0.45);
  }

  /// Новая поза от камеры. [dt] — секунд с прошлой позы.
  void updatePose(BodyPose? pose) {
    final Map<HitPart, Offset> parts = pose == null ? const {} : _partsOf(pose);
    final double dt = math.max(_sinceLastPose, 1 / 60);
    _partVelocity = {
      for (final MapEntry<HitPart, Offset> entry in parts.entries)
        if (_previousParts[entry.key] != null)
          entry.key: (entry.value - _previousParts[entry.key]!) / dt,
    };
    _previousParts = parts;
    _sinceLastPose = 0;
    _pose = pose;
  }

  BodyPose? _pose;

  /// Точки тела, которыми сейчас можно бить (для подсветки на экране).
  Map<HitPart, Offset> get parts => _previousParts;

  /// Шаг физики: [dt] секунд. Возвращает касание, если оно было.
  BallHit? step(double dt) {
    _sinceLastPose += dt;
    if (phase != BallGamePhase.playing) return null;
    _cooldown = math.max(0, _cooldown - dt);

    velocity = velocity + Offset(0, gravity * _h * dt);
    position = position + velocity * dt;
    angle += spin * dt;
    spin *= math.pow(0.6, dt).toDouble();

    // Стены: мяч не улетает за край кадра.
    if (position.dx < radius && velocity.dx < 0 ||
        position.dx > size.width - radius && velocity.dx > 0) {
      velocity = Offset(-velocity.dx * 0.7, velocity.dy);
      position = Offset(position.dx.clamp(radius, size.width - radius), position.dy);
    }

    BallHit? hit;
    final BodyPose? pose = _pose;
    if (mode == BallGameMode.basketball) {
      _floorBounce(pose);
      if (pose != null && _cooldown == 0) hit = _dribble(pose);
    } else if (pose != null && _cooldown == 0 && velocity.dy > 0) {
      hit = _collide(pose);
    }
    if (hit != null) {
      score++;
      lastHit = hit;
      _cooldown = hitCooldown;
    }

    if (position.dy - radius > _h) phase = BallGamePhase.over;
    return hit;
  }

  /// Удар пальцем по экрану — для проверки игры без камеры
  /// (компьютер, эмулятор). Засчитывается, если попал по мячу.
  bool tap(Offset at) {
    if (phase != BallGamePhase.playing) return false;
    if ((at - position).distance > radius * 1.6) return false;
    if (mode == BallGameMode.basketball) {
      velocity = Offset(0, dribbleSpeed * _h);
    } else {
      _bounce(at, Offset.zero, HitPart.finger);
    }
    score++;
    lastHit = BallHit(HitPart.finger, at);
    _cooldown = hitCooldown;
    return true;
  }

  // ---------------------------------------------------------------------------
  // Части тела

  Offset? _at(BodyPose pose, BodyJoint joint) {
    final BodyPoint? point = pose[joint];
    return point == null ? null : Offset(point.x * size.width, point.y * _h);
  }

  /// Ширина плеч — масштаб тела в кадре (чем ближе человек, тем больше).
  double? _shoulderWidth(BodyPose pose) {
    final Offset? l = _at(pose, BodyJoint.leftShoulder);
    final Offset? r = _at(pose, BodyJoint.rightShoulder);
    return l == null || r == null ? null : (l - r).distance;
  }

  /// Точки, которыми можно бить в этом режиме.
  Map<HitPart, Offset> _partsOf(BodyPose pose) {
    final Map<HitPart, Offset> parts = {};
    void put(HitPart part, Offset? point) {
      if (point != null) parts[part] = point;
    }

    switch (mode) {
      case BallGameMode.football:
        // Стопа чуть ниже щиколотки; берём ту, что выше (ей и бьют).
        final List<Offset> feet = [
          for (final BodyJoint joint in [BodyJoint.leftAnkle, BodyJoint.rightAnkle])
            if (_at(pose, joint) case final Offset ankle) ankle,
        ];
        if (feet.isNotEmpty) {
          feet.sort((a, b) => a.dy.compareTo(b.dy));
          put(HitPart.foot, feet.first);
        }
        final List<Offset> knees = [
          for (final BodyJoint joint in [BodyJoint.leftKnee, BodyJoint.rightKnee])
            if (_at(pose, joint) case final Offset knee) knee,
        ];
        if (knees.isNotEmpty) {
          knees.sort((a, b) => a.dy.compareTo(b.dy));
          put(HitPart.knee, knees.first);
        }
        put(HitPart.head, _head(pose));
      case BallGameMode.volleyballLow:
        final Offset? le = _at(pose, BodyJoint.leftElbow);
        final Offset? re = _at(pose, BodyJoint.rightElbow);
        final Offset? lw = _at(pose, BodyJoint.leftWrist);
        final Offset? rw = _at(pose, BodyJoint.rightWrist);
        if (le != null && re != null && lw != null && rw != null) {
          // Середина «площадки» — между серединами локтей и запястий.
          put(HitPart.forearms, Offset.lerp((le + re) / 2, (lw + rw) / 2, 0.6));
        }
      case BallGameMode.volleyballHigh:
        final Offset? lw = _at(pose, BodyJoint.leftWrist);
        final Offset? rw = _at(pose, BodyJoint.rightWrist);
        if (lw != null && rw != null) put(HitPart.hands, (lw + rw) / 2);
      case BallGameMode.basketball:
        // Ведут одной рукой — берём ту ладонь, что ближе к мячу.
        final List<Offset> hands = [
          for (final BodyJoint joint in [BodyJoint.leftWrist, BodyJoint.rightWrist])
            if (_at(pose, joint) case final Offset wrist) wrist,
        ];
        if (hands.isNotEmpty) {
          hands.sort((a, b) =>
              (a - position).distance.compareTo((b - position).distance));
          put(HitPart.hands, hands.first);
        }
    }
    return parts;
  }

  // ---------------------------------------------------------------------------
  // Баскетбол: дриблинг

  /// Скорость, с которой ладонь отправляет мяч в пол (доля высоты кадра/с).
  static const double dribbleSpeed = 1.5;

  /// Отскок от пола: доля скорости, которая остаётся у мяча.
  static const double floorBounce = 0.8;

  /// Пол — уровень стоп; без человека в кадре — низ кадра.
  double _floorY(BodyPose? pose) {
    if (pose == null) return _h * 0.95;
    final List<double> ankles = [
      for (final BodyJoint joint in [BodyJoint.leftAnkle, BodyJoint.rightAnkle])
        if (_at(pose, joint) case final Offset ankle) ankle.dy,
    ];
    if (ankles.isEmpty) return _h * 0.95;
    return math.min(ankles.reduce(math.max) + radius * 0.3, _h * 0.98);
  }

  /// Мяч ударился о пол. Если без ладони он уже не поднимается
  /// до колен — мяч «умер», игра окончена.
  void _floorBounce(BodyPose? pose) {
    final double floor = _floorY(pose);
    if (position.dy + radius < floor || velocity.dy <= 0) return;
    position = Offset(position.dx, floor - radius);
    velocity = Offset(velocity.dx * 0.9, -velocity.dy * floorBounce);
    final double peak = velocity.dy * velocity.dy / (2 * gravity * _h);
    final double knee = (pose == null ? null : _kneeY(pose)) ?? _h * 0.75;
    if (floor - peak > knee) phase = BallGamePhase.over;
  }

  double? _kneeY(BodyPose pose) {
    final List<double> knees = [
      for (final BodyJoint joint in [BodyJoint.leftKnee, BodyJoint.rightKnee])
        if (_at(pose, joint) case final Offset knee) knee.dy,
    ];
    return knees.isEmpty ? null : knees.reduce(math.max);
  }

  /// Ладонь встречает мяч сверху и толкает в пол.
  BallHit? _dribble(BodyPose pose) {
    final Offset? hand = _partsOf(pose)[HitPart.hands];
    if (hand == null) return null;
    final double reach = (_shoulderWidth(pose) ?? size.width * 0.3) * 0.45;
    final Offset delta = position - hand;
    // Ладонь над мячом (или рядом), мяч не летит уже вниз быстро.
    if (delta.distance > radius + reach || delta.dy < -radius * 0.8) return null;
    if (velocity.dy > dribbleSpeed * _h * 0.5) return null;
    final Offset handVelocity = _partVelocity[HitPart.hands] ?? Offset.zero;
    velocity = Offset(
      (handVelocity.dx * 0.3).clamp(-0.3 * size.width, 0.3 * size.width),
      dribbleSpeed * _h + math.max(0, handVelocity.dy) * 0.2,
    );
    spin = velocity.dx / radius;
    return BallHit(HitPart.hands, hand);
  }

  /// Голова: нос, а если его не видно — над серединой плеч.
  Offset? _head(BodyPose pose) {
    final Offset? nose = _at(pose, BodyJoint.nose);
    if (nose != null) return nose;
    final Offset? l = _at(pose, BodyJoint.leftShoulder);
    final Offset? r = _at(pose, BodyJoint.rightShoulder);
    if (l == null || r == null) return null;
    return (l + r) / 2 - Offset(0, (l - r).distance * 0.7);
  }

  // ---------------------------------------------------------------------------
  // Столкновения

  BallHit? _collide(BodyPose pose) {
    final double shoulders = _shoulderWidth(pose) ?? size.width * 0.3;
    final Map<HitPart, Offset> parts = _partsOf(pose);
    for (final MapEntry<HitPart, Offset> entry in parts.entries) {
      if (!_validForm(entry.key, pose)) continue;
      // Зона касания растёт с телом в кадре: стопа и голова — пятно,
      // предплечья и ладони — пошире.
      final double reach = switch (entry.key) {
        HitPart.foot => shoulders * 0.45,
        HitPart.knee => shoulders * 0.4,
        HitPart.head => shoulders * 0.4,
        HitPart.forearms => shoulders * 0.75,
        HitPart.hands => shoulders * 0.6,
        HitPart.finger => 0,
      };
      final Offset point = entry.value;
      final Offset delta = position - point;
      // Мяч должен быть над частью тела или рядом с ней.
      if (delta.distance <= radius + reach && delta.dy < radius * 0.8) {
        _bounce(point, _partVelocity[entry.key] ?? Offset.zero, entry.key);
        return BallHit(entry.key, point);
      }
    }
    return null;
  }

  /// Правильная ли техника в этом кадре.
  bool _validForm(HitPart part, BodyPose pose) {
    final Offset? ls = _at(pose, BodyJoint.leftShoulder);
    final Offset? rs = _at(pose, BodyJoint.rightShoulder);
    final double? shouldersY = ls == null || rs == null ? null : (ls.dy + rs.dy) / 2;
    switch (part) {
      case HitPart.forearms:
        // Нижний приём: запястья ниже плеч и сведены вместе.
        final Offset? lw = _at(pose, BodyJoint.leftWrist);
        final Offset? rw = _at(pose, BodyJoint.rightWrist);
        if (lw == null || rw == null || shouldersY == null) return false;
        final double together = (lw - rw).distance;
        return lw.dy > shouldersY &&
            rw.dy > shouldersY &&
            together < (_shoulderWidth(pose) ?? size.width) * 0.9;
      case HitPart.hands:
        // Верхний приём: обе ладони выше головы.
        final Offset? lw = _at(pose, BodyJoint.leftWrist);
        final Offset? rw = _at(pose, BodyJoint.rightWrist);
        final Offset? head = _head(pose);
        if (lw == null || rw == null || head == null) return false;
        return lw.dy < head.dy && rw.dy < head.dy;
      case HitPart.foot:
      case HitPart.knee:
      case HitPart.head:
      case HitPart.finger:
        return true;
    }
  }

  /// Отскок: всегда вверх, сила зависит от того, как быстро часть тела
  /// шла навстречу мячу; вбок — от точки удара.
  void _bounce(Offset from, Offset partVelocity, HitPart part) {
    final double up = launch * _h +
        math.max(0, -partVelocity.dy) * 0.25; // подбили вверх — выше
    // Мяч не должен улетать за верх кадра: высшая точка полёта —
    // не выше 8% высоты (v² = 2·g·высота).
    final double ceiling = math.sqrt(
      2 * gravity * _h * math.max(from.dy - radius - _h * 0.08, _h * 0.05),
    );
    final double side = (position.dx - from.dx) * 2.2 + partVelocity.dx * 0.2;
    velocity = Offset(
      side.clamp(-0.5 * size.width, 0.5 * size.width),
      -math.min(math.min(up, launch * _h * 1.35), ceiling),
    );
    spin = side / radius * 0.6;
    position = Offset(position.dx, math.min(position.dy, from.dy - radius * 0.5));
  }
}
