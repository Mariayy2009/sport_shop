import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../data/repositories/try_on_repository.dart';
import '../models/product.dart';
import '../models/try_on.dart';
import '../services/media_storage.dart';
import '../services/try_on/photo_try_on_service.dart';

/// Этап примерки по фотографии.
enum TryOnPhase {
  /// Выбор фото и товара.
  idle,

  /// Фото отправляются на сервер.
  uploading,

  /// Сервер генерирует изображение.
  generating,

  /// Результат получен.
  done,
}

/// Управляет примеркой по фотографии: адрес сервера, фото пользователя,
/// запуск генерации, ход работы, результат и его сохранение.
class TryOnController extends ChangeNotifier {
  TryOnController(this._repository, this._service, this._storage);

  final TryOnRepository _repository;
  final PhotoTryOnService _service;
  final MediaStorage _storage;

  /// Как часто спрашивать сервер о ходе генерации.
  static const Duration pollInterval = Duration(seconds: 2);

  /// Общий предел ожидания: на процессоре генерация идёт минуты,
  /// но не должна висеть бесконечно.
  static const Duration maxWait = Duration(minutes: 45);

  /// Сколько сбоев связи подряд терпим, прежде чем сдаться.
  static const int _maxNetworkErrors = 6;

  /// Метка этого телефона для сервера: новая примерка отменяет
  /// прежнее задание, если связь с ним прервалась.
  final String _client = List.generate(
    12, (_) => Random().nextInt(16).toRadixString(16),
  ).join();

  int? _userId;
  String? _serverUrl;
  TryOnServerStatus? _server;
  bool _isCheckingServer = false;
  String? _personPhoto;
  Product? _product;
  TryOnPhase _phase = TryOnPhase.idle;
  TryOnJobStatus? _job;
  String? _jobId;
  Uint8List? _result;
  String? _error;
  List<TryOnResult> _saved = const [];
  bool _resultSaved = false;
  int _seed = 42;
  DateTime? _startedAt;

  /// Номер текущей генерации. Отмена, смена вещи или новая генерация
  /// увеличивают его — прежний опрос сервера видит это и молча
  /// прекращается, не трогая экран. Иначе два опроса показывали бы
  /// попеременно «Шаг 1 из 6» и «В очереди».
  int _generation = 0;

  String? get serverUrl => _serverUrl;
  TryOnServerStatus? get server => _server;
  bool get isCheckingServer => _isCheckingServer;
  bool get serverReady => (_server?.reachable ?? false) && (_server?.modelReady ?? false);
  String? get personPhoto => _personPhoto;
  Product? get product => _product;
  TryOnPhase get phase => _phase;
  TryOnJobStatus? get job => _job;
  Uint8List? get result => _result;
  String? get error => _error;
  List<TryOnResult> get saved => _saved;
  bool get resultSaved => _resultSaved;
  bool get isBusy =>
      _phase == TryOnPhase.uploading || _phase == TryOnPhase.generating;
  Duration get elapsed => _startedAt == null
      ? Duration.zero
      : DateTime.now().difference(_startedAt!);

  /// Вызывается при входе / выходе: у каждого пользователя свои фото.
  Future<void> setUser(int? userId) async {
    if (userId == _userId) return;
    _userId = userId;
    _reset(keepProduct: false);
    _personPhoto = null;
    _saved = const [];
    _serverUrl = await _repository.readServerUrl();
    if (userId != null) {
      _personPhoto = await _repository.readPersonPhoto(userId);
      _saved = await _repository.results(userId);
    }
    notifyListeners();
  }

  /// Товар для примерки. Смена товара сбрасывает прошлый результат,
  /// фото пользователя остаётся.
  void selectProduct(Product product) {
    if (_product?.id == product.id) return;
    _product = product;
    _reset(keepProduct: true);
    notifyListeners();
  }

  /// Сохраняет адрес сервера и сразу проверяет его.
  /// Возвращает текст ошибки или null.
  Future<String?> setServerUrl(String input) async {
    final String? url = PhotoTryOnService.normalizeUrl(input);
    if (url == null) {
      return 'Введите адрес вида 192.168.1.5 или 192.168.1.5:8000';
    }
    _serverUrl = url;
    await _repository.saveServerUrl(url);
    await checkServer();
    return (_server?.reachable ?? false) ? null : _server?.message;
  }

  Future<void> checkServer() async {
    final String? url = _serverUrl;
    if (url == null) {
      _server = null;
      notifyListeners();
      return;
    }
    _isCheckingServer = true;
    notifyListeners();
    _server = await _service.health(url);
    _isCheckingServer = false;
    notifyListeners();
  }

  /// Фото пользователя из камеры или галереи.
  Future<void> pickPerson(PhotoSource source) async {
    final int? userId = _userId;
    if (userId == null) {
      throw const AppException('Войдите в аккаунт, чтобы примерять по фотографии');
    }
    final String? path = await _storage.pickAndSave(
      userId: userId,
      kind: PhotoKind.body,
      source: source,
    );
    if (path == null) return;
    final String? problem =
        PhotoTryOnService.validateImage(await File(path).readAsBytes());
    if (problem != null) {
      await _storage.delete(path);
      throw AppException(problem);
    }
    // Прежнее фото больше не нужно — не копим снимки пользователя.
    await _storage.delete(_personPhoto);
    _personPhoto = path;
    await _repository.savePersonPhoto(userId, path);
    _reset(keepProduct: true);
    notifyListeners();
  }

  /// Запускает генерацию. [again] — повторить с другим вариантом
  /// (другое случайное зерно) для тех же фото.
  Future<void> generate({bool again = false}) async {
    final Product? product = _product;
    final String? url = _serverUrl;
    final String? person = _personPhoto;
    final TryOnCategory? category =
        product == null ? null : TryOnSupport.of(product).category;
    if (isBusy) return;
    if (product == null || category == null) {
      _fail('Этот товар нельзя примерить по фотографии');
      return;
    }
    if (url == null) {
      _fail('Укажите адрес сервера примерки');
      return;
    }
    if (person == null) {
      _fail('Сначала добавьте свою фотографию');
      return;
    }

    if (again) _seed++;
    _error = null;
    _result = null;
    _resultSaved = false;
    _job = null;
    final int generation = ++_generation;
    _phase = TryOnPhase.uploading;
    _startedAt = DateTime.now();
    notifyListeners();

    try {
      final Uint8List personBytes = await File(person).readAsBytes();
      final Uint8List garmentBytes = await _service.loadProductImage(product);
      for (final Uint8List bytes in [personBytes, garmentBytes]) {
        final String? problem = PhotoTryOnService.validateImage(bytes);
        if (problem != null) throw AppException(problem);
      }
      final String jobId = await _service.submit(
        url,
        person: personBytes,
        garment: garmentBytes,
        category: category,
        seed: _seed,
        client: _client,
        garmentOnModel: PhotoTryOnService.modelPhotos.contains(product.imageUrl),
      );
      if (generation != _generation) {
        // Пока фото отправлялись, примерку отменили.
        unawaited(_service.delete(url, jobId));
        return;
      }
      _jobId = jobId;
      _phase = TryOnPhase.generating;
      notifyListeners();
      await _waitForResult(url, jobId, generation);
    } on AppException catch (error) {
      _abandon(url, generation);
      if (generation == _generation) _fail(error.message);
    } on Exception catch (error) {
      debugPrint('Ошибка примерки: $error');
      _abandon(url, generation);
      if (generation == _generation) {
        _fail('Не удалось выполнить примерку. Проверьте связь с сервером');
      }
    }
  }

  /// Примерка прервалась — просим сервер удалить задание, чтобы оно
  /// не занимало ноутбук и не держало очередь.
  void _abandon(String url, int generation) {
    final String? jobId = _jobId;
    if (jobId != null && generation == _generation) {
      unawaited(_service.delete(url, jobId));
    }
  }

  /// Опрашивает сервер, пока изображение не будет готово.
  Future<void> _waitForResult(String url, String jobId, int generation) async {
    int networkErrors = 0;
    bool stale() => generation != _generation;
    while (true) {
      if (stale()) return;
      if (elapsed > maxWait) {
        await _service.delete(url, jobId);
        throw const AppException(
          'Генерация идёт слишком долго. Проверьте, не перегружен ли ноутбук',
        );
      }
      await Future<void>.delayed(pollInterval);
      if (stale()) return;
      try {
        final TryOnJobStatus status = await _service.status(url, jobId);
        if (stale()) return;
        networkErrors = 0;
        _job = status;
        if (status.state == TryOnJobState.failed) {
          throw AppException(status.error ?? 'Сервер не смог выполнить примерку');
        }
        if (status.state == TryOnJobState.done) {
          final Uint8List image = await _service.result(url, jobId);
          if (stale()) return;
          _result = image;
          // Результат получен — на сервере он больше не нужен.
          unawaited(_service.delete(url, jobId));
          _jobId = null;
          _phase = TryOnPhase.done;
          notifyListeners();
          return;
        }
        notifyListeners();
      } on AppException {
        rethrow;
      } on Exception catch (error) {
        // Телефон мог на секунду потерять Wi-Fi — генерация на сервере идёт.
        debugPrint('Опрос сервера примерки: $error');
        if (++networkErrors >= _maxNetworkErrors) {
          throw const AppException(
            'Потеряна связь с сервером примерки. Проверьте Wi-Fi и сервер',
          );
        }
      }
    }
  }

  /// Отмена генерации: сервер прекращает работу и удаляет фото.
  Future<void> cancel() async {
    if (!isBusy) return;
    final String? url = _serverUrl;
    final String? jobId = _jobId;
    _reset(keepProduct: true);
    notifyListeners();
    if (url != null && jobId != null) await _service.delete(url, jobId);
  }

  /// Сохраняет результат в папке приложения.
  Future<void> saveResult() async {
    final int? userId = _userId;
    final Uint8List? bytes = _result;
    final Product? product = _product;
    if (userId == null || bytes == null || product == null || _resultSaved) return;
    await _repository.saveResult(userId, product.id!, bytes);
    _saved = await _repository.results(userId);
    _resultSaved = true;
    notifyListeners();
  }

  Future<void> deleteSaved(TryOnResult result) async {
    await _repository.deleteResult(result);
    final int? userId = _userId;
    if (userId != null) _saved = await _repository.results(userId);
    notifyListeners();
  }

  /// Удаляет фото пользователя и все сохранённые примерки.
  Future<void> deleteAllPhotos() async {
    final int? userId = _userId;
    if (userId == null) return;
    await cancel();
    await _repository.deleteAll(userId);
    _personPhoto = null;
    _saved = const [];
    _reset(keepProduct: true);
    notifyListeners();
  }

  /// Вернуться к выбору фото (например, «Примерить заново»).
  void backToStart() {
    _reset(keepProduct: true);
    notifyListeners();
  }

  void _fail(String message) {
    _phase = TryOnPhase.idle;
    _job = null;
    _jobId = null;
    _error = message;
    notifyListeners();
  }

  void _reset({required bool keepProduct}) {
    if (!keepProduct) _product = null;
    // Идущая генерация больше не относится к экрану — и ноутбуку
    // незачем её досчитывать.
    _generation++;
    final String? jobId = _jobId;
    final String? url = _serverUrl;
    if (jobId != null && url != null) unawaited(_service.delete(url, jobId));
    _phase = TryOnPhase.idle;
    _job = null;
    _jobId = null;
    _result = null;
    _resultSaved = false;
    _error = null;
    _startedAt = null;
  }
}
