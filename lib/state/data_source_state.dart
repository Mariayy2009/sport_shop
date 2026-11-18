import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/datasources/local/shop_server_storage.dart';
import '../data/datasources/remote/shop_api_client.dart';
import '../data/repositories/api_product_repository.dart';
import '../data/repositories/switchable_product_repository.dart';
import 'product_state.dart';

/// Откуда берётся каталог: SQLite на телефоне или сервер магазина
/// с PostgreSQL. Переключение — без перезапуска приложения.
class DataSourceState extends ChangeNotifier {
  DataSourceState({
    required SwitchableProductRepository products,
    required ShopServerStorage storage,
    required ProductState catalog,
    http.Client? client,
  })  : _products = products,
        _storage = storage,
        _catalog = catalog,
        _client = client;

  final SwitchableProductRepository _products;
  final ShopServerStorage _storage;
  final ProductState _catalog;
  final http.Client? _client;

  String? _serverUrl;
  ShopServerStatus? _status;
  bool _isBusy = false;

  /// Сохранённый адрес сервера (даже если сейчас он недоступен).
  String? get serverUrl => _serverUrl;
  ShopServerStatus? get status => _status;
  bool get isBusy => _isBusy;

  /// Каталог сейчас идёт с сервера.
  bool get usesServer => _products.usesServer;

  /// Адрес сохранён, но сервер не ответил — показываются данные телефона.
  bool get serverUnavailable => _serverUrl != null && !usesServer;

  /// При запуске: подключиться к сохранённому серверу, если он отвечает.
  /// Каталог потом загружает AppStates.init().
  Future<void> restore() async {
    _serverUrl = await _storage.readUrl();
    final String? url = _serverUrl;
    if (url != null) await _tryServer(url);
    notifyListeners();
  }

  /// Подключить сервер. Возвращает текст ошибки или null.
  Future<String?> connect(String input) async {
    final String? url = ShopApiClient.normalizeUrl(input);
    if (url == null) return 'Введите адрес вида 192.168.1.5 или 192.168.1.5:8080';
    _setBusy(true);
    final bool ok = await _tryServer(url);
    if (ok) {
      _serverUrl = url;
      await _storage.saveUrl(url);
      await _catalog.init();
    }
    _setBusy(false);
    return ok ? null : (_status?.message ?? 'Сервер не отвечает');
  }

  /// Повторная попытка подключиться к сохранённому серверу.
  Future<String?> retry() async {
    final String? url = _serverUrl;
    return url == null ? null : connect(url);
  }

  /// Работать с каталогом на телефоне; адрес сервера забывается.
  Future<void> useLocal() async {
    _setBusy(true);
    _products.useLocal();
    _serverUrl = null;
    _status = null;
    await _storage.saveUrl(null);
    await _catalog.init();
    _setBusy(false);
  }

  Future<bool> _tryServer(String url) async {
    final ShopApiClient api = ShopApiClient(url, _client);
    _status = await api.health();
    if (_status!.reachable) {
      _products.useServer(ApiProductRepository(api));
      return true;
    }
    debugPrint('Сервер магазина недоступен: ${_status!.message}');
    _products.useLocal();
    return false;
  }

  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }
}
