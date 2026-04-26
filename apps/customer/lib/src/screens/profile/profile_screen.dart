import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:akjol_auth/akjol_auth.dart';
import '../../theme/akjol_theme.dart';
import '../../services/firebase_push_bootstrap.dart';

/// ═══════════════════════════════════════════════════════════════
/// Profile Screen — Упрощенный премиум профиль AkJol
/// ═══════════════════════════════════════════════════════════════

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _auth = AkJolAuthService();

  Map<String, dynamic>? _profile;
  bool _loading = true;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await _supabase
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _profile = profile;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ─── Edit Personal Info ──────────────────────────────
  void _showEditDataSheet() {
    final nameCtrl = TextEditingController(text: _profile?['name'] ?? '');
    final usernameCtrl = TextEditingController(
      text: _profile?['username'] ?? '',
    );
    final phoneCtrl = TextEditingController(
      text: _supabase.auth.currentUser?.phone?.replaceFirst('+996', '') ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditDataSheet(
        nameCtrl: nameCtrl,
        usernameCtrl: usernameCtrl,
        phoneCtrl: phoneCtrl,
        isDark: _isDark,
        onSave: () async {
          Navigator.pop(ctx);
          await _savePersonalData(
            name: nameCtrl.text.trim(),
            username: usernameCtrl.text.trim().toLowerCase(),
            phone: phoneCtrl.text.trim(),
          );
        },
      ),
    );
  }

  Future<void> _savePersonalData({
    required String name,
    required String username,
    required String phone,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Clean phone
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');

      // Update Auth if phone changed (requires OTP usually, but we try)
      final currentPhone = user.phone ?? '';
      if (cleanPhone.isNotEmpty && currentPhone != '+996$cleanPhone') {
        try {
          // Warning: Supabase might send OTP to new number.
          await _supabase.auth.updateUser(
            UserAttributes(phone: '+996$cleanPhone'),
          );
        } catch (e) {
          _snack('Не удалось обновить номер телефона', AkJolTheme.error);
        }
      }

      // Update Profile
      await _supabase
          .from('user_profiles')
          .update({
            'name': name,
            'username': username,
            'updated_at': DateTime.now().toIso8601String(),
            if (cleanPhone.isNotEmpty) 'phone': '+996$cleanPhone',
          })
          .eq('id', user.id);

      setState(() {
        if (_profile != null) {
          _profile!['name'] = name;
          _profile!['username'] = username;
        }
      });
      _snack('Данные обновлены', AkJolTheme.success);
    } catch (e) {
      _snack('Ошибка сохранения (возможно username занят)', AkJolTheme.error);
    }
  }

  // ─── Edit Password ──────────────────────────────
  void _showEditPasswordSheet() {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditPasswordSheet(
        oldPassCtrl: oldPassCtrl,
        newPassCtrl: newPassCtrl,
        confirmPassCtrl: confirmPassCtrl,
        isDark: _isDark,
        onSave: () async {
          final oldPass = oldPassCtrl.text;
          final newPass = newPassCtrl.text;
          final currentPhone = _supabase.auth.currentUser?.phone;

          if (newPass.length < 6) {
            _snack(
              'Новый пароль должен быть от 6 символов',
              AkJolTheme.statusPending,
            );
            return;
          }

          if (currentPhone == null || currentPhone.isEmpty) {
            _snack('Ошибка: номер телефона не привязан', AkJolTheme.error);
            return;
          }

          Navigator.pop(ctx);

          try {
            // Verify old password by trying to re-login silently
            await _supabase.auth.signInWithPassword(
              phone: currentPhone,
              password: oldPass,
            );

            // Change password
            await _supabase.auth.updateUser(UserAttributes(password: newPass));

            _snack('Пароль успешно изменён', AkJolTheme.success);
          } on AuthException catch (e) {
            if (e.message.contains('Invalid login credentials')) {
              _snack('Неверный старый пароль', AkJolTheme.error);
            } else {
              _snack('Ошибка: ${e.message}', AkJolTheme.error);
            }
          } catch (e) {
            _snack('Не удалось изменить пароль', AkJolTheme.error);
          }
        },
      ),
    );
  }

  // ─── Logout ────────────────────────────────────
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isDark ? const Color(0xFF161B22) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Выйти из аккаунта?'),
        content: const Text('Вы сможете войти снова в любое время.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Отмена',
              style: TextStyle(
                color: _isDark
                    ? const Color(0xFF8B949E)
                    : const Color(0xFF6B7280),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebasePushBootstrap.onLogout();
              await _auth.signOut();
              if (mounted) context.go('/login');
            },
            child: const Text(
              'Выйти',
              style: TextStyle(color: AkJolTheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────
  String _getInitials() {
    final name = _profile?['name'] ?? '';
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    final bg = _isDark ? const Color(0xFF0D1117) : const Color(0xFFF8F9FA);
    final cardBg = _isDark ? const Color(0xFF161B22) : Colors.white;
    final text = _isDark ? Colors.white : const Color(0xFF111827);
    final muted = _isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
    final border = _isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB);

    if (_loading) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AkJolTheme.primary),
              const SizedBox(height: 16),
              Text(
                'Загрузка профиля...',
                style: TextStyle(color: muted, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        color: AkJolTheme.primary,
        child: CustomScrollView(
          slivers: [
            // ═══ HEADER ═══
            SliverToBoxAdapter(child: _buildHeader(user, text, muted)),

            // ═══ CONTENT ═══
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Settings ──
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: border, width: 0.5),
                    ),
                    child: Column(
                      children: [
                        _ActionTile(
                          icon: Icons.person_outline,
                          color: AkJolTheme.primary,
                          title: 'Личные данные',
                          subtitle: 'Имя, юзернейм, номер',
                          isDark: _isDark,
                          onTap: _showEditDataSheet,
                        ),
                        Divider(color: border, height: 1, indent: 56),
                        _ActionTile(
                          icon: Icons.lock_outline,
                          color: const Color(0xFF3498DB),
                          title: 'Пароль',
                          subtitle: 'Изменить текущий пароль',
                          isDark: _isDark,
                          onTap: _showEditPasswordSheet,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Danger Zone ──
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: border, width: 0.5),
                    ),
                    child: _ActionTile(
                      icon: Icons.logout_rounded,
                      color: AkJolTheme.error,
                      title: 'Выйти из аккаунта',
                      subtitle: 'Вы сможете войти снова',
                      isDark: _isDark,
                      onTap: _confirmLogout,
                      titleColor: AkJolTheme.error,
                    ),
                  ),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeader(User? user, Color text, Color muted) {
    final name = _profile?['name'] ?? 'Пользователь';
    final username = _profile?['username'] as String?;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDark
              ? [const Color(0xFF0D1A12), const Color(0xFF0D1117)]
              : [const Color(0xFFE8F8ED), const Color(0xFFF8F9FA)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2ECC71), Color(0xFF1ABC9C)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AkJolTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _getInitials(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: text,
                ),
              ),
              if (username != null && username.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '@$username',
                    style: const TextStyle(
                      fontSize: 15,
                      color: AkJolTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.phone_outlined, size: 14, color: muted),
                  const SizedBox(width: 4),
                  Text(
                    user?.phone ?? '',
                    style: TextStyle(fontSize: 14, color: muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  WIDGETS
// ═══════════════════════════════════════════════════════════════

// ── Action Tile ───────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final bool isDark;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? titleColor;

  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.isDark,
    this.onTap,
    this.trailing,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? const Color(0xFF8B949E) : const Color(0xFF9CA3AF);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color:
              titleColor ?? (isDark ? Colors.white : const Color(0xFF111827)),
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(subtitle, style: TextStyle(fontSize: 13, color: muted)),
      ),
      trailing: trailing ?? Icon(Icons.chevron_right, color: muted, size: 22),
      onTap: onTap,
    );
  }
}

// ── Edit Data Sheet ────────────────────────────

class _EditDataSheet extends StatelessWidget {
  final TextEditingController nameCtrl, usernameCtrl, phoneCtrl;
  final bool isDark;
  final VoidCallback onSave;

  const _EditDataSheet({
    required this.nameCtrl,
    required this.usernameCtrl,
    required this.phoneCtrl,
    required this.isDark,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF161B22) : Colors.white;
    final fieldBg = isDark ? const Color(0xFF21262D) : const Color(0xFFF3F4F6);
    final text = isDark ? Colors.white : const Color(0xFF111827);
    final muted = isDark ? const Color(0xFF8B949E) : const Color(0xFF9CA3AF);

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 100,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: muted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Личные данные',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: text,
            ),
          ),
          const SizedBox(height: 20),

          _sheetField('Имя', nameCtrl, fieldBg, text, muted, false),
          const SizedBox(height: 14),
          _sheetField(
            'Юзернейм',
            usernameCtrl,
            fieldBg,
            text,
            muted,
            false,
            isUsername: true,
          ),
          const SizedBox(height: 14),
          _sheetField(
            'Номер телефона',
            phoneCtrl,
            fieldBg,
            text,
            muted,
            false,
            isPhone: true,
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2ECC71).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  if (usernameCtrl.text.length < 3) return;
                  if (phoneCtrl.text.length < 9) return;
                  onSave();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Сохранить',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetField(
    String label,
    TextEditingController ctrl,
    Color fieldBg,
    Color text,
    Color muted,
    bool isObscure, {
    bool isPhone = false,
    bool isUsername = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: muted,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: ctrl,
            obscureText: isObscure,
            keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
            style: TextStyle(fontSize: 15, color: text),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              hintStyle: TextStyle(color: muted.withValues(alpha: 0.4)),
              prefixIcon: isPhone
                  ? const Padding(
                      padding: EdgeInsets.fromLTRB(16, 14, 8, 14),
                      child: Text(
                        '+996',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : isUsername
                  ? const Padding(
                      padding: EdgeInsets.fromLTRB(16, 14, 8, 14),
                      child: Text(
                        '@',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : null,
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Edit Password Sheet ────────────────────────────

class _EditPasswordSheet extends StatefulWidget {
  final TextEditingController oldPassCtrl, newPassCtrl, confirmPassCtrl;
  final bool isDark;
  final VoidCallback onSave;

  const _EditPasswordSheet({
    required this.oldPassCtrl,
    required this.newPassCtrl,
    required this.confirmPassCtrl,
    required this.isDark,
    required this.onSave,
  });

  @override
  State<_EditPasswordSheet> createState() => _EditPasswordSheetState();
}

class _EditPasswordSheetState extends State<_EditPasswordSheet> {
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF161B22) : Colors.white;
    final fieldBg = widget.isDark
        ? const Color(0xFF21262D)
        : const Color(0xFFF3F4F6);
    final text = widget.isDark ? Colors.white : const Color(0xFF111827);
    final muted = widget.isDark
        ? const Color(0xFF8B949E)
        : const Color(0xFF9CA3AF);

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 100,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: muted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Сменить пароль',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: text,
            ),
          ),
          const SizedBox(height: 20),

          _passField(
            'Старый пароль',
            widget.oldPassCtrl,
            fieldBg,
            text,
            muted,
            _obscureOld,
            () => setState(() => _obscureOld = !_obscureOld),
          ),
          const SizedBox(height: 14),
          _passField(
            'Новый пароль',
            widget.newPassCtrl,
            fieldBg,
            text,
            muted,
            _obscureNew,
            () => setState(() => _obscureNew = !_obscureNew),
          ),
          const SizedBox(height: 14),
          _passField(
            'Подтвердите пароль',
            widget.confirmPassCtrl,
            fieldBg,
            text,
            muted,
            _obscureConfirm,
            () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3498DB), Color(0xFF2980B9)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3498DB).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  if (widget.newPassCtrl.text != widget.confirmPassCtrl.text) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Пароли не совпадают'),
                        backgroundColor: AkJolTheme.error,
                      ),
                    );
                    return;
                  }
                  widget.onSave();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Изменить пароль',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passField(
    String label,
    TextEditingController ctrl,
    Color fieldBg,
    Color text,
    Color muted,
    bool isObscure,
    VoidCallback toggleEye,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: muted,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: ctrl,
            obscureText: isObscure,
            style: TextStyle(fontSize: 15, color: text),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  isObscure ? Icons.visibility_off : Icons.visibility,
                  color: muted,
                  size: 20,
                ),
                onPressed: toggleEye,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
