import 'package:flutter/foundation.dart';

import '../data/repositories/fitting_repository.dart';
import '../models/fitting_photos.dart';
import '../services/media_storage.dart';

/// Фото пользователя для примерки и подгонка одежды под фото.
class FittingState extends ChangeNotifier {
  FittingState(this._repository, this._storage);

  final FittingRepository _repository;
  final MediaStorage _storage;

  int? _userId;
  FittingPhotos? _photos;

  FittingPhotos? get photos => _photos;
  bool get hasBody => _photos?.hasBody ?? false;
  bool get hasFace => _photos?.hasFace ?? false;

  /// Вызывается при входе / выходе пользователя.
  Future<void> setUser(int? userId) async {
    if (userId == _userId) return;
    _userId = userId;
    _photos = userId == null ? null : await _repository.get(userId);
    notifyListeners();
  }

  /// Выбор фото лица или фото в полный рост.
  /// Возвращает false, если пользователь отменил выбор.
  Future<bool> pick(PhotoKind kind, PhotoSource source) async {
    final int? userId = _userId;
    if (userId == null) return false;
    final String? path =
        await _storage.pickAndSave(userId: userId, kind: kind, source: source);
    if (path == null) return false;

    final FittingPhotos current =
        _photos ?? FittingPhotos(userId: userId, consentAt: DateTime.now());
    // Прежний файл больше не нужен — не оставляем лишних копий фото.
    await _storage
        .delete(kind == PhotoKind.face ? current.facePath : current.bodyPath);
    await _save(kind == PhotoKind.face
        ? current.copyWith(facePath: path)
        : current.copyWith(bodyPath: path, fitScale: 1, fitWidth: 1, fitDx: 0, fitDy: 0));
    return true;
  }

  Future<void> remove(PhotoKind kind) async {
    final FittingPhotos? current = _photos;
    if (current == null) return;
    await _storage
        .delete(kind == PhotoKind.face ? current.facePath : current.bodyPath);
    final FittingPhotos next = kind == PhotoKind.face
        ? current.copyWith(clearFace: true)
        : current.copyWith(clearBody: true);
    if (next.isEmpty) {
      await _repository.delete(current.userId);
      _photos = null;
      notifyListeners();
    } else {
      await _save(next);
    }
  }

  /// Удаляет все фото и запись о согласии.
  Future<void> deleteAll() async {
    final FittingPhotos? current = _photos;
    if (current == null) return;
    await _storage.delete(current.facePath);
    await _storage.delete(current.bodyPath);
    await _repository.delete(current.userId);
    _photos = null;
    notifyListeners();
  }

  /// Положение одежды на фото меняется жестами — обновляем сразу,
  /// а в базу пишем по окончании жеста ([persistFit]).
  void updateFit({double? scale, double? width, double? dx, double? dy}) {
    final FittingPhotos? current = _photos;
    if (current == null) return;
    _photos = current.copyWith(
      fitScale: scale?.clamp(FittingPhotos.minScale, FittingPhotos.maxScale),
      fitWidth: width?.clamp(FittingPhotos.minWidth, FittingPhotos.maxWidth),
      fitDx: dx?.clamp(-0.5, 0.5),
      fitDy: dy?.clamp(-0.5, 0.5),
    );
    notifyListeners();
  }

  Future<void> persistFit() async {
    final FittingPhotos? current = _photos;
    if (current != null) await _repository.save(current);
  }

  Future<void> _save(FittingPhotos photos) async {
    await _repository.save(photos);
    _photos = photos;
    notifyListeners();
  }
}
