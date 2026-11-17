import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../core/errors/app_exception.dart';
import '../../models/product.dart';
import '../../models/try_on.dart';

/// Примерка по фотографии: общение с локальным сервером на ноутбуке,
/// где работает открытая модель FASHN VTON v1.5.
///
/// Сервер бесплатный и свой: фото отправляются только на компьютер
/// в той же сети Wi-Fi, платные облачные сервисы не используются.
class PhotoTryOnService {
  PhotoTryOnService([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  static const int defaultPort = 8000;
  static const int maxImageBytes = 15 * 1024 * 1024;
  static const int minImageBytes = 2 * 1024;

  static const Duration _healthTimeout = Duration(seconds: 6);
  static const Duration _uploadTimeout = Duration(seconds: 90);
  static const Duration _pollTimeout = Duration(seconds: 12);

  /// Приводит введённый адрес к виду http://192.168.1.5:8000.
  /// null — адрес не похож на адрес сервера.
  static String? normalizeUrl(String input) {
    String text = input.trim();
    if (text.isEmpty || text.contains(' ')) return null;
    if (!text.contains('://')) text = 'http://$text';
    final Uri? uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    final int port = uri.hasPort ? uri.port : defaultPort;
    return '${uri.scheme}://${uri.host}:$port';
  }

  /// Проверка файла до отправки: размер и формат (JPEG, PNG, WebP).
  /// null — файл подходит, иначе текст ошибки.
  static String? validateImage(Uint8List bytes) {
    if (bytes.length < minImageBytes) {
      return 'Файл слишком маленький или повреждён';
    }
    if (bytes.length > maxImageBytes) {
      return 'Фото больше 15 МБ — выберите другое или уменьшите его';
    }
    final bool jpeg = bytes[0] == 0xFF && bytes[1] == 0xD8;
    final bool png = bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E;
    final bool webp = bytes.length > 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
    if (!jpeg && !png && !webp) {
      return 'Нужна фотография в формате JPG, PNG или WebP';
    }
    return null;
  }

  /// Фото товара: из ресурсов приложения или из файла, добавленного
  /// администратором.
  Future<Uint8List> loadProductImage(Product product) async {
    final String? url = product.imageUrl;
    if (url == null || url.isEmpty) {
      throw const AppException('У товара нет фотографии для примерки');
    }
    try {
      if (url.startsWith('assets/')) {
        return (await rootBundle.load(url)).buffer.asUint8List();
      }
      return await File(url).readAsBytes();
    } on Exception {
      throw const AppException('Не удалось открыть фотографию товара');
    }
  }

  /// Доступен ли сервер и готова ли модель.
  Future<TryOnServerStatus> health(String baseUrl) async {
    try {
      final http.Response response = await _client
          .get(Uri.parse('$baseUrl/health'))
          .timeout(_healthTimeout);
      if (response.statusCode != 200) {
        return TryOnServerStatus(
          reachable: false,
          message: 'Сервер ответил ошибкой ${response.statusCode}',
        );
      }
      return TryOnServerStatus.fromJson(_json(response));
    } on TimeoutException {
      return const TryOnServerStatus(
        reachable: false,
        message: 'Сервер не отвечает. Проверьте, что он запущен, а телефон '
            'и ноутбук подключены к одной сети Wi-Fi',
      );
    } on Exception catch (error) {
      debugPrint('Сервер примерки недоступен: $error');
      return const TryOnServerStatus(
        reachable: false,
        message: 'Не удалось подключиться. Проверьте адрес, сеть Wi-Fi '
            'и разрешение в брандмауэре Windows',
      );
    }
  }

  /// Отправляет фото человека и вещи. Возвращает номер задания.
  Future<String> submit(
    String baseUrl, {
    required Uint8List person,
    required Uint8List garment,
    required TryOnCategory category,
    int seed = 42,
  }) async {
    final http.MultipartRequest request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/tryon'))
          ..fields['category'] = category.apiValue
          // Каталожное фото: вещь без человека.
          ..fields['garment_type'] = 'flat-lay'
          ..fields['seed'] = '$seed'
          ..files.add(http.MultipartFile.fromBytes('person', person, filename: 'person.jpg'))
          ..files.add(http.MultipartFile.fromBytes('garment', garment, filename: 'garment.jpg'));
    try {
      final http.Response response = await http.Response.fromStream(
        await _client.send(request).timeout(_uploadTimeout),
      );
      if (response.statusCode != 200) throw AppException(_errorText(response));
      return _json(response)['job_id']! as String;
    } on TimeoutException {
      throw const AppException('Сервер не принял фото вовремя. Попробуйте ещё раз');
    } on SocketException {
      throw const AppException('Нет связи с сервером примерки');
    } on http.ClientException {
      throw const AppException('Нет связи с сервером примерки');
    }
  }

  Future<TryOnJobStatus> status(String baseUrl, String jobId) async {
    final http.Response response = await _client
        .get(Uri.parse('$baseUrl/jobs/$jobId'))
        .timeout(_pollTimeout);
    if (response.statusCode != 200) throw AppException(_errorText(response));
    return TryOnJobStatus.fromJson(_json(response));
  }

  Future<Uint8List> result(String baseUrl, String jobId) async {
    final http.Response response = await _client
        .get(Uri.parse('$baseUrl/jobs/$jobId/result'))
        .timeout(_uploadTimeout);
    if (response.statusCode != 200) throw AppException(_errorText(response));
    return response.bodyBytes;
  }

  /// Отмена генерации и удаление фото с сервера. Ошибки не важны:
  /// сервер и сам удаляет данные через полчаса.
  Future<void> delete(String baseUrl, String jobId) async {
    try {
      await _client
          .delete(Uri.parse('$baseUrl/jobs/$jobId'))
          .timeout(_healthTimeout);
    } on Exception catch (error) {
      debugPrint('Не удалось удалить задание примерки: $error');
    }
  }

  static Map<String, Object?> _json(http.Response response) =>
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>;

  /// Текст ошибки сервера (FastAPI кладёт его в поле detail).
  static String _errorText(http.Response response) {
    try {
      final Object? detail = _json(response)['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
    } on FormatException {
      // Тело ответа — не JSON.
    }
    return 'Сервер примерки вернул ошибку ${response.statusCode}';
  }
}
