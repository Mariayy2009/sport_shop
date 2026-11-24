import 'package:sqflite/sqflite.dart';

import '../../models/enums.dart';
import '../../models/question.dart';
import '../../models/review.dart';
import '../database/app_database.dart';
import '../database/database_schema.dart';
import 'feedback_repository.dart';

/// Отзывы и вопросы в SQLite (таблицы reviews и questions).
class LocalFeedbackRepository implements FeedbackRepository {
  LocalFeedbackRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  /// Имя автора: «Мария Г.» — фамилия сокращается до буквы.
  static const String _authorName =
      "TRIM(COALESCE(u.first_name, 'Покупатель') || ' ' || "
      "CASE WHEN u.last_name IS NULL OR u.last_name = '' THEN '' "
      "ELSE SUBSTR(u.last_name, 1, 1) || '.' END) AS author_name";

  @override
  Future<List<Review>> getReviews(int productId) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT r.*, $_authorName, u.avatar_path AS author_avatar_path '
      'FROM ${DatabaseSchema.reviews} r '
      'JOIN ${DatabaseSchema.users} u ON u.id = r.user_id '
      'WHERE r.product_id = ? ORDER BY r.created_at DESC',
      [productId],
    );
    return rows.map(Review.fromMap).toList();
  }

  @override
  Future<Map<int, Review>> getReviewsByUser(int userId) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseSchema.reviews,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return {
      for (final Review review in rows.map(Review.fromMap))
        review.productId: review,
    };
  }

  @override
  Future<bool> hasPurchased(int userId, int productId) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT 1 FROM ${DatabaseSchema.orderItems} oi '
      'JOIN ${DatabaseSchema.orders} o ON o.id = oi.order_id '
      'WHERE o.user_id = ? AND oi.product_id = ? AND o.status = ? LIMIT 1',
      [userId, productId, OrderStatus.delivered.value],
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> saveReview(Review review) async {
    final Database db = await _appDatabase.database;
    await db.transaction((txn) async {
      await txn.delete(
        DatabaseSchema.reviews,
        where: 'user_id = ? AND product_id = ?',
        whereArgs: [review.userId, review.productId],
      );
      await txn.insert(DatabaseSchema.reviews, review.toMap()..remove('id'));
      await _recalculate(txn, review.productId);
    });
  }

  @override
  Future<void> deleteReview(int userId, int productId) async {
    final Database db = await _appDatabase.database;
    await db.transaction((txn) async {
      await txn.delete(
        DatabaseSchema.reviews,
        where: 'user_id = ? AND product_id = ?',
        whereArgs: [userId, productId],
      );
      await _recalculate(txn, productId);
    });
  }

  /// Рейтинг товара = средняя оценка отзывов. Пока отзывов нет,
  /// рейтинг в карточке не меняется.
  Future<void> _recalculate(Transaction txn, int productId) async {
    final List<Map<String, Object?>> rows = await txn.rawQuery(
      'SELECT COUNT(*) AS count, AVG(rating) AS average '
      'FROM ${DatabaseSchema.reviews} WHERE product_id = ?',
      [productId],
    );
    final int count = (rows.first['count'] as int?) ?? 0;
    final double? average = (rows.first['average'] as num?)?.toDouble();
    await txn.update(
      DatabaseSchema.products,
      {
        'reviews_count': count,
        if (average != null) 'rating': (average * 10).round() / 10,
      },
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  static const String _selectQuestions =
      'SELECT q.*, $_authorName, p.name AS product_name '
      'FROM ${DatabaseSchema.questions} q '
      'JOIN ${DatabaseSchema.users} u ON u.id = q.user_id '
      'JOIN ${DatabaseSchema.products} p ON p.id = q.product_id';

  @override
  Future<List<Question>> getQuestions(int productId) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      '$_selectQuestions WHERE q.product_id = ? ORDER BY q.created_at DESC',
      [productId],
    );
    return rows.map(Question.fromMap).toList();
  }

  @override
  Future<List<Question>> getQuestionsForSeller(int sellerId) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      '$_selectQuestions WHERE p.seller_id = ? '
      'ORDER BY (q.answer IS NOT NULL), q.created_at DESC',
      [sellerId],
    );
    return rows.map(Question.fromMap).toList();
  }

  @override
  Future<List<Question>> getAllQuestions() async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      '$_selectQuestions '
      'ORDER BY (q.answer IS NOT NULL), q.created_at DESC',
    );
    return rows.map(Question.fromMap).toList();
  }

  @override
  Future<void> askQuestion(Question question) async {
    final Database db = await _appDatabase.database;
    await db.insert(DatabaseSchema.questions, {
      'product_id': question.productId,
      'user_id': question.userId,
      'text': question.text,
      'created_at': question.createdAt.toIso8601String(),
    });
  }

  @override
  Future<void> answerQuestion(int questionId, String answer) async {
    final Database db = await _appDatabase.database;
    await db.update(
      DatabaseSchema.questions,
      {'answer': answer, 'answered_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [questionId],
    );
  }

  @override
  Future<void> deleteQuestion(int questionId) async {
    final Database db = await _appDatabase.database;
    await db.delete(
      DatabaseSchema.questions,
      where: 'id = ?',
      whereArgs: [questionId],
    );
  }
}
