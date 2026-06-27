import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/service_request_providers.dart';


/// ═══════════════════════════════════════════════════════════════
/// Service Requests Tab — заявки на услуги из Ак Жол
///
/// Бизнес видит входящие заявки от клиентов,
/// может принять, отклонить, выполнить.
/// ═══════════════════════════════════════════════════════════════

class ServiceRequestsTab extends ConsumerWidget {
  const ServiceRequestsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(serviceRequestsProvider);
    final cs = Theme.of(context).colorScheme;

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Ошибка: $e')),
      data: (requests) {
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.inbox_rounded,
                      size: 48, color: AppColors.secondary.withValues(alpha: 0.5)),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Нет заявок',
                    style: AppTypography.headlineSmall.copyWith(color: cs.onSurface)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Когда клиенты закажут вашу услугу\nв Ак Жол — заявка появится здесь',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5)),
                ),
              ],
            ),
          );
        }

        // Split into active and completed
        final active = requests.where((r) => r.isActive).toList();
        final completed = requests.where((r) => !r.isActive).toList();

        return RefreshIndicator(
          onRefresh: () => ref.read(serviceRequestsProvider.notifier).load(),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              // Active
              if (active.isNotEmpty) ...[
                Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Активные (${active.length})',
                        style: AppTypography.bodyLarge.copyWith(
                            color: cs.onSurface, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ...active.map((r) => _RequestCard(
                      request: r,
                      onAccept: () => ref
                          .read(serviceRequestsProvider.notifier)
                          .updateStatus(r.id, 'accepted'),
                      onStart: () => ref
                          .read(serviceRequestsProvider.notifier)
                          .updateStatus(r.id, 'in_progress'),
                      onComplete: () => _showCompleteDialog(context, ref, r),
                      onCancel: () => ref
                          .read(serviceRequestsProvider.notifier)
                          .updateStatus(r.id, 'cancelled'),
                    )),
                const SizedBox(height: AppSpacing.xl),
              ],

              // Completed
              if (completed.isNotEmpty) ...[
                Text('Завершённые (${completed.length})',
                    style: AppTypography.bodyLarge.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.5))),
                const SizedBox(height: AppSpacing.sm),
                ...completed.map((r) => _RequestCard(request: r)),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showCompleteDialog(BuildContext context, WidgetRef ref, ServiceRequest request) {
    final priceCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Завершить заявку'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Итоговая цена (опционально)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Заметки'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(serviceRequestsProvider.notifier).complete(
                    request.id,
                    priceFinal: double.tryParse(priceCtrl.text),
                    notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
                  );
            },
            child: const Text('Завершить'),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final ServiceRequest request;
  final VoidCallback? onAccept;
  final VoidCallback? onStart;
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;

  const _RequestCard({
    required this.request,
    this.onAccept,
    this.onStart,
    this.onComplete,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: request.isActive
              ? _statusColor(request.status).withValues(alpha: 0.3)
              : cs.outline.withValues(alpha: 0.15),
          width: request.isActive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: service name + status
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _statusColor(request.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _statusIcon(request.status),
                    color: _statusColor(request.status),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.serviceName,
                          style: AppTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600, color: cs.onSurface)),
                      Text(
                        _formatDate(request.createdAt),
                        style: AppTypography.bodySmall.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(request.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    request.statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _statusColor(request.status),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Address
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 14,
                    color: cs.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(request.address,
                      style: AppTypography.bodySmall.copyWith(color: cs.onSurface),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),

            // Description
            if (request.description != null && request.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(request.description!,
                  style: AppTypography.bodySmall.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.6)),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],

            // Phone
            if (request.customerPhone != null && request.customerPhone!.isNotEmpty) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  try {
                    launchUrl(Uri.parse('tel:${request.customerPhone}'));
                  } catch (_) {}
                },
                child: Row(
                  children: [
                    Icon(Icons.phone_outlined, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(request.customerPhone!,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ],
                ),
              ),
            ],

            // Actions
            if (request.isActive) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onCancel != null)
                    TextButton(
                      onPressed: onCancel,
                      child: Text('Отменить',
                          style: TextStyle(color: cs.error, fontSize: 13)),
                    ),
                  const Spacer(),
                  if (request.status == 'pending' && onAccept != null)
                    FilledButton.tonal(
                      onPressed: onAccept,
                      child: const Text('Принять'),
                    ),
                  if (request.status == 'accepted' && onStart != null)
                    FilledButton(
                      onPressed: onStart,
                      child: const Text('Начать'),
                    ),
                  if (request.status == 'in_progress' && onComplete != null)
                    FilledButton(
                      onPressed: onComplete,
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary),
                      child: const Text('Завершить',
                          style: TextStyle(color: Colors.white)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'accepted': return Colors.blue;
      case 'in_progress': return Colors.purple;
      case 'completed': return AppColors.primary;
      case 'cancelled': return AppColors.error;
      default: return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending': return Icons.schedule;
      case 'accepted': return Icons.check_circle_outline;
      case 'in_progress': return Icons.engineering;
      case 'completed': return Icons.check_circle;
      case 'cancelled': return Icons.cancel;
      default: return Icons.help_outline;
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
    if (diff.inHours < 24) return '${diff.inHours} ч назад';
    if (diff.inDays == 1) return 'Вчера';
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}';
  }
}
