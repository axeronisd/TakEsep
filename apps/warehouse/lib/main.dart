import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'src/routing/app_router.dart';
import 'src/providers/theme_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'src/providers/auth_providers.dart';
import 'src/data/powersync_db.dart';
import 'src/services/firebase_push_bootstrap.dart';
import 'src/services/notification_service.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Catch Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      FirebaseCrashlytics.instance.recordError(
        details.exception,
        details.stack,
        reason: details.context?.toString(),
        fatal: true,
      );
    };

    // Catch platform errors
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true; // handled
    };

    // Show inline error widget instead of crash
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.red, size: 32),
              const SizedBox(height: 8),
              Text(
                'Ошибка: ${details.exceptionAsString().length > 100 ? details.exceptionAsString().substring(0, 100) : details.exceptionAsString()}',
                style: const TextStyle(color: Colors.red, fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    };

    await Supabase.initialize(
      url: const String.fromEnvironment('SUPABASE_URL',
          defaultValue: 'https://smvegrscjnoelfsipwqq.supabase.co'),
      anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY',
          defaultValue:
              'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNtdmVncnNjam5vZWxmc2lwd3FxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMxNTU5MjcsImV4cCI6MjA4ODczMTkyN30.z6h0ubNjAC0QfdGgg3FhAfSCy9RVVCupOuQUKuD98ig'),
    );

    // Initialize PowerSync offline-first database
    try {
      await initPowerSync();
    } catch (e) {
      debugPrint('[TakEsep] PowerSync init error (non-fatal): $e');
    }

    // Initialize Firebase & Push Notifications
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // Enable Crashlytics collection
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      await NotificationService().initialize();
      await FirebasePushBootstrap.initialize();
      debugPrint('[TakEsep] Firebase + Push + Crashlytics initialized ✅');
    } catch (e) {
      debugPrint('[TakEsep] Firebase init error (non-fatal): $e');
    }

    final prefs = await SharedPreferences.getInstance();

    debugPrint('[TakEsep] Warehouse app initialized — crash handlers ACTIVE');

    runApp(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const TakEsepWarehouseApp(),
    ));
  }, (Object error, StackTrace stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

class TakEsepWarehouseApp extends ConsumerWidget {
  const TakEsepWarehouseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'TakEsep Склад',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      locale: const Locale('ru', 'RU'),
      supportedLocales: const [Locale('ru', 'RU')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
