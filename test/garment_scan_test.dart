import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sport_shop/core/di/app_dependencies.dart';
import 'package:sport_shop/data/database/app_database.dart';
import 'package:sport_shop/data/datasources/local/session_local_datasource.dart';
import 'package:sport_shop/data/repositories/preferences_repository.dart';
import 'package:sport_shop/data/repositories/try_on_scan_repository.dart';
import 'package:sport_shop/services/assistant/ai_key_store.dart';
import 'package:sport_shop/services/try_on/body_pose.dart';
import 'package:sport_shop/services/try_on/garment_scan.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Человек в кадре: [width] — ширина плеч (доля кадра), [face] — видно ли лицо.
BodyPose person({double width = 0.2, bool face = true, double? nose}) {
  BodyPoint p(double x, double y, [double c = 1]) => BodyPoint(x, y, 0, c);
  return BodyPose({
    BodyJoint.nose: p(0.5, 0.2, nose ?? (face ? 0.99 : 0.1)),
    BodyJoint.leftShoulder: p(0.5 + width / 2, 0.3),
    BodyJoint.rightShoulder: p(0.5 - width / 2, 0.3),
    BodyJoint.leftHip: p(0.5 + width / 3, 0.55),
    BodyJoint.rightHip: p(0.5 - width / 3, 0.55),
  });
}

void main() {
  test('поворот на 360°: перед, бок, спина, бок — сканирование готово', () {
    final GarmentScan scan = GarmentScan(isBottom: false);
    // Бок до переда не считается — человек должен начать лицом к камере.
    scan.addPose(person(width: 0.06));
    expect(scan.seen, isEmpty);
    expect(scan.addPose(person()), ScanView.front);
    expect(scan.addPose(person(width: 0.06)), ScanView.sideA);
    expect(scan.addPose(person(face: false)), ScanView.back);
    expect(scan.addPose(person(width: 0.06, face: false)), ScanView.sideB);
    expect(scan.progress, 1);
    expect(scan.isComplete, isFalse); // кадра спереди ещё нет
  });

  test('спиной камера «додумывает» лицо — после бока это всё равно спина', () {
    final GarmentScan scan = GarmentScan(isBottom: true);
    expect(scan.addPose(person()), ScanView.front);
    expect(scan.addPose(person(width: 0.06)), ScanView.sideA);
    // Затылок: модель уверена в «носе» на 0,85.
    expect(scan.addPose(person(nose: 0.85)), ScanView.back);
    expect(scan.addPose(person(width: 0.06, nose: 0.85)), ScanView.sideB);
    expect(scan.progress, 1);
  });

  test('вещь вырезается из кадра по маске человека, без зеркала', () {
    // Кадр 40×80 (BGRA, без поворота): слева красное, справа синее.
    const int w = 40, h = 80;
    final Uint8List bgra = Uint8List(w * h * 4);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        bgra.setAll((y * w + x) * 4,
            x < w / 2 ? const [0, 0, 255, 255] : const [255, 0, 0, 255]);
      }
    }
    final GarmentScan scan = GarmentScan(isBottom: false);
    final ScanShot shot = scan.cut(
      ScanFrame(
        planes: [bgra],
        bytesPerRow: const [w * 4],
        bytesPerPixel: const [4],
        width: w,
        height: h,
        rotation: 0,
        mirror: true,
        bgra: true,
        // Человек — всё, кроме правой четверти кадра.
        mask: [for (int y = 0; y < 8; y++) for (int x = 0; x < 8; x++) x < 6 ? 1.0 : 0.0],
        maskWidth: 8,
        maskHeight: 8,
      ),
      person(width: 0.4),
      outWidth: 60,
    )!;
    expect(shot.width, 60);
    expect(shot.anchors.centerX, closeTo(30, 0.5));
    expect(shot.anchors.hipY, greaterThan(shot.anchors.shoulderY));
    // Снимок не зеркальный: красная половина кадра — слева.
    final int row = shot.anchors.shoulderY.round() * shot.width * 4;
    expect(shot.rgba[row + 5 * 4], 255); // красный слева
    expect(shot.rgba[row + 5 * 4 + 3], 255); // непрозрачно (человек)
  });

  test('отсканированная примерка сохраняется и находится по товару', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final Directory temp = Directory.systemTemp.createTempSync('scan_test');
    addTearDown(() => temp.deleteSync(recursive: true));
    final AppDatabase database = AppDatabase.withPath(inMemoryDatabasePath);
    final TryOnScanRepository scans =
        LocalTryOnScanRepository(database, root: () async => temp);
    // Товары есть в базе.
    final AppDependencies deps = AppDependencies.local(
      database,
      sessionStorage: InMemorySessionStorage(),
      aiKeyStore: InMemoryAiKeyStore(),
      preferencesRepository: InMemoryPreferencesRepository(),
    );
    final int productId = (await deps.productRepository.getProducts()).first.id!;
    expect(await scans.forProduct(productId), isNull);
    const ScanAnchors anchors =
        ScanAnchors(shoulderY: 20, hipY: 90, centerX: 50, span: 70, hipSpan: 60);
    await scans.save(
      productId,
      frontPng: Uint8List.fromList([1, 2, 3]),
      front: anchors,
      backPng: Uint8List.fromList([4, 5, 6]),
      back: anchors,
    );
    final ScanRecord record = (await scans.forProduct(productId))!;
    expect(File(record.frontPath).existsSync(), isTrue);
    expect(record.backPath, isNotNull);
    expect(record.front.span, 70);
  });
}
