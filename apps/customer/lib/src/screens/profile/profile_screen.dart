import 'package:flutter/material.dart';
import '../../theme/akjol_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AkJolTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, size: 40, color: AkJolTheme.primary),
            ),
          ),
          const SizedBox(height: 24),

          _ProfileTile(
            icon: Icons.history,
            title: 'История заказов',
            onTap: () {},
          ),
          _ProfileTile(
            icon: Icons.location_on_outlined,
            title: 'Мои адреса',
            onTap: () {},
          ),
          _ProfileTile(
            icon: Icons.help_outline,
            title: 'Помощь',
            onTap: () {},
          ),
          _ProfileTile(
            icon: Icons.info_outline,
            title: 'О приложении',
            subtitle: 'AkJol v1.0.0',
            onTap: () {},
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              // TODO: Logout
            },
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

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AkJolTheme.primary),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: const Icon(Icons.chevron_right, color: AkJolTheme.textTertiary),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
