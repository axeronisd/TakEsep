import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import '../../providers/kitchen_direct_providers.dart';
import '../../providers/employee_providers.dart';
import '../../utils/snackbar_helper.dart';

class WaiterCommissionSettingsScreen extends ConsumerWidget {
  const WaiterCommissionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeeListProvider);
    final settingsAsync = ref.watch(directWaiterSettingsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Комиссии официантов'),
      ),
      body: employeesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Ошибка сотрудников: $err')),
        data: (employees) {
          return settingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Ошибка настроек: $err')),
            data: (settingsList) {
              // Convert settings list to helper map for quick lookup
              final settingsMap = {
                for (final s in settingsList) s.employeeId: s.commissionPercent
              };

              if (employees.isEmpty) {
                return const Center(child: Text('Сотрудники не найдены.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: employees.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final emp = employees[index];
                  final currentPercent = settingsMap[emp.id] ?? 0.0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      children: [
                        // Avatar and name
                        CircleAvatar(
                          backgroundColor: cs.surfaceContainerHighest,
                          child: Text(
                            emp.name.substring(0, 1).toUpperCase(),
                            style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                emp.name,
                                style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                              ),
                               if (emp.phone != null && emp.phone!.isNotEmpty)
                                Text(
                                  emp.phone!,
                                  style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
                                ),
                            ],
                          ),
                        ),

                        // Commission percentage input
                        SizedBox(
                          width: 140,
                          child: TextFormField(
                            initialValue: currentPercent == 0.0 ? '' : currentPercent.toStringAsFixed(1),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.end,
                            decoration: InputDecoration(
                              suffixText: ' %',
                              hintText: '0.0',
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              isDense: true,
                              fillColor: cs.surface,
                              filled: true,
                            ),
                            style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                            onChanged: (val) {
                              final double? percent = double.tryParse(val.replaceAll(',', '.'));
                              if (percent != null && percent >= 0.0 && percent <= 100.0) {
                                KitchenDirectMutator.saveWaiterCommission(emp.id, percent);
                              } else if (val.isEmpty) {
                                KitchenDirectMutator.saveWaiterCommission(emp.id, 0.0);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
