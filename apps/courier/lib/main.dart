import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'src/theme/akjol_theme.dart';
import 'src/routing/app_router.dart';
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
      return true;
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
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
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

    // Supabase
    await Supabase.initialize(
      url: 'https://smvegrscjnoelfsipwqq.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNtdmVncnNjam5vZWxmc2lwd3FxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMxNTU5MjcsImV4cCI6MjA4ODczMTkyN30.z6h0ubNjAC0QfdGgg3FhAfSCy9RVVCupOuQUKuD98ig',
    );

    // Firebase + Notifications
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      // Initialize local notification channels
      await NotificationService().initialize();
      // Push Notifications
      await FirebasePushBootstrap.initialize();
    } catch (e) {
      debugPrint('⚠️ Firebase init skipped: $e');
    }

    debugPrint('[AkJol Pro] App initialized — crash handlers ACTIVE');

    runApp(const ProviderScope(child: AkJolCourierApp()));
  }, (Object error, StackTrace stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

class AkJolCourierApp extends ConsumerWidget {
  const AkJolCourierApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'AkJol Pro',
      debugShowCheckedModeBanner: false,
      theme: AkJolTheme.lightTheme,
      darkTheme: AkJolTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
