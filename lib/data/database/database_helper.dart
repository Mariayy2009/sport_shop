import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Подготовка SQLite под текущую платформу.
///
/// Android / iOS / macOS — стандартный sqflite.
/// Windows / Linux — sqflite_common_ffi (та же SQLite через FFI),
/// чтобы приложение можно было запускать на ноутбуке.
class DatabaseHelper {
  DatabaseHelper._();

  static void initPlatform() {
    if (kIsWeb) {
      throw UnsupportedError(
        'Веб-версия не поддерживается: используйте Android или Windows.',
      );
    }
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }
}
