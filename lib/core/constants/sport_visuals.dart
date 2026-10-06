import 'package:flutter/material.dart';

/// Оформление вида спорта: иконка, картинка плитки на главной
/// и форма названия для заголовка «Твоя экипировка для волейбола».
class SportVisual {
  const SportVisual({
    required this.icon,
    required this.assetKey,
    required this.genitive,
  });

  final IconData icon;
  final String assetKey;
  final String genitive;

  /// Картинка плитки: assets/images/sports/<ключ>.png
  String get imagePath => 'assets/images/sports/$assetKey.png';
}

class SportVisuals {
  SportVisuals._();

  static const Map<String, SportVisual> _byName = {
    'Волейбол': SportVisual(
        icon: Icons.sports_volleyball, assetKey: 'volleyball', genitive: 'волейбола'),
    'Бег': SportVisual(
        icon: Icons.directions_run, assetKey: 'running', genitive: 'бега'),
    'Футбол': SportVisual(
        icon: Icons.sports_soccer, assetKey: 'football', genitive: 'футбола'),
    'Плавание': SportVisual(
        icon: Icons.pool, assetKey: 'swimming', genitive: 'плавания'),
    'Бокс': SportVisual(
        icon: Icons.sports_mma, assetKey: 'boxing', genitive: 'бокса'),
    'Карате': SportVisual(
        icon: Icons.sports_martial_arts, assetKey: 'karate', genitive: 'карате'),
    'Баскетбол': SportVisual(
        icon: Icons.sports_basketball, assetKey: 'basketball', genitive: 'баскетбола'),
    'Йога': SportVisual(
        icon: Icons.self_improvement, assetKey: 'yoga', genitive: 'йоги'),
    'Фитнес': SportVisual(
        icon: Icons.fitness_center, assetKey: 'fitness', genitive: 'фитнеса'),
  };

  static const SportVisual _fallback =
      SportVisual(icon: Icons.sports, assetKey: 'default', genitive: 'спорта');

  static SportVisual of(String? sportName) =>
      _byName[sportName] ?? _fallback;
}
