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
  WidgetsFlutterBinding.ensureInitialized();

  // Catch ALL errors and show them on screen
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _showErrorOnScreen(details.exceptionAsString(), details.stack?.toString());
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    _showErrorOnScreen('$error', stack.toString());
    return true;
  };

  runZonedGuarded(() async {
    try {
      await _bootstrapApp();
    } catch (e, st) {
      debugPrint('[TakEsep] FATAL BOOT ERROR: $e\n$st');
      _showErrorOnScreen('BOOT ERROR: $e', st.toString());
    }
  }, (error, stack) {
    debugPrint('[TakEsep] UNHANDLED: $error\n$stack');
    _showErrorOnScreen('UNHANDLED: $error', stack.toString());
  });
}

Future<void> _bootstrapApp() async {
  // ─── Initialize Supabase ───
  try {
    await Supabase.initialize(
      url: const String.fromEnvironment('SUPABASE_URL',
          defaultValue: 'https://smvegrscjnoelfsipwqq.supabase.co'),
      anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY',
          defaultValue:
              'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNtdmVncnNjam5vZWxmc2lwd3FxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMxNTU5MjcsImV4cCI6MjA4ODczMTkyN30.z6h0ubNjAC0QfdGgg3FhAfSCy9RVVCupOuQUKuD98ig'),
    );
    debugPrint('[TakEsep] Supabase initialized ✅');
  } catch (e, st) {
    debugPrint('[TakEsep] Supabase init FAILED: $e');
    _showErrorOnScreen('Supabase init failed: $e', st.toString());
    return;
  }

  // Initialize PowerSync offline-first database
  try {
    await initPowerSync();
    debugPrint('[TakEsep] PowerSync initialized ✅');
  } catch (e, st) {
    debugPrint('[TakEsep] PowerSync init FAILED: $e');
    _showErrorOnScreen('PowerSync init failed: $e', st.toString());
    return;
  }

  // Initialize Firebase & Push Notifications
  bool firebaseOk = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    firebaseOk = true;
    debugPrint('[TakEsep] Firebase initialized ✅');
  } catch (e, st) {
    debugPrint('[TakEsep] Firebase init FAILED: $e');
    // Firebase is optional — continue without it
  }

  if (firebaseOk) {
    try {
      await NotificationService().initialize();
      await FirebasePushBootstrap.initialize();
      debugPrint('[TakEsep] Push notifications initialized ✅');
    } catch (e, st) {
      debugPrint('[TakEsep] Push init FAILED (non-fatal): $e');
    }
  }

  final prefs = await SharedPreferences.getInstance();

  debugPrint('[TakEsep] Warehouse app — fully initialized ✅');

  runApp(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: const TakEsepWarehouseApp(),
  ));
}

void _showErrorOnScreen(String message, String? stack) {
  debugPrint('═══════════════════════════════════════');
  debugPrint('🔴 ERROR: $message');
  if (stack != null)
    debugPrint(
        'Stack: ${stack.substring(0, stack.length > 500 ? 500 : stack.length)}');
  debugPrint('═══════════════════════════════════════');

  try {
    runApp(_ErrorApp(message: message, stack: stack));
  } catch (e) {
    debugPrint('[TakEsep] Even error screen failed: $e');
  }
}

class _ErrorApp extends StatelessWidget {
  final String message;
  final String? stack;
  const _ErrorApp({required this.message, this.stack});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                const Text('TakEsep — Ошибка',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: SelectableText(
                    message,
                    style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                        fontFamily: 'monospace'),
                  ),
                ),
                if (stack != null) ...[
                  const SizedBox(height: 16),
                  const Text('Stack trace:',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      stack!.length > 2000 ? stack!.substring(0, 2000) : stack!,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
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
