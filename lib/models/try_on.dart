import 'product.dart';

/// Категория вещи для примерки по фотографии — так её понимает модель.
enum TryOnCategory {
  tops('tops', 'верх'),
  bottoms('bottoms', 'низ'),
  onePieces('one-pieces', 'комплект');

  const TryOnCategory(this.apiValue, this.label);

  /// Значение, которое уходит на сервер примерки.
  final String apiValue;
  final String label;
}

/// 3D-модель одежды для живой примерки (файл assets/models/имя.glb).
enum GarmentShape {
  tshirt('tshirt'),
  jersey('jersey'),
  longSleeve('long_sleeve'),
  shorts('shorts'),
  pants('pants');

  const GarmentShape(this.fileName);

  final String fileName;

  String get assetPath => 'assets/models/$fileName.glb';
}

/// Что можно сделать с товаром в примерочной.
class TryOnSupport {
  const TryOnSupport({this.category, this.shape, this.reason});

  /// null — примерка по фото для товара недоступна.
  final TryOnCategory? category;

  /// null — живая примерка для товара недоступна.
  final GarmentShape? shape;

  /// Объяснение для пользователя, если что-то недоступно.
  final String? reason;

  bool get photo => category != null;
  bool get live => shape != null;
  bool get any => photo || live;

  /// Правила по категории и названию товара.
  ///
  /// Примеряется одежда: футболки, форма, костюмы, шорты, штаны.
  /// Обувь, защита, инвентарь и аксессуары не примеряются: модель
  /// по фото обучена на одежде, а для живой примерки у них нет 3D-модели.
  static TryOnSupport of(Product product) {
    final String name = product.name.toLowerCase();
    bool has(String part) => name.contains(part);

    if (product.categoryName == 'Обувь') {
      return const TryOnSupport(
        reason: 'Обувь пока нельзя примерить: примерка работает с одеждой. '
            'Размер поможет выбрать подсказка в карточке товара.',
      );
    }
    if (has('костюм') || has('комбинезон')) {
      return const TryOnSupport(
        category: TryOnCategory.onePieces,
        shape: GarmentShape.longSleeve,
      );
    }
    if (has('кимоно')) {
      return const TryOnSupport(
        category: TryOnCategory.tops,
        shape: GarmentShape.longSleeve,
      );
    }
    if (has('купальник')) {
      return const TryOnSupport(
        category: TryOnCategory.onePieces,
        reason: 'Для купальника доступна только примерка по фотографии.',
      );
    }
    if (has('форма') || has('майка')) {
      // Игровая форма: на фото и в камере примеряется майка.
      return const TryOnSupport(
        category: TryOnCategory.tops,
        shape: GarmentShape.jersey,
      );
    }
    if (has('футболк') || has('лонгслив') || has('толстовк') || has('худи')) {
      return TryOnSupport(
        category: TryOnCategory.tops,
        shape: has('футболк') ? GarmentShape.tshirt : GarmentShape.longSleeve,
      );
    }
    if (has('шорты')) {
      return const TryOnSupport(
        category: TryOnCategory.bottoms,
        shape: GarmentShape.shorts,
      );
    }
    if (has('штаны') || has('брюки') || has('тайтс') || has('леггинс')) {
      return const TryOnSupport(
        category: TryOnCategory.bottoms,
        shape: GarmentShape.pants,
      );
    }
    return TryOnSupport(
      reason: '«${product.categoryName ?? 'Этот товар'}» не примеряется: '
          'примерка доступна для футболок, формы, костюмов, шорт и штанов.',
    );
  }
}

/// Состояние сервера примерки на ноутбуке.
class TryOnServerStatus {
  const TryOnServerStatus({
    required this.reachable,
    this.modelReady = false,
    this.device,
    this.secondsPerStep,
    this.defaultSteps,
    this.message,
    this.warnings = const [],
  });

  /// Сервер ответил.
  final bool reachable;

  /// Модель загружена в память и готова генерировать.
  final bool modelReady;

  /// На чём идут вычисления: «cpu», «cuda».
  final String? device;

  /// Измеренное время одного шага генерации — для оценки ожидания.
  final double? secondsPerStep;

  /// Сколько шагов генерации делает сервер по умолчанию.
  final int? defaultSteps;

  /// Ожидаемое время примерки в секундах (если сервер уже что-то считал).
  double? get expectedSeconds => secondsPerStep == null || defaultSteps == null
      ? null
      : secondsPerStep! * defaultSteps!;

  /// Пояснение, если что-то не так.
  final String? message;

  /// Что замедлит примерку на ноутбуке: мало памяти, работа от батареи.
  final List<String> warnings;

  factory TryOnServerStatus.fromJson(Map<String, Object?> json) {
    return TryOnServerStatus(
      reachable: true,
      modelReady: json['model_ready'] == true,
      device: json['device'] as String?,
      secondsPerStep: (json['seconds_per_step'] as num?)?.toDouble(),
      defaultSteps: (json['default_steps'] as num?)?.toInt(),
      message: json['message'] as String?,
      warnings: _strings(json['warnings']),
    );
  }
}

List<String> _strings(Object? value) => value is List
    ? [for (final Object? item in value) if (item is String) item]
    : const [];

/// Ход генерации на сервере.
enum TryOnJobState {
  queued,
  running,
  done,
  failed;

  static TryOnJobState fromValue(String? value) => TryOnJobState.values
      .firstWhere((state) => state.name == value, orElse: () => failed);
}

class TryOnJobStatus {
  const TryOnJobStatus({
    required this.state,
    this.step = 0,
    this.totalSteps = 0,
    this.stage,
    this.etaSeconds,
    this.error,
    this.warnings = const [],
  });

  final TryOnJobState state;
  final int step;
  final int totalSteps;

  /// Что сервер делает сейчас: «Подготовка фото», «Генерация».
  final String? stage;
  final double? etaSeconds;
  final String? error;

  /// Что сейчас замедляет генерацию на ноутбуке.
  final List<String> warnings;

  double get progress => totalSteps == 0 ? 0 : (step / totalSteps).clamp(0, 1);

  factory TryOnJobStatus.fromJson(Map<String, Object?> json) {
    return TryOnJobStatus(
      state: TryOnJobState.fromValue(json['state'] as String?),
      step: (json['step'] as num?)?.toInt() ?? 0,
      totalSteps: (json['total_steps'] as num?)?.toInt() ?? 0,
      stage: json['stage'] as String?,
      etaSeconds: (json['eta_seconds'] as num?)?.toDouble(),
      error: json['error'] as String?,
      warnings: _strings(json['warnings']),
    );
  }
}

/// Сохранённый результат примерки (файл в папке приложения).
class TryOnResult {
  const TryOnResult({
    required this.path,
    required this.productId,
    required this.createdAt,
  });

  final String path;
  final int productId;
  final DateTime createdAt;
}
