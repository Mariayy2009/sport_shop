import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Откуда взять фотографию.
enum PhotoSource {
  camera('Сделать фото'),
  gallery('Выбрать из галереи');

  const PhotoSource(this.label);

  final String label;
}

/// Назначение фотографии — попадает в имя файла.
enum PhotoKind { avatar, face, body, product, exhibit }

/// Хранилище фотографий пользователя: аватар и фото для примерки.
///
/// Сейчас файлы лежат в закрытой папке приложения на устройстве
/// и никуда не отправляются. С появлением сервера здесь же появится
/// реализация с загрузкой по защищённому каналу.
abstract class MediaStorage {
  /// Открывает камеру или галерею и сохраняет выбранное фото.
  /// Возвращает путь к файлу или null, если пользователь отменил выбор.
  Future<String?> pickAndSave({
    required int userId,
    required PhotoKind kind,
    required PhotoSource source,
  });

  /// Удаляет файл; отсутствие файла — не ошибка.
  Future<void> delete(String? path);
}

class DeviceMediaStorage implements MediaStorage {
  DeviceMediaStorage([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Фото уменьшается при выборе: для экрана телефона этого достаточно,
  /// а файл занимает в разы меньше места.
  static const double _maxSide = 1600;
  static const int _quality = 88;

  @override
  Future<String?> pickAndSave({
    required int userId,
    required PhotoKind kind,
    required PhotoSource source,
  }) async {
    final XFile? picked = await _picker.pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: _maxSide,
      maxHeight: _maxSide,
      imageQuality: _quality,
      preferredCameraDevice:
          kind == PhotoKind.body ? CameraDevice.rear : CameraDevice.front,
    );
    if (picked == null) return null;

    final Directory root = await getApplicationSupportDirectory();
    final Directory folder =
        Directory(p.join(root.path, 'user_media', '$userId'));
    await folder.create(recursive: true);
    final String extension =
        p.extension(picked.path).isEmpty ? '.jpg' : p.extension(picked.path);
    final String target = p.join(
      folder.path,
      '${kind.name}_${DateTime.now().millisecondsSinceEpoch}$extension',
    );
    await picked.saveTo(target);
    return target;
  }

  @override
  Future<void> delete(String? path) async {
    if (path == null) return;
    final File file = File(path);
    if (await file.exists()) await file.delete();
  }
}
