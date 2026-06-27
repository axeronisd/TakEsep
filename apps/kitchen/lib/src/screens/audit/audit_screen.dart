import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:takesep_design_system/takesep_design_system.dart';

import '../../providers/audit_providers.dart';
import '../../providers/auth_providers.dart';
import '../../utils/snackbar_helper.dart';
import 'widgets/audit_count_pane.dart';

/// Audit (Ревизия) screen — simplified: start new or continue draft.
class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final currentAudit = ref.watch(currentAuditProvider);

    // If an audit is active, show the counting screen
    if (currentAudit != null) {
      return AuditCountPane(audit: currentAudit);
    }

    final draftsAsync = ref.watch(auditDraftsProvider);
    final pad = isMobile ? AppSpacing.md : AppSpacing.xxl;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ревизия',
                  style: (isMobile
                          ? AppTypography.headlineMedium
                          : AppTypography.displaySmall)
                      .copyWith(
                          color: cs.onSurface, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.xs),
              Text('Инвентаризация и сверка остатков',
                  style: AppTypography.bodyMedium.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5))),

              // Center content
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fact_check_rounded,
                            size: isMobile ? 56 : 72,
                            color: AppColors.primary.withValues(alpha: 0.25)),
                        const SizedBox(height: AppSpacing.xl),
                        Text('Пересчёт всех товаров\nна текущем складе',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyLarge.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.6))),
                        const SizedBox(height: AppSpacing.xxl),

                        // ── Start new ──
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () => _startAudit(ref, context),
                            icon: const Icon(Icons.play_arrow_rounded, size: 22),
                            label: const Text('Начать новую ревизию',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                            ),
                          ),
                        ),

                        // ── Continue draft (if exists) ──
                        draftsAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (drafts) {
                            if (drafts.isEmpty) return const SizedBox.shrink();
                            final draft = drafts.first;
                            final dateStr =
                                '${draft.createdAt.day.toString().padLeft(2, '0')}.'
                                '${draft.createdAt.month.toString().padLeft(2, '0')}.'
                                '${draft.createdAt.year}';
                            final pct = (draft.progress * 100).toInt();
                            return Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.md),
                              child: SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    await ref
                                        .read(currentAuditProvider.notifier)
                                        .loadAudit(draft.id);
                                  },
                                  icon: const Icon(Icons.history_rounded, size: 20),
                                  label: Text(
                                    'Продолжить ($dateStr · $pct%)',
                                    style: const TextStyle(
                                        fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.warning,
                                    side: const BorderSide(color: AppColors.warning),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(AppSpacing.radiusMd)),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Можно пропустить отдельные позиции —\nнепроверенные товары не изменятся',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySmall.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.35)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startAudit(WidgetRef ref, BuildContext ctx) async {
    final ok = await ref.read(currentAuditProvider.notifier).startAudit(
          type: AuditType.full,
        );
    if (!ok && ctx.mounted) {
      final auth = ref.read(authProvider);
      String msg = 'Не удалось начать ревизию';
      if (auth.currentCompany == null) {
        msg += ': компания не определена';
      } else if (auth.selectedWarehouseId == null) {
        msg += ': склад не выбран';
      }
      showErrorSnackBar(ctx, msg);
    }
  }
}
