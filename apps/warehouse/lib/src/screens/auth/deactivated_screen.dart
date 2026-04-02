import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';

import '../../providers/auth_providers.dart';

/// Полноэкранное уведомление при деактивации ключа.
/// Блокирует ВСЕ функции TakEsep.
/// Показывает сообщение от админа.
class DeactivatedScreen extends ConsumerWidget {
  const DeactivatedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final message = authState.deactivationMessage ??
        'Ваш аккаунт был деактивирован.\nСвяжитесь с администрацией AkJol.';
    final companyName = authState.currentCompany?.title ?? 'Компания';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.shade50,
                  ),
                  child: Icon(
                    Icons.block_rounded,
                    size: 54,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  'TakEsep деактивирован',
                  style: AppTypography.headlineMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.red.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  companyName,
                  style: AppTypography.bodyLarge.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 32),

                // Admin message
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.shade50,
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.message_rounded,
                              size: 18, color: Colors.red.shade300),
                          const SizedBox(width: 8),
                          Text(
                            'Сообщение от администрации',
                            style: AppTypography.labelMedium.copyWith(
                              color: Colors.red.shade400,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        message,
                        style: AppTypography.bodyLarge.copyWith(
                          color: Colors.grey.shade800,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Retry button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ref.read(authProvider.notifier).recheckLicense();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Проверить снова'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Logout button
                TextButton(
                  onPressed: () {
                    ref.read(authProvider.notifier).logout();
                  },
                  child: Text(
                    'Выйти и ввести другой ключ',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),

                const SizedBox(height: 24),
                Text(
                  'Обратитесь в поддержку: support@akjol.kg',
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
