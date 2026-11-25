import 'dart:math' as math;

import 'package:sqflite/sqflite.dart';

import '../../models/coupon.dart';
import '../database/app_database.dart';
import '../database/database_schema.dart';
import 'notification_repository.dart';

/// Строка таблицы рекордов.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.name,
    required this.score,
  });

  final int userId;
  final String name;
  final int score;
}

/// Результат сохранения: личный рекорд и выданный промокод.
class GameResult {
  const GameResult({required this.best, required this.isRecord, this.coupon});

  final int best;
  final bool isRecord;
  final Coupon? coupon;
}

/// Рекорды игры с мячом и промокоды за них.
abstract class GameRepository {
  /// Очков для промокода на мяч.
  static const int couponScore = 10;
  static const int couponPercent = 5;

  Future<GameResult> saveScore(int userId, String mode, int score);

  /// Лучший результат каждого игрока в режиме [mode].
  Future<List<LeaderboardEntry>> leaderboard(String mode, {int limit = 10});

  /// Неиспользованные промокоды покупателя.
  Future<List<Coupon>> activeCoupons(int userId);

  /// Промокод по коду (без учёта регистра); null — нет такого или уже
  /// использован.
  Future<Coupon?> findCoupon(int userId, String code);

  Future<void> useCoupon(int couponId);
}

class LocalGameRepository implements GameRepository {
  LocalGameRepository(this._appDatabase, {math.Random? random})
      : _random = random ?? math.Random();

  final AppDatabase _appDatabase;
  final math.Random _random;

  @override
  Future<GameResult> saveScore(int userId, String mode, int score) async {
    final Database db = await _appDatabase.database;
    return db.transaction((txn) async {
      final int previous = Sqflite.firstIntValue(await txn.rawQuery(
            'SELECT MAX(score) FROM ${DatabaseSchema.gameScores} '
            'WHERE user_id = ? AND mode = ?',
            [userId, mode],
          )) ??
          0;
      if (score > 0) {
        await txn.insert(DatabaseSchema.gameScores, {
          'user_id': userId,
          'mode': mode,
          'score': score,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      Coupon? coupon;
      if (score >= GameRepository.couponScore) {
        // Один действующий промокод за игру: использовал — можно
        // заработать новый.
        final List<Map<String, Object?>> active = await txn.query(
          DatabaseSchema.coupons,
          where: 'user_id = ? AND scope = ? AND used_at IS NULL',
          whereArgs: [userId, Coupon.scopeBalls],
        );
        if (active.isEmpty) {
          final String code = 'МЯЧ-${1000 + _random.nextInt(9000)}-$userId';
          final int id = await txn.insert(DatabaseSchema.coupons, {
            'user_id': userId,
            'code': code,
            'percent': GameRepository.couponPercent,
            'scope': Coupon.scopeBalls,
            'title': 'За рекорд в игре: $score очков',
            'created_at': DateTime.now().toIso8601String(),
          });
          coupon = Coupon(
            id: id,
            code: code,
            percent: GameRepository.couponPercent,
            scope: Coupon.scopeBalls,
            title: 'За рекорд в игре: $score очков',
          );
          await LocalNotificationRepository.push(
            txn,
            userId: userId,
            title: 'Промокод ${GameRepository.couponPercent}% на мяч',
            body: 'Код $code — введите его при оформлении заказа',
          );
        }
      }
      return GameResult(
        best: math.max(previous, score),
        isRecord: score > previous,
        coupon: coupon,
      );
    });
  }

  @override
  Future<List<LeaderboardEntry>> leaderboard(String mode, {int limit = 10}) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT g.user_id, MAX(g.score) AS best, '
      "TRIM(COALESCE(u.first_name, 'Игрок') || ' ' || "
      "CASE WHEN u.last_name IS NULL OR u.last_name = '' THEN '' "
      "ELSE SUBSTR(u.last_name, 1, 1) || '.' END) AS name "
      'FROM ${DatabaseSchema.gameScores} g '
      'JOIN ${DatabaseSchema.users} u ON u.id = g.user_id '
      'WHERE g.mode = ? GROUP BY g.user_id ORDER BY best DESC, MIN(g.created_at) '
      'LIMIT ?',
      [mode, limit],
    );
    return [
      for (final Map<String, Object?> row in rows)
        LeaderboardEntry(
          userId: row['user_id']! as int,
          name: row['name']! as String,
          score: row['best']! as int,
        ),
    ];
  }

  @override
  Future<List<Coupon>> activeCoupons(int userId) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseSchema.coupons,
      where: 'user_id = ? AND used_at IS NULL',
      whereArgs: [userId],
      orderBy: 'id DESC',
    );
    return rows.map(Coupon.fromMap).toList();
  }

  @override
  Future<Coupon?> findCoupon(int userId, String code) async {
    final String wanted = code.trim().toUpperCase();
    for (final Coupon coupon in await activeCoupons(userId)) {
      if (coupon.code.toUpperCase() == wanted) return coupon;
    }
    return null;
  }

  @override
  Future<void> useCoupon(int couponId) async {
    final Database db = await _appDatabase.database;
    await db.update(
      DatabaseSchema.coupons,
      {'used_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [couponId],
    );
  }
}
