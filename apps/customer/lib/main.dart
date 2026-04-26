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
import 'src/services/notification_service.dart';
import 'src/services/firebase_push_bootstrap.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════
  //  LAYER 3: Zone-level errors (outermost)
  //  Catches ALL unhandled async/sync Dart exceptions
  // ═══════════════════════════════════════════════════════════════
  runZonedGuarded(() async {
    // Binding MUST be initialized first
    WidgetsFlutterBinding.ensureInitialized();

    // ═══════════════════════════════════════════════════════════
    //  LAYER 1: Flutter framework errors (after binding)
    //  Catches UI errors: layout, render, gestures, build
    // ═══════════════════════════════════════════════════════════
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('');
      debugPrint('╔══════════════════════════════════════════════════════');
      debugPrint('║ 🔴 FLUTTER FRAMEWORK CRASH');
      debugPrint('╠══════════════════════════════════════════════════════');
      debugPrint('║ Exception: ${details.exceptionAsString()}');
      debugPrint('║ Library:   ${details.library}');
      debugPrint('║ Context:   ${details.context?.toDescription() ?? 'неизвестно'}');
      if (details.informationCollector != null) {
        for (final info in details.informationCollector!()) {
          debugPrint('║ Info:      ${info.toDescription()}');
        }
      }
      debugPrint('║ Stack:');
      final lines = details.stack.toString().split('\n');
      for (int i = 0; i < lines.length && i < 20; i++) {
        debugPrint('║   ${lines[i]}');
      }
      debugPrint('╚══════════════════════════════════════════════════════');
      debugPrint('');
    };

    // ═══════════════════════════════════════════════════════════
    //  LAYER 2: Platform dispatcher errors
    //  Catches platform errors (native, codec, channel)
    // ═══════════════════════════════════════════════════════════
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      debugPrint('');
      debugPrint('╔══════════════════════════════════════════════════════');
      debugPrint('║ 🟠 PLATFORM ERROR');
      debugPrint('╠══════════════════════════════════════════════════════');
      debugPrint('║ Error: $error');
      debugPrint('║ Type:  ${error.runtimeType}');
      debugPrint('║ Stack:');
      final lines = stack.toString().split('\n');
      for (int i = 0; i < lines.length && i < 20; i++) {
        debugPrint('║   ${lines[i]}');
      }
      debugPrint('╚══════════════════════════════════════════════════════');
      debugPrint('');
      return true; // handled — don't crash
    };

    // ═══════════════════════════════════════════════════════════
    //  LAYER 4: ErrorWidget.builder — prevents app from dying
    //  on build() errors; shows inline error instead of crash
    // ═══════════════════════════════════════════════════════════
    ErrorWidget.builder = (FlutterErrorDetails details) {
      debugPrint('');
      debugPrint('╔══════════════════════════════════════════════════════');
      debugPrint('║ 🟡 BUILD ERROR (widget crashed)');
      debugPrint('╠══════════════════════════════════════════════════════');
      debugPrint('║ ${details.exceptionAsString()}');
      debugPrint('╚══════════════════════════════════════════════════════');
      debugPrint('');
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
                'Ошибка виджета:\n${details.exceptionAsString().length > 120 ? details.exceptionAsString().substring(0, 120) : details.exceptionAsString()}',
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

    // ─── Initialize Supabase ───
    await Supabase.initialize(
      url: 'https://smvegrscjnoelfsipwqq.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNtdmVncnNjam5vZWxmc2lwd3FxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMxNTU5MjcsImV4cCI6MjA4ODczMTkyN30.z6h0ubNjAC0QfdGgg3FhAfSCy9RVVCupOuQUKuD98ig',
    );

    // ─── Initialize Firebase & Push Notifications ───
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await NotificationService().initialize();
      await FirebasePushBootstrap.initialize();
      debugPrint('[AkJol] Firebase + Push initialized ✅');
    } catch (e) {
      debugPrint('[AkJol] Firebase init error (non-fatal): $e');
    }

    debugPrint('');
    debugPrint('══════════════════════════════════════════════════');
    debugPrint('  ✅ AkJol Customer App — fully initialized');
    debugPrint('══════════════════════════════════════════════════');
    debugPrint('');

    runApp(const ProviderScope(child: AkJolCustomerApp()));
  }, (Object error, StackTrace stack) {
    debugPrint('');
    debugPrint('╔══════════════════════════════════════════════════════');
    debugPrint('║ 🔴 UNHANDLED DART EXCEPTION');
    debugPrint('╠══════════════════════════════════════════════════════');
    debugPrint('║ Error: $error');
    debugPrint('║ Type:  ${error.runtimeType}');
    debugPrint('║ Stack:');
    final lines = stack.toString().split('\n');
    for (int i = 0; i < lines.length && i < 25; i++) {
      debugPrint('║   ${lines[i]}');
    }
    debugPrint('╚══════════════════════════════════════════════════════');
    debugPrint('');
  });
}

class AkJolCustomerApp extends ConsumerWidget {
  const AkJolCustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'AkJol',
      debugShowCheckedModeBanner: false,
      theme: AkJolTheme.lightTheme,
      darkTheme: AkJolTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: (context, child) {
        return ScrollConfiguration(
          behavior: const _NoScrollbarBehavior(),
          child: child!,
        );
      },
    );
  }
}

class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}
