import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Хеширование паролей.
///
/// В БД хранится только хеш, а не сам пароль.
/// Для локальной учебной версии достаточно SHA-256 с «солью».
/// В дипломе хеширование переедет на сервер (bcrypt/argon2),
/// а приложение будет отправлять пароль по HTTPS.
class PasswordHasher {
  PasswordHasher._();

  static const String _salt = 'sport_shop_local_salt_v1';

  static String hash(String password) {
    return sha256.convert(utf8.encode('$_salt:$password')).toString();
  }

  static bool verify(String password, String storedHash) {
    return hash(password) == storedHash;
  }
}
