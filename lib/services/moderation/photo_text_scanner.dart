import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Текст на фото товара: ник Telegram-канала в углу, ссылка, надпись
/// латиницей. Распознаётся на телефоне (ML Kit, без интернета и платных
/// сервисов) и проверяется вместе с описанием товара.
///
/// ML Kit читает латиницу и цифры — этого хватает для ников, ссылок
/// и номеров телефонов, которые прячут на фото.
abstract class PhotoTextScanner {
  /// Текст с фото по пути [path]; null — не удалось или нечего читать.
  Future<String?> scan(String path);
}

/// На телефоне — ML Kit; на компьютере и в тестах — пропускается.
class MlKitPhotoTextScanner implements PhotoTextScanner {
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<String?> scan(String path) async {
    if (!isSupported || path.startsWith('assets/')) return null;
    final TextRecognizer recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final RecognizedText result =
          await recognizer.processImage(InputImage.fromFilePath(path));
      final String text = result.text.trim();
      return text.isEmpty ? null : text;
    } on Exception catch (error) {
      debugPrint('Текст на фото не распознан: $error');
      return null;
    } finally {
      await recognizer.close();
    }
  }
}

/// Без распознавания — для тестов и компьютера.
class NoPhotoTextScanner implements PhotoTextScanner {
  const NoPhotoTextScanner();

  @override
  Future<String?> scan(String path) async => null;
}
