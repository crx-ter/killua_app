import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:appflowy_editor/appflowy_editor.dart';

import 'features/login/login_screen.dart';
import 'services/theme_config_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  FlutterError.onError = (details) {
    final error = details.exception;
    final stack = details.stack ?? '';
    debugPrint('FlutterError: $error\n$stack');
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Algo salió mal.\n${details.exception}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
      ),
    );
  };

  final themeConfig = ThemeConfigService();
  await themeConfig.init();

  runApp(
    ChangeNotifierProvider.value(value: themeConfig, child: const KilluaApp()),
  );
}

class KilluaApp extends StatelessWidget {
  const KilluaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Solo escucha cambios en textColor (no en fontSizeDelta, que se aplica
    // via MediaQuery más abajo para evitar reconstruir el árbol completo)
    final textColor = context.select<ThemeConfigService, Color>(
      (s) => s.currentTextColor,
    );
    final highContrast = context.select<ThemeConfigService, bool>(
      (s) => s.highContrastLines,
    );

    final baseTheme = ThemeData.dark();

    // Apply contrast weight and color
    TextTheme customTextTheme = baseTheme.textTheme.apply(
      bodyColor: textColor,
      displayColor: textColor,
    );

    if (highContrast) {
      customTextTheme = customTextTheme.copyWith(
        bodyMedium: customTextTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: customTextTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        bodySmall: customTextTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        titleMedium: customTextTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleLarge: customTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        labelLarge: customTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return MaterialApp(
      title: 'Killua',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        scaffoldBackgroundColor: Colors.black,
        textTheme: customTextTheme,
        iconTheme: baseTheme.iconTheme.copyWith(color: textColor),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        AppFlowyEditorLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es'), Locale('en')],
      builder: (context, child) {
        final fontSizeDelta = context.select<ThemeConfigService, double>(
          (s) => s.fontSizeDelta,
        );
        final scale = 1.0 + (fontSizeDelta / 14.0);

        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox(),
        );
      },
      home: const LoginScreen(),
    );
  }
}
