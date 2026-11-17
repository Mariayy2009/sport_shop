import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/try_on.dart';

/// Данные примерки на устройстве: адрес сервера, фото пользователя
/// и сохранённые результаты. В базе данных ничего не дублируется:
/// настройки лежат в настройках приложения, картинки — файлами.
abstract class TryOnRepository {
  Future<String?> readServerUrl();

  Future<void> saveServerUrl(String? url);

  /// Последнее фото пользователя для примерки (чтобы не выбирать заново).
  Future<String?> readPersonPhoto(int userId);

  Future<void> savePersonPhoto(int userId, String? path);

  Future<TryOnResult> saveResult(int userId, int productId, Uint8List bytes);

  /// Сохранённые примерки, сначала новые.
  Future<List<TryOnResult>> results(int userId);

  Future<void> deleteResult(TryOnResult result);

  /// Удаляет фото пользователя и все его примерки с устройства.
  Future<void> deleteAll(int userId);
}

class LocalTryOnRepository implements TryOnRepository {
  LocalTryOnRepository({Future<Directory> Function()? rootDirectory})
      : _rootDirectory = rootDirectory ?? getApplicationSupportDirectory;

  static const String _serverKey = 'try_on_server_url';
  static const String _personKeyPrefix = 'try_on_person_';

  final Future<Directory> Function() _rootDirectory;
  // Создаётся при первом обращении: файловые операции работают и без него.
  late final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  Future<Directory> _folder(int userId) async {
    final Directory root = await _rootDirectory();
    return Directory(p.join(root.path, 'try_on', '$userId'));
  }

  @override
  Future<String?> readServerUrl() => _preferences.getString(_serverKey);

  @override
  Future<void> saveServerUrl(String? url) => url == null || url.isEmpty
      ? _preferences.remove(_serverKey)
      : _preferences.setString(_serverKey, url);

  @override
  Future<String?> readPersonPhoto(int userId) async {
    final String? path = await _preferences.getString('$_personKeyPrefix$userId');
    // Файл могли удалить вне приложения.
    return path != null && File(path).existsSync() ? path : null;
  }

  @override
  Future<void> savePersonPhoto(int userId, String? path) => path == null
      ? _preferences.remove('$_personKeyPrefix$userId')
      : _preferences.setString('$_personKeyPrefix$userId', path);

  @override
  Future<TryOnResult> saveResult(int userId, int productId, Uint8List bytes) async {
    final Directory folder = await _folder(userId);
    await folder.create(recursive: true);
    final DateTime now = DateTime.now();
    final File file = File(
      p.join(folder.path, 'result_${productId}_${now.millisecondsSinceEpoch}.jpg'),
    );
    await file.writeAsBytes(bytes, flush: true);
    return TryOnResult(path: file.path, productId: productId, createdAt: now);
  }

  @override
  Future<List<TryOnResult>> results(int userId) async {
    final Directory folder = await _folder(userId);
    if (!folder.existsSync()) return const [];
    final List<TryOnResult> items = [];
    for (final FileSystemEntity entity in folder.listSync()) {
      // Имя файла: result_<id товара>_<время>.jpg
      final RegExpMatch? match = RegExp(r'^result_(\d+)_(\d+)\.jpg$')
          .firstMatch(p.basename(entity.path));
      if (entity is! File || match == null) continue;
      items.add(TryOnResult(
        path: entity.path,
        productId: int.parse(match.group(1)!),
        createdAt: DateTime.fromMillisecondsSinceEpoch(int.parse(match.group(2)!)),
      ));
    }
    return items..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> deleteResult(TryOnResult result) async {
    final File file = File(result.path);
    if (file.existsSync()) await file.delete();
  }

  @override
  Future<void> deleteAll(int userId) async {
    final String? person = await _preferences.getString('$_personKeyPrefix$userId');
    if (person != null && File(person).existsSync()) await File(person).delete();
    await _preferences.remove('$_personKeyPrefix$userId');
    final Directory folder = await _folder(userId);
    if (folder.existsSync()) await folder.delete(recursive: true);
  }
}

/// Хранилище в памяти — для тестов.
class InMemoryTryOnRepository implements TryOnRepository {
  String? serverUrl;
  final Map<int, String> personPhotos = {};
  final Map<int, List<TryOnResult>> saved = {};
  int _counter = 0;

  @override
  Future<String?> readServerUrl() async => serverUrl;

  @override
  Future<void> saveServerUrl(String? url) async =>
      serverUrl = url == null || url.isEmpty ? null : url;

  @override
  Future<String?> readPersonPhoto(int userId) async => personPhotos[userId];

  @override
  Future<void> savePersonPhoto(int userId, String? path) async =>
      path == null ? personPhotos.remove(userId) : personPhotos[userId] = path;

  @override
  Future<TryOnResult> saveResult(int userId, int productId, Uint8List bytes) async {
    final TryOnResult result = TryOnResult(
      path: '/memory/result_${productId}_${++_counter}.jpg',
      productId: productId,
      createdAt: DateTime.now(),
    );
    saved.putIfAbsent(userId, () => []).insert(0, result);
    return result;
  }

  @override
  Future<List<TryOnResult>> results(int userId) async =>
      List.of(saved[userId] ?? const []);

  @override
  Future<void> deleteResult(TryOnResult result) async {
    for (final List<TryOnResult> list in saved.values) {
      list.removeWhere((item) => item.path == result.path);
    }
  }

  @override
  Future<void> deleteAll(int userId) async {
    personPhotos.remove(userId);
    saved.remove(userId);
  }
}
