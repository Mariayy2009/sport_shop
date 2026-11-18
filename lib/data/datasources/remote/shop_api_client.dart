import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/errors/app_exception.dart';

/// Состояние сервера магазина.
class ShopServerStatus {
  const ShopServerStatus({
    required this.reachable,
    this.database,
    this.products,
    this.message,
  });

  final bool reachable;

  /// Версия базы, например «PostgreSQL 16.4».
  final String? database;
  final int? products;
  final String? message;
}

/// HTTP-клиент сервера магазина (FastAPI + PostgreSQL, папка backend/).
///
/// Ошибки сети и сервера превращаются в AppException с понятным текстом.
class ShopApiClient {
  ShopApiClient(this.baseUrl, [http.Client? client])
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static const int defaultPort = 8080;
  static const Duration _timeout = Duration(seconds: 10);

  /// Приводит введённый адрес к виду http://192.168.1.5:8080.
  static String? normalizeUrl(String input) {
    String text = input.trim();
    if (text.isEmpty || text.contains(' ')) return null;
    if (!text.contains('://')) text = 'http://$text';
    final Uri? uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return '${uri.scheme}://${uri.host}:${uri.hasPort ? uri.port : defaultPort}';
  }

  Future<ShopServerStatus> health() async {
    try {
      final Map<String, Object?> body =
          await getJson('/health') as Map<String, Object?>;
      return ShopServerStatus(
        reachable: true,
        database: body['database'] as String?,
        products: (body['products'] as num?)?.toInt(),
      );
    } on AppException catch (error) {
      return ShopServerStatus(reachable: false, message: error.message);
    }
  }

  /// GET-запрос; возвращает разобранный JSON. null — 404 (не найдено).
  Future<Object?> getJson(
    String path, [
    Map<String, String> query = const {},
  ]) async {
    final Uri uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: query.isEmpty ? null : query,
    );
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(_timeout);
    } on TimeoutException {
      throw const AppException(
        'Сервер магазина не отвечает. Проверьте, что он запущен, '
        'а телефон и компьютер в одной сети Wi-Fi',
      );
    } on SocketException {
      throw const AppException('Нет связи с сервером магазина');
    } on http.ClientException {
      throw const AppException('Нет связи с сервером магазина');
    }
    if (response.statusCode == 404) return null;
    final Object? body = response.bodyBytes.isEmpty
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200) {
      final Object? detail = body is Map<String, Object?> ? body['detail'] : null;
      throw AppException(
        detail is String
            ? detail
            : 'Сервер магазина вернул ошибку ${response.statusCode}',
      );
    }
    return body;
  }
}
