import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sport_shop/services/games/ball_game.dart';
import 'package:sport_shop/services/try_on/body_pose.dart';

/// Человек в кадре 1000×2000: плечи на 30% высоты, щиколотки на 90%.
BodyPose person({
  Offset leftWrist = const Offset(0.38, 0.55),
  Offset rightWrist = const Offset(0.62, 0.55),
  Offset leftElbow = const Offset(0.36, 0.42),
  Offset rightElbow = const Offset(0.64, 0.42),
  double footY = 0.9,
}) {
  BodyPoint p(Offset o) => BodyPoint(o.dx, o.dy);
  return BodyPose({
    BodyJoint.nose: p(const Offset(0.5, 0.2)),
    BodyJoint.leftShoulder: p(const Offset(0.4, 0.3)),
    BodyJoint.rightShoulder: p(const Offset(0.6, 0.3)),
    BodyJoint.leftElbow: p(leftElbow),
    BodyJoint.rightElbow: p(rightElbow),
    BodyJoint.leftWrist: p(leftWrist),
    BodyJoint.rightWrist: p(rightWrist),
    BodyJoint.leftHip: p(const Offset(0.45, 0.55)),
    BodyJoint.rightHip: p(const Offset(0.55, 0.55)),
    BodyJoint.leftKnee: p(const Offset(0.45, 0.72)),
    BodyJoint.rightKnee: p(const Offset(0.55, 0.75)),
    BodyJoint.leftAnkle: p(Offset(0.5, footY)),
    BodyJoint.rightAnkle: p(const Offset(0.56, 0.92)),
  });
}

/// Ведёт игру [seconds] секунд по 1/60 с, возвращает касания.
List<BallHit> run(BallGame game, double seconds) {
  final List<BallHit> hits = [];
  for (int i = 0; i < (seconds * 60).round(); i++) {
    final BallHit? hit = game.step(1 / 60);
    if (hit != null) hits.add(hit);
    if (game.phase == BallGamePhase.over) break;
  }
  return hits;
}

void main() {
  const Size frame = Size(1000, 2000);

  test('чеканка: мяч, упавший на голову, отскакивает вверх, +1 очко', () {
    final BallGame game = BallGame(size: frame)..start();
    game.updatePose(person());
    final List<BallHit> hits = run(game, 1.0);
    expect(hits, isNotEmpty);
    expect(hits.first.part, HitPart.head);
    expect(game.score, greaterThanOrEqualTo(1));
    expect(game.phase, BallGamePhase.playing);
  });

  test('без человека мяч падает — игра окончена', () {
    final BallGame game = BallGame(size: frame)..start();
    game.updatePose(null);
    run(game, 5);
    expect(game.phase, BallGamePhase.over);
    expect(game.score, 0);
  });

  test('нижний приём: засчитываются только сведённые предплечья ниже плеч', () {
    // Руки разведены широко — техника неправильная.
    final BallGame wrong = BallGame(size: frame, mode: BallGameMode.volleyballLow)
      ..start();
    wrong.updatePose(person(
      leftWrist: const Offset(0.1, 0.5),
      rightWrist: const Offset(0.9, 0.5),
    ));
    run(wrong, 4);
    expect(wrong.score, 0);

    final BallGame right = BallGame(size: frame, mode: BallGameMode.volleyballLow)
      ..start();
    right.updatePose(person(
      leftWrist: const Offset(0.47, 0.55),
      rightWrist: const Offset(0.53, 0.55),
      leftElbow: const Offset(0.44, 0.45),
      rightElbow: const Offset(0.56, 0.45),
    ));
    final List<BallHit> hits = run(right, 1.2);
    expect(hits.map((hit) => hit.part), contains(HitPart.forearms));
    // Голова в волейболе не считается.
    expect(hits.any((hit) => hit.part == HitPart.head), isFalse);
  });

  test('верхний приём: запястья почти не видны, но локти подняты — засчитывается', () {
    final BallGame game = BallGame(size: frame, mode: BallGameMode.volleyballHigh)
      ..start();
    BodyPoint p(double x, double y, [double c = 1]) => BodyPoint(x, y, 0, c);
    game.updatePose(BodyPose({
      BodyJoint.nose: p(0.5, 0.2),
      BodyJoint.leftShoulder: p(0.4, 0.3),
      BodyJoint.rightShoulder: p(0.6, 0.3),
      BodyJoint.leftElbow: p(0.43, 0.2),
      BodyJoint.rightElbow: p(0.57, 0.2),
      BodyJoint.leftWrist: p(0.46, 0.12, 0.05), // камера не уверена
      BodyJoint.rightWrist: p(0.54, 0.12, 0.05),
    }));
    expect(run(game, 1), isNotEmpty);
  });

  test('верхний приём: ладони должны быть выше головы', () {
    final BallGame low = BallGame(size: frame, mode: BallGameMode.volleyballHigh)
      ..start();
    low.updatePose(person()); // ладони на уровне пояса
    run(low, 4);
    expect(low.score, 0);

    final BallGame high = BallGame(size: frame, mode: BallGameMode.volleyballHigh)
      ..start();
    high.updatePose(person(
      leftWrist: const Offset(0.47, 0.12),
      rightWrist: const Offset(0.53, 0.12),
    ));
    final List<BallHit> hits = run(high, 1);
    expect(hits, isNotEmpty);
    expect(hits.every((hit) => hit.part == HitPart.hands), isTrue);
  });

  test('одно касание — одно очко, после удара мяч летит вверх', () {
    final BallGame game = BallGame(size: frame)..start();
    game.updatePose(person());
    BallHit? hit;
    while (hit == null && game.phase == BallGamePhase.playing) {
      hit = game.step(1 / 60);
    }
    expect(game.score, 1);
    expect(game.velocity.dy, lessThan(0));
    // Пока мяч летит вверх, повторных очков нет.
    while (game.velocity.dy < 0) {
      expect(game.step(1 / 60), isNull);
    }
    expect(game.score, 1);
    // Высшая точка — в кадре.
    expect(game.position.dy, greaterThan(0));
  });

  test('без камеры можно отбивать мяч пальцем', () {
    final BallGame game = BallGame(size: frame)..start();
    run(game, 0.5);
    expect(game.tap(game.position), isTrue);
    expect(game.score, 1);
    expect(game.tap(const Offset(0, 0)), isFalse);
  });

  test('дриблинг: мяч отскакивает от пола, ладонь бьёт вниз — очко', () {
    final BallGame game = BallGame(size: frame, mode: BallGameMode.basketball)
      ..start();
    // Ладонь на уровне пояса, ноги на 90% высоты.
    game.updatePose(person(
      leftWrist: const Offset(0.5, 0.5),
      rightWrist: const Offset(0.62, 0.55),
    ));
    final List<BallHit> hits = run(game, 4);
    expect(game.phase, BallGamePhase.playing);
    expect(hits.length, greaterThanOrEqualTo(3));
    expect(hits.every((hit) => hit.part == HitPart.hands), isTrue);
  });

  test('дриблинг: без ладони мяч затухает — игра окончена', () {
    final BallGame game = BallGame(size: frame, mode: BallGameMode.basketball)
      ..start();
    game.updatePose(null);
    run(game, 10);
    expect(game.phase, BallGamePhase.over);
  });
}
