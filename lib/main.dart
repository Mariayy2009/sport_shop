import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/constants/app_strings.dart';
import 'core/routes/app_router.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Макеты Figma только портретные
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // На этапе 3 здесь появится инициализация SQLite,
  // на этапе 11 — подключение Provider-состояний.
  runApp(const SportShopApp());
}

class SportShopApp extends StatelessWidget {
  const SportShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: AppRoutes.main,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
