import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'firebase_options.dart';
import 'src/routing/app_router.dart';
import 'src/services/firebase_push_bootstrap.dart';
import 'src/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('ru', null);

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL',
        defaultValue: 'https://smvegrscjnoelfsipwqq.supabase.co'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY',
        defaultValue:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNtdmVncnNjam5vZWxmc2lwd3FxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzE1NTkyNywiZXhwIjoyMDg4NzMxOTI3fQ.A7OpKWshMrtBWGd7LAYCQR2zP2L9lxL_tfP1uf35YIU'),
  );

  // Initialize Firebase & Push Notifications
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await NotificationService().initialize();
    await FirebasePushBootstrap.initialize();
    debugPrint('[Admin] Firebase + Push initialized ✅');
  } catch (e) {
    debugPrint('[Admin] Firebase init error (non-fatal): $e');
  }

  runApp(const ProviderScope(child: TakEsepAdminApp()));
}

class TakEsepAdminApp extends ConsumerWidget {
  const TakEsepAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(adminRouterProvider);

    return MaterialApp.router(
      title: 'TakEsep Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
