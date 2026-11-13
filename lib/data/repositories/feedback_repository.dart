import '../../models/question.dart';
import '../../models/review.dart';

/// Контракт работы с отзывами и вопросами о товарах.
abstract class FeedbackRepository {
  Future<List<Review>> getReviews(int productId);

  /// Отзывы пользователя: id товара → отзыв.
  Future<Map<int, Review>> getReviewsByUser(int userId);

  /// Пользователь получил этот товар (есть доставленный заказ).
  Future<bool> hasPurchased(int userId, int productId);

  /// Сохраняет отзыв (повторный заменяет прежний) и пересчитывает
  /// рейтинг товара как среднюю оценку.
  Future<void> saveReview(Review review);

  Future<void> deleteReview(int userId, int productId);

  Future<List<Question>> getQuestions(int productId);

  /// Все вопросы для администратора: сначала без ответа.
  Future<List<Question>> getAllQuestions();

  Future<void> askQuestion(Question question);

  Future<void> answerQuestion(int questionId, String answer);

  Future<void> deleteQuestion(int questionId);
}
