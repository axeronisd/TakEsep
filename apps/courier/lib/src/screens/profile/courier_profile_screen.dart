import 'package:flutter/material.dart';
import '../../theme/akjol_theme.dart';

class CourierProfileScreen extends StatelessWidget {
  const CourierProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar + name
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AkJolTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delivery_dining,
                      size: 40, color: AkJolTheme.primary),
                ),
                const SizedBox(height: 12),
                const Text('Курьер',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                Text('Велосипед',
                    style: TextStyle(color: AkJolTheme.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Stats card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AkJolTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(value: '0', label: 'Доставок'),
                _StatItem(value: '0', label: 'Заработок'),
                _StatItem(value: '—', label: 'Рейтинг'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Card(
            child: ListTile(
              leading: const Icon(Icons.history, color: AkJolTheme.primary),
              title: const Text('История доставок'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined,
                  color: AkJolTheme.primary),
              title: const Text('Заработок'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.help_outline, color: AkJolTheme.primary),
              title: const Text('Помощь'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.logout, color: AkJolTheme.error),
            label: const Text('Выйти', style: TextStyle(color: AkJolTheme.error)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AkJolTheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(fontSize: 12, color: AkJolTheme.textSecondary)),
      ],
    );
  }
}
