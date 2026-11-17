import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sport_shop/core/di/app_dependencies.dart';
import 'package:sport_shop/core/errors/app_exception.dart';
import 'package:sport_shop/data/database/app_database.dart';
import 'package:sport_shop/data/datasources/local/session_local_datasource.dart';
import 'package:sport_shop/data/repositories/try_on_repository.dart';
import 'package:sport_shop/models/product.dart';
import 'package:sport_shop/models/try_on.dart';
import 'package:sport_shop/services/assistant/ai_key_store.dart';
import 'package:sport_shop/services/media_storage.dart';
import 'package:sport_shop/services/try_on/body_pose.dart';
import 'package:sport_shop/services/try_on/garment_color.dart';
import 'package:sport_shop/services/try_on/garment_mesh.dart';
import 'package:sport_shop/services/try_on/photo_try_on_service.dart';
import 'package:sport_shop/state/try_on_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Минимальный «JPEG»: подпись формата и нужный размер файла.
Uint8List fakeJpeg([int size = 4096]) =>
    Uint8List(size)..setAll(0, const [0xFF, 0xD8, 0xFF, 0xE0]);

/// Хранилище фото, которое кладёт настоящий файл во временную папку.
class TempMediaStorage implements MediaStorage {
  TempMediaStorage(this.folder, {this.bytes});

  final Directory folder;
  final Uint8List? bytes;
  final List<String> deleted = [];
  int _counter = 0;

  @override
  Future<String?> pickAndSave({
    required int userId,
    required PhotoKind kind,
    required PhotoSource source,
  }) async {
    final File file = File('${folder.path}/${kind.name}_${++_counter}.jpg');
    await file.writeAsBytes(bytes ?? fakeJpeg());
    return file.path;
  }

  @override
  Future<void> delete(String? path) async {
    if (path == null) return;
    deleted.add(path);
    final File file = File(path);
    if (file.existsSync()) await file.delete();
  }
}

/// Поза человека в кадре: плечи на 0.3, бёдра на 0.55, колени на 0.74.
BodyPose standing({double shift = 0}) => BodyPose({
      BodyJoint.leftShoulder: BodyPoint(0.39 + shift, 0.30),
      BodyJoint.rightShoulder: BodyPoint(0.61 + shift, 0.30),
      BodyJoint.leftElbow: BodyPoint(0.34 + shift, 0.43),
      BodyJoint.rightElbow: BodyPoint(0.66 + shift, 0.43),
      BodyJoint.leftWrist: BodyPoint(0.33 + shift, 0.55),
      BodyJoint.rightWrist: BodyPoint(0.67 + shift, 0.55),
      BodyJoint.leftHip: BodyPoint(0.43 + shift, 0.55),
      BodyJoint.rightHip: BodyPoint(0.57 + shift, 0.55),
      BodyJoint.leftKnee: BodyPoint(0.42 + shift, 0.74),
      BodyJoint.rightKnee: BodyPoint(0.58 + shift, 0.74),
      BodyJoint.leftAnkle: BodyPoint(0.42 + shift, 0.92),
      BodyJoint.rightAnkle: BodyPoint(0.58 + shift, 0.92),
    });

void main() {
  // Фото товаров читаются из ресурсов приложения.
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late AppDependencies deps;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = AppDatabase.withPath(inMemoryDatabasePath);
    deps = AppDependencies.local(
      database,
      sessionStorage: InMemorySessionStorage(),
      aiKeyStore: InMemoryAiKeyStore(),
      tryOnRepository: InMemoryTryOnRepository(),
    );
    await database.database;
  });

  tearDown(() => database.close());

  Future<Product> product(String name) async {
    final List<Product> all = await deps.productRepository.getProducts();
    return all.firstWhere((item) => item.name == name);
  }

  group('Какие товары можно примерить', () {
    test('одежда: категория для фото и 3D-модель для камеры', () async {
      final TryOnSupport tee = TryOnSupport.of(await product('Беговая футболка'));
      expect(tee.category, TryOnCategory.tops);
      expect(tee.shape, GarmentShape.tshirt);

      final TryOnSupport uniform = TryOnSupport.of(await product('Волейбольная форма'));
      expect(uniform.category, TryOnCategory.tops);
      expect(uniform.shape, GarmentShape.jersey);
      expect(TryOnSupport.of(await product('Баскетбольная форма')).shape,
          GarmentShape.jersey);

      expect(TryOnSupport.of(await product('Шорты волейбольные')).shape,
          GarmentShape.shorts);
      expect(TryOnSupport.of(await product('Штаны Adidas')).category,
          TryOnCategory.bottoms);
      expect(TryOnSupport.of(await product('Тайтсы беговые')).shape,
          GarmentShape.pants);
    });

    test('обувь, инвентарь и аксессуары — с понятным объяснением', () async {
      for (final String name in const [
        'Кроссовки для бега',
        'Гиря 8 кг',
        'Бутылка для тренировок',
        'Наколенники волейбольные',
      ]) {
        final TryOnSupport support = TryOnSupport.of(await product(name));
        expect(support.any, isFalse, reason: name);
        expect(support.reason, isNotEmpty, reason: name);
      }
      expect(TryOnSupport.of(await product('Кроссовки для бега')).reason,
          contains('Обувь'));
    });

    test('купальник — только по фотографии', () async {
      final TryOnSupport swimsuit =
          TryOnSupport.of(await product('Спортивный купальник'));
      expect(swimsuit.photo, isTrue);
      expect(swimsuit.live, isFalse);
      expect(swimsuit.category, TryOnCategory.onePieces);
    });
  });

  group('3D-модели одежды', () {
    test('все модели читаются и лёгкие для телефона', () {
      for (final GarmentShape shape in GarmentShape.values) {
        final GarmentMesh mesh =
            GarmentMesh.fromGlb(File(shape.assetPath).readAsBytesSync());
        expect(mesh.parts, isNotEmpty, reason: shape.name);
        expect(mesh.triangleCount, lessThan(1000), reason: shape.name);
        for (final GarmentPart part in mesh.parts) {
          expect(part.normals.length, part.positions.length);
          expect(part.indices.every((index) => index < part.vertexCount), isTrue);
        }
      }
      final GarmentMesh pants =
          GarmentMesh.fromGlb(File(GarmentShape.pants.assetPath).readAsBytesSync());
      expect(pants.parts.map((part) => part.name),
          containsAll(['waist', 'leg_l', 'leg_r', 'shin_l', 'shin_r']));
    });

    test('не GLB — понятная ошибка', () {
      expect(() => GarmentMesh.fromGlb(Uint8List(40)), throwsFormatException);
    });
  });

  group('Посадка по позе', () {
    test('торс садится от плеч к бёдрам и следует за человеком', () {
      final Map<String, BoneFrame> frames = BodyRig.frames(standing(), 1000, 1000);
      final BoneFrame torso = frames['torso']!;
      // Начало — середина плеч, ось y ведёт к середине бёдер.
      expect(torso.origin.x, closeTo(500, 0.5));
      expect(torso.origin.y, closeTo(300, 0.5));
      final Vec3 hips = torso.apply(0, -1, 0);
      expect(hips.x, closeTo(500, 0.5));
      expect(hips.y, closeTo(550, 0.5));
      // Ширина одежды чуть больше расстояния между суставами плеч.
      expect(torso.ax.length, greaterThan(220));

      final BoneFrame moved = BodyRig.frames(standing(shift: 0.1), 1000, 1000)['torso']!;
      expect(moved.origin.x, closeTo(600, 0.5));
    });

    test('рукава и штанины привязаны к своим суставам', () {
      final Map<String, BoneFrame> frames = BodyRig.frames(standing(), 1000, 1000);
      expect(frames.keys, containsAll([
        'sleeve_l', 'sleeve_r', 'forearm_l', 'forearm_r',
        'leg_l', 'leg_r', 'shin_l', 'shin_r', 'waist',
      ]));
      final BoneFrame sleeve = frames['sleeve_l']!;
      // Левый рукав: от левого плеча (390, 300) к левому локтю (340, 430).
      expect(sleeve.origin.x, closeTo(390, 0.5));
      final Vec3 elbow = sleeve.apply(0, 1, 0);
      expect(elbow.x, closeTo(340, 0.5));
      expect(elbow.y, closeTo(430, 0.5));
    });

    test('зеркальное изображение не выворачивает одежду', () {
      final BodyPose mirrored = BodyPose({
        for (final MapEntry<BodyJoint, BodyPoint> entry in standing().joints.entries)
          entry.key: BodyPoint(1 - entry.value.x, entry.value.y),
      });
      final Map<String, BoneFrame> frames = BodyRig.frames(mirrored, 1000, 1000);
      expect(frames['torso']!.ax.x, greaterThan(0));
      // «Левый» рукав одежды — тот, что левее на экране.
      expect(frames['sleeve_l']!.origin.x, lessThan(frames['sleeve_r']!.origin.x));
    });

    test('без плеч одежда не рисуется; без бёдер нет торса', () {
      expect(BodyRig.frames(const BodyPose({}), 100, 100), isEmpty);
      final BodyPose noHips = BodyPose({
        BodyJoint.leftShoulder: const BodyPoint(0.4, 0.3),
        BodyJoint.rightShoulder: const BodyPoint(0.6, 0.3),
        BodyJoint.leftHip: const BodyPoint(0.45, 0.55, 0, 0.1),
      });
      expect(BodyRig.frames(noHips, 100, 100).containsKey('torso'), isFalse);
      expect(noHips.hasTorso, isFalse);
    });

    test('сглаживание убирает дрожание между кадрами', () {
      final BodyPose smooth =
          standing(shift: 0.1).smoothedFrom(standing(), 0.5);
      expect(smooth[BodyJoint.leftShoulder]!.x, closeTo(0.44, 1e-9));
    });
  });

  test('цвет вещи по фото: фон не учитывается', () {
    final Uint8List rgba = Uint8List(100 * 4);
    for (int i = 0; i < 100; i++) {
      // 70 пикселей белого фона и 30 красных.
      rgba.setAll(i * 4, i < 70 ? const [250, 250, 250, 255] : const [200, 20, 30, 255]);
    }
    final color = GarmentColor.dominant(rgba);
    expect((color.r * 255).round(), 200);
    expect((color.g * 255).round(), 20);
  });

  group('Сервис примерки по фото', () {
    test('адрес сервера', () {
      expect(PhotoTryOnService.normalizeUrl('192.168.1.5'), 'http://192.168.1.5:8000');
      expect(PhotoTryOnService.normalizeUrl(' 10.0.2.2:9000 '), 'http://10.0.2.2:9000');
      expect(PhotoTryOnService.normalizeUrl('http://laptop.local:8000/'),
          'http://laptop.local:8000');
      expect(PhotoTryOnService.normalizeUrl(''), isNull);
      expect(PhotoTryOnService.normalizeUrl('ftp://x'), isNull);
    });

    test('проверка изображений', () {
      expect(PhotoTryOnService.validateImage(fakeJpeg()), isNull);
      expect(PhotoTryOnService.validateImage(Uint8List(10)), contains('маленький'));
      expect(PhotoTryOnService.validateImage(Uint8List(5000)), contains('JPG'));
      expect(PhotoTryOnService.validateImage(fakeJpeg(16 * 1024 * 1024)),
          contains('15 МБ'));
    });

    test('состояние сервера', () async {
      final PhotoTryOnService ready = PhotoTryOnService(MockClient((request) async {
        expect(request.url.path, '/health');
        return http.Response(
          jsonEncode({'model_ready': true, 'device': 'cpu', 'seconds_per_step': 21.5}),
          200,
        );
      }));
      final TryOnServerStatus status = await ready.health('http://x:8000');
      expect(status.reachable && status.modelReady, isTrue);
      expect(status.secondsPerStep, 21.5);

      final PhotoTryOnService offline = PhotoTryOnService(
        MockClient((request) async => throw const SocketException('нет сети')),
      );
      final TryOnServerStatus down = await offline.health('http://x:8000');
      expect(down.reachable, isFalse);
      expect(down.message, contains('Wi-Fi'));
    });

    test('ошибка сервера показывается текстом из ответа', () async {
      final PhotoTryOnService service = PhotoTryOnService(MockClient((request) async =>
          http.Response.bytes(utf8.encode(jsonEncode({'detail': 'Фото человека: файл пустой'})), 400)));
      await expectLater(
        service.submit('http://x:8000',
            person: fakeJpeg(), garment: fakeJpeg(), category: TryOnCategory.tops),
        throwsA(isA<AppException>().having((e) => e.message, 'message', 'Фото человека: файл пустой')),
      );
    });
  });

  group('Примерка по фото: полный сценарий', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('try_on_test'));
    tearDown(() => temp.deleteSync(recursive: true));

    /// Сервер-заглушка: принимает задание, два раза отвечает «идёт»,
    /// затем «готово» и отдаёт картинку.
    MockClient fakeServer(List<String> calls) {
      int polls = 0;
      return MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        final String path = request.url.path;
        if (path == '/health') {
          return http.Response(jsonEncode({'model_ready': true, 'device': 'cpu'}), 200);
        }
        if (path == '/tryon') {
          final String body = latin1.decode(request.bodyBytes);
          expect(body, contains('name="category"'));
          expect(body, contains('tops'));
          expect(body, contains('name="person"'));
          expect(body, contains('name="garment"'));
          return http.Response(jsonEncode({'job_id': 'job1', 'total_steps': 20}), 200);
        }
        if (path == '/jobs/job1' && request.method == 'GET') {
          polls++;
          return http.Response(
            jsonEncode(polls < 3
                ? {'state': 'running', 'step': polls * 5, 'total_steps': 20}
                : {'state': 'done', 'step': 20, 'total_steps': 20}),
            200,
          );
        }
        if (path == '/jobs/job1/result') {
          return http.Response.bytes(fakeJpeg(8000), 200);
        }
        if (path == '/jobs/job1' && request.method == 'DELETE') {
          return http.Response('{"deleted":true}', 200);
        }
        return http.Response('{}', 404);
      });
    }

    test('фото → генерация → результат → сохранение → удаление', () async {
      final InMemoryTryOnRepository repository = InMemoryTryOnRepository();
      final List<String> calls = [];
      final TempMediaStorage storage = TempMediaStorage(temp);
      final TryOnController controller = TryOnController(
        repository,
        PhotoTryOnService(fakeServer(calls)),
        storage,
      );
      await controller.setUser(2);
      controller.selectProduct(await product('Беговая футболка'));

      expect(await controller.setServerUrl('192.168.1.5'), isNull);
      expect(controller.serverReady, isTrue);
      expect(repository.serverUrl, 'http://192.168.1.5:8000');

      await controller.pickPerson(PhotoSource.gallery);
      expect(controller.personPhoto, isNotNull);

      await controller.generate();
      expect(controller.error, isNull);
      expect(controller.phase, TryOnPhase.done);
      expect(controller.result!.length, 8000);
      // Результат забран — задание удалено с сервера.
      await Future<void>.delayed(Duration.zero);
      expect(calls, contains('DELETE /jobs/job1'));

      await controller.saveResult();
      expect(controller.saved.single.productId,
          (await product('Беговая футболка')).id);

      // Смена товара сбрасывает результат, но не фото.
      controller.selectProduct(await product('Штаны Adidas'));
      expect(controller.result, isNull);
      expect(controller.personPhoto, isNotNull);

      await controller.deleteAllPhotos();
      expect(controller.personPhoto, isNull);
      expect(controller.saved, isEmpty);
      expect(repository.personPhotos, isEmpty);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('без сервера, фото или с обувью — понятная ошибка', () async {
      final TryOnController controller = TryOnController(
        InMemoryTryOnRepository(),
        PhotoTryOnService(fakeServer([])),
        TempMediaStorage(temp),
      );
      await controller.setUser(2);
      controller.selectProduct(await product('Кроссовки для бега'));
      await controller.generate();
      expect(controller.error, contains('нельзя примерить'));

      controller.selectProduct(await product('Беговая футболка'));
      await controller.generate();
      expect(controller.error, contains('адрес сервера'));

      await controller.setServerUrl('10.0.2.2');
      await controller.generate();
      expect(controller.error, contains('фотографию'));
    });

    test('не картинка — фото не принимается и удаляется', () async {
      final TempMediaStorage storage =
          TempMediaStorage(temp, bytes: Uint8List(5000));
      final TryOnController controller = TryOnController(
        InMemoryTryOnRepository(),
        PhotoTryOnService(fakeServer([])),
        storage,
      );
      await controller.setUser(2);
      await expectLater(
        controller.pickPerson(PhotoSource.camera),
        throwsA(isA<AppException>()),
      );
      expect(controller.personPhoto, isNull);
      expect(storage.deleted, hasLength(1));
    });
  });

  test('файлы примерок на устройстве: сохранение и удаление', () async {
    final Directory temp = Directory.systemTemp.createTempSync('try_on_repo');
    addTearDown(() => temp.deleteSync(recursive: true));
    final LocalTryOnRepository repository =
        LocalTryOnRepository(rootDirectory: () async => temp);
    final TryOnResult first = await repository.saveResult(5, 11, fakeJpeg());
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await repository.saveResult(5, 12, fakeJpeg());
    final List<TryOnResult> saved = await repository.results(5);
    expect(saved.map((item) => item.productId), [12, 11]);
    expect(await repository.results(6), isEmpty);

    await repository.deleteResult(first);
    expect((await repository.results(5)).single.productId, 12);
  });
}
