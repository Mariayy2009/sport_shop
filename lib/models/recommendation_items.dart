import 'product.dart';

/// Товар из sport_requirements с признаком обязательности.
typedef RequirementItem = ({Product product, bool isMandatory});

/// Товар из recommendations с причиной и минимальным стажем.
typedef ExperienceItem = ({Product product, String reason, int minExperience});
