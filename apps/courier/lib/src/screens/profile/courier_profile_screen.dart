import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/courier_providers.dart';
import '../../theme/akjol_theme.dart';

class CourierProfileScreen extends ConsumerStatefulWidget {
  const CourierProfileScreen({super.key});

  @override
  ConsumerState<CourierProfileScreen> createState() =>
      _CourierProfileScreenState();
}

class _CourierProfileScreenState extends ConsumerState<CourierProfileScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _courier;
  Map<String, dynamic>? _stats;
  bool _loading = true;
  bool _saving = false;
  bool _isUploadingQR = false;

  // Controllers for editable fields
  late TextEditingController _bankNameCtrl;
  late TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    _bankNameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _bankNameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = ref.read(courierProfileProvider);
    if (profile == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final courier = await _supabase
          .from('couriers')
          .select()
          .eq('id', profile.id)
          .maybeSingle();

      Map<String, dynamic>? stats;
      if (courier != null) {
        final deliveredOrders = await _supabase
            .from('delivery_orders')
            .select('id, courier_earning, delivery_fee')
            .eq('courier_id', courier['id'])
            .eq('status', 'delivered');

        double totalEarned = 0;
        for (final o in deliveredOrders) {
          totalEarned += (o['courier_earning'] as num?)?.toDouble() ?? 0;
        }

        stats = {
          'total_orders': deliveredOrders.length,
          'total_earned': totalEarned,
        };

        // Set controller values
        _bankNameCtrl.text = courier['bank_name'] ?? '';
        _phoneCtrl.text = courier['card_number'] ?? '';
      }

      setState(() {
        _courier = courier;
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Profile load error: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(courierProfileProvider);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AkJolTheme.primary)),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        color: AkJolTheme.primary,
        child: CustomScrollView(
          slivers: [
            // ── Header ──
            SliverToBoxAdapter(child: _buildHeader(profile)),

            // ── Stats Cards ──
            if (_stats != null)
              SliverToBoxAdapter(child: _buildStatsRow()),

            // ── Transport Info ──
            SliverToBoxAdapter(child: _buildTransportCard()),

            // ── Payment Requisites ──
            SliverToBoxAdapter(child: _buildRequisitesSection()),

            // ── Settings ──
            SliverToBoxAdapter(child: _buildSettingsSection()),

            // ── Logout ──
            SliverToBoxAdapter(child: _buildLogout()),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════

  Widget _buildHeader(dynamic profile) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AkJolTheme.primaryDark,
            AkJolTheme.primary.withValues(alpha: 0.7),
            Theme.of(context).scaffoldBackgroundColor,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AkJolTheme.primary, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AkJolTheme.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 42,
              backgroundColor: cs.surface,
              child: Text(
                _getInitials(profile?.name ?? 'К'),
                style: const TextStyle(
                  color: AkJolTheme.primary,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Name
          Text(
            profile?.name ?? 'Курьер',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),

          // Phone
          Text(
            profile?.phone ?? '',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: (_courier?['is_online'] == true ? AkJolTheme.primary : Colors.grey)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (_courier?['is_online'] == true ? AkJolTheme.primary : Colors.grey)
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _courier?['is_online'] == true ? AkJolTheme.primary : Colors.grey,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _courier?['is_online'] == true ? 'В сети' : 'Не в сети',
                  style: TextStyle(
                    color: _courier?['is_online'] == true ? AkJolTheme.primary : Colors.grey,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // STATS
  // ═══════════════════════════════════════════════════════════

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(child: _StatTile(
            icon: Icons.check_circle_rounded,
            value: '${_stats!['total_orders']}',
            label: 'Доставок',
            color: AkJolTheme.primary,
          )),
          const SizedBox(width: 12),
          Expanded(child: _StatTile(
            icon: Icons.account_balance_wallet_rounded,
            value: '${(_stats!['total_earned'] as double).toStringAsFixed(0)}',
            label: 'Заработано (сом)',
            color: const Color(0xFFFFA726),
          )),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TRANSPORT
  // ═══════════════════════════════════════════════════════════

  Widget _buildTransportCard() {
    if (_courier == null) return const SizedBox();
    final type = _courier!['transport_type'] ?? 'bicycle';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AkJolTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_transportIcon(type), color: AkJolTheme.primary, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Транспорт',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(_transportLabel(type),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AkJolTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _courier!['is_active'] == true ? 'Активен' : 'Отключен',
                style: TextStyle(
                  color: _courier!['is_active'] == true ? AkJolTheme.primary : Colors.redAccent,
                  fontSize: 12, fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // REQUISITES — with auto-save
  // ═══════════════════════════════════════════════════════════

  Widget _buildRequisitesSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.credit_card_rounded, color: AkJolTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text('Реквизиты для оплаты',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Клиенты переводят сюда за доставку',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35), fontSize: 12)),
            const SizedBox(height: 16),

            // Bank name
            _buildTextField(
              controller: _bankNameCtrl,
              label: 'Название банка',
              hint: 'Mbank, Optima, О!Деньги...',
              icon: Icons.account_balance_rounded,
              onSave: () => _saveField('bank_name', _bankNameCtrl.text),
            ),
            const SizedBox(height: 12),

            // Phone for transfer
            _buildTextField(
              controller: _phoneCtrl,
              label: 'Номер для перевода',
              hint: '+996 700 123 456',
              icon: Icons.phone_rounded,
              onSave: () => _saveField('card_number', _phoneCtrl.text),
            ),
            const SizedBox(height: 16),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveAllRequisites,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_saving ? 'Сохраняется...' : 'Сохранить реквизиты'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AkJolTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // QR Code
            Row(
              children: [
                Icon(Icons.qr_code_rounded, size: 20, color: AkJolTheme.primary),
                const SizedBox(width: 8),
                Text('QR для оплаты',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (_isUploadingQR)
                  const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AkJolTheme.primary))
                else
                  TextButton.icon(
                    onPressed: _uploadQR,
                    icon: Icon(
                      _hasQR ? Icons.refresh_rounded : Icons.upload_rounded,
                      size: 16, color: AkJolTheme.primary,
                    ),
                    label: Text(
                      _hasQR ? 'Заменить' : 'Загрузить',
                      style: const TextStyle(fontSize: 12, color: AkJolTheme.primary),
                    ),
                  ),
              ],
            ),
            if (_hasQR)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _courier!['qr_url'] as String,
                      height: 200,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        height: 80,
                        color: Colors.grey.withValues(alpha: 0.1),
                        child: const Center(child: Text('Ошибка загрузки QR')),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool get _hasQR =>
      _courier?['qr_url'] != null &&
      (_courier!['qr_url'] as String).isNotEmpty;

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required VoidCallback onSave,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: AkJolTheme.primary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SETTINGS
  // ═══════════════════════════════════════════════════════════

  Widget _buildSettingsSection() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            _SettingsTile(
              icon: Icons.notifications_active_rounded,
              label: 'Звук заказов',
              subtitle: 'Уведомления о новых заказах',
              trailing: Switch(
                value: true,
                onChanged: (_) {},
                activeColor: AkJolTheme.primary,
              ),
            ),
            Divider(height: 0.5, color: cs.outlineVariant.withValues(alpha: 0.15)),
            _SettingsTile(
              icon: Icons.support_agent_rounded,
              label: 'Поддержка',
              subtitle: 'Связаться с диспетчером',
              trailing: Icon(Icons.chevron_right, color: cs.onSurface.withValues(alpha: 0.25)),
              onTap: () {},
            ),
            Divider(height: 0.5, color: cs.outlineVariant.withValues(alpha: 0.15)),
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              label: 'О приложении',
              subtitle: 'AkJol Go v1.0.0',
              trailing: Icon(Icons.chevron_right, color: cs.onSurface.withValues(alpha: 0.25)),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // LOGOUT
  // ═══════════════════════════════════════════════════════════

  Widget _buildLogout() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
          label: const Text('Выйти из аккаунта',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════

  Future<void> _saveAllRequisites() async {
    if (_courier == null) return;
    setState(() => _saving = true);
    try {
      await _supabase.from('couriers').update({
        'bank_name': _bankNameCtrl.text,
        'card_number': _phoneCtrl.text,
      }).eq('id', _courier!['id']);

      _courier!['bank_name'] = _bankNameCtrl.text;
      _courier!['card_number'] = _phoneCtrl.text;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Реквизиты сохранены'),
              ],
            ),
            backgroundColor: AkJolTheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveField(String field, String value) async {
    if (_courier == null) return;
    try {
      await _supabase.from('couriers')
          .update(<String, dynamic>{field: value})
          .eq('id', _courier!['id']);
      setState(() => _courier![field] = value);
    } catch (e) {
      debugPrint('Save error: $e');
    }
  }

  Future<void> _uploadQR() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _isUploadingQR = true);

      final courierId = _courier!['id'];
      final ext = picked.name.split('.').last;
      final path = 'courier-qr/$courierId.$ext';
      final bytes = await picked.readAsBytes();

      await _supabase.storage.from('images').uploadBinary(
        path, bytes,
        fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
      );

      final publicUrl = _supabase.storage.from('images').getPublicUrl(path);
      await _saveField('qr_url', publicUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('QR загружен'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ошибка загрузки: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isUploadingQR = false);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('courier_phone');
    await prefs.remove('courier_key');
    await prefs.remove('courier_online');
    ref.read(courierProfileProvider.notifier).state = null;
    if (mounted) context.go('/login');
  }

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'К';
  }

  IconData _transportIcon(String type) {
    switch (type) {
      case 'bicycle': return Icons.electric_bike_rounded;
      case 'motorcycle':
      case 'scooter': return Icons.two_wheeler_rounded;
      case 'truck': return Icons.local_shipping_rounded;
      default: return Icons.delivery_dining_rounded;
    }
  }

  String _transportLabel(String type) {
    switch (type) {
      case 'bicycle': return 'Электровелосипед';
      case 'motorcycle':
      case 'scooter': return 'Муравей';
      case 'truck': return 'Грузовой';
      default: return type;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  STAT TILE
// ═══════════════════════════════════════════════════════════════

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.4),
                  fontSize: 12)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SETTINGS TILE
// ═══════════════════════════════════════════════════════════════

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: AkJolTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AkJolTheme.primary, size: 20),
      ),
      title: Text(label,
          style: TextStyle(color: cs.onSurface, fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle,
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.35), fontSize: 12)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
