import 'package:flutter/foundation.dart';

import '../models/enums.dart';
import '../models/recommendation_request.dart';
import '../models/recommended_product.dart';
import '../models/user_sizes.dart';
import '../services/recommendation_service.dart';

/// Ответы опроса AI-подбора и полученные рекомендации.
class RecommendationState extends ChangeNotifier {
  RecommendationState(this._service);

  final RecommendationService _service;

  static const double minBudget = 10000;
  static const double maxBudget = 200000;
  static const double budgetStep = 5000;
  static const double defaultBudget = 60000;

  // Ответы опроса
  int? sportId;
  SportLevel? level;
  int? experienceYears;
  int? height;
  int? weight;
  String? clothingSize;
  int? shoeSize;
  double budget = defaultBudget;

  List<RecommendedProduct> _results = [];
  bool _isLoading = false;
  String? _error;
  RecommendationRequest? _lastRequest;

  List<RecommendedProduct> get results => _results;
  List<RecommendedProduct> get mandatory =>
      _results.where((item) => item.isMandatory).toList();
  List<RecommendedProduct> get optional =>
      _results.where((item) => !item.isMandatory).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasResults => _results.isNotEmpty;
  RecommendationRequest? get lastRequest => _lastRequest;

  double get totalPrice => RecommendationService.totalPrice(_results);
  double get mandatoryTotal => RecommendationService.totalPrice(mandatory);

  /// Начало опроса: ответы заполняются из профиля, если он есть.
  void startQuiz(UserSizes? sizes) {
    sportId = sizes?.sportId;
    experienceYears = sizes?.experienceYears;
    level = experienceYears == null
        ? null
        : SportLevel.fromExperience(experienceYears!);
    height = sizes?.height;
    weight = sizes?.weight;
    clothingSize = sizes?.clothingSize;
    shoeSize = sizes?.shoeSize;
    budget = defaultBudget;
    notifyListeners();
  }

  void selectSport(int id) {
    sportId = id;
    notifyListeners();
  }

  void selectLevel(SportLevel value) {
    level = value;
    notifyListeners();
  }

  void setBudget(double value) {
    budget = value;
    notifyListeners();
  }

  void setExperience(int? years) {
    experienceYears = years;
    notifyListeners();
  }

  void setParameters({
    required int height,
    required int weight,
    required String clothingSize,
    required int shoeSize,
  }) {
    this.height = height;
    this.weight = weight;
    this.clothingSize = clothingSize;
    this.shoeSize = shoeSize;
    notifyListeners();
  }

  /// Ответы опроса в виде запроса к RecommendationService.
  RecommendationRequest buildRequest() {
    return RecommendationRequest(
      sportId: sportId!,
      level: level ?? SportLevel.fromExperience(experienceYears ?? 0),
      experienceYears: experienceYears ?? 0,
      height: height,
      weight: weight,
      clothingSize: clothingSize,
      shoeSize: shoeSize,
      budget: budget,
    );
  }

  Future<void> loadRecommendations() async {
    final RecommendationRequest request = buildRequest();
    _lastRequest = request;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _results = await _service.getRecommendations(request);
    } catch (error) {
      debugPrint('Ошибка подбора: $error');
      _results = [];
      _error = 'Не удалось подобрать экипировку. Попробуйте ещё раз';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
