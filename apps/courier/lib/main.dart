import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'src/theme/akjol_theme.dart';
import 'src/routing/app_router.dart';
import 'src/services/firebase_push_bootstrap.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Catch Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('[AkJol Go] Flutter error: ${details.exceptionAsString()}');
    };

    // Catch platform errors
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      debugPrint('[AkJol Go] Platform error: $error');
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

    // Firebase (skip on web if not configured)
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // Push Notifications
      await FirebasePushBootstrap.initialize();
    } catch (e) {
      debugPrint('⚠️ Firebase init skipped: $e');
    }

    debugPrint('[AkJol Go] App initialized — crash handlers ACTIVE');

    runApp(const ProviderScope(child: AkJolCourierApp()));
  }, (Object error, StackTrace stack) {
    debugPrint('[AkJol Go] Unhandled exception: $error');
  });
}

class AkJolCourierApp extends ConsumerWidget {
  const AkJolCourierApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'AkJol Go',
      debugShowCheckedModeBanner: false,
      theme: AkJolTheme.lightTheme,
      darkTheme: AkJolTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
