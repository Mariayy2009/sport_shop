import 'package:sqflite/sqflite.dart';

import '../../../models/enums.dart';
import '../../../models/product.dart';
import '../../../models/recommendation_items.dart';
import '../../database/app_database.dart';
import '../../database/database_schema.dart';

/// SQL-запросы к таблицам sport_requirements и recommendations.
class RecommendationLocalDataSource {
  RecommendationLocalDataSource(this._appDatabase);

  final AppDatabase _appDatabase;

  static const String _productColumns =
      'p.*, c.name AS category_name, s.name AS sport_name';
  static const String _productJoins =
      'JOIN ${DatabaseSchema.products} p ON p.id = r.product_id '
      'JOIN ${DatabaseSchema.categories} c ON c.id = p.category_id '
      'JOIN ${DatabaseSchema.sports} s ON s.id = p.sport_id';

  /// Товары, нужные для вида спорта и уровня. Сначала обязательные.
  Future<List<RequirementItem>> getRequirements(
    int sportId,
    SportLevel level,
  ) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT $_productColumns, r.is_mandatory AS is_mandatory '
      'FROM ${DatabaseSchema.sportRequirements} r $_productJoins '
      'WHERE r.sport_id = ? AND r.level = ? '
      'ORDER BY r.is_mandatory DESC, p.price ASC',
      [sportId, level.value],
    );
    return rows
        .map((row) => (
              product: Product.fromMap(row),
              isMandatory: row['is_mandatory'] == 1,
            ))
        .toList();
  }

  /// Рекомендации «Что ещё купить?» для указанного стажа.
  Future<List<ExperienceItem>> getExperienceRecommendations(
    int sportId,
    int experienceYears,
  ) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT $_productColumns, r.reason AS reason, '
      'r.min_experience AS min_experience '
      'FROM ${DatabaseSchema.recommendations} r $_productJoins '
      'WHERE r.sport_id = ? AND r.min_experience <= ? '
      'ORDER BY r.min_experience DESC, p.price ASC',
      [sportId, experienceYears],
    );
    return rows
        .map((row) => (
              product: Product.fromMap(row),
              reason: (row['reason'] as String?) ?? 'Подходит для вашего стажа',
              minExperience: (row['min_experience'] as int?) ?? 0,
            ))
        .toList();
  }
}
