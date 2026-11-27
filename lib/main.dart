import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import 'core/platform_services.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    PlatformServices.logToPlatform(details.toString());
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    PlatformServices.logToPlatform('Uncaught: $error\n$stack');
    return true;
  };
  runApp(const FeiNiaoApp());
}

class FeiNiaoApp extends StatelessWidget {
  const FeiNiaoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'V2Board-Subscription-Inspector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false,
        primaryColor: AppColors.blue,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: AppSwatch.primary,
        ).copyWith(background: AppColors.background),
      ),
      home: const HomePage(),
    );
  }
}
