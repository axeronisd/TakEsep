import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/akjol_theme.dart';
import '../../services/courier_auth_service.dart';
import '../../providers/courier_providers.dart';

/// Курьерский вход по секретному ключу
/// Админ генерирует ключ → курьер вводит телефон + ключ
class CourierLoginScreen extends ConsumerStatefulWidget {
  const CourierLoginScreen({super.key});

  @override
  ConsumerState<CourierLoginScreen> createState() => _CourierLoginScreenState();
}

class _CourierLoginScreenState extends ConsumerState<CourierLoginScreen>
    with SingleTickerProviderStateMixin {
  final _courierAuth = CourierAuthService();
  final _phoneController = TextEditingController();
  final _keyController = TextEditingController();
  bool _loading = false;
  bool _autoLogging = true;
  String? _error;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPhone = prefs.getString('courier_phone');
      final savedKey = prefs.getString('courier_key');

      if (savedPhone != null && savedKey != null) {
        final profile = await _courierAuth.loginWithKey(
          phone: savedPhone,
          accessKey: savedKey,
        );

        if (profile != null && mounted) {
          ref.read(courierProfileProvider.notifier).state = profile;
          context.go('/');
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _autoLogging = false);
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _phoneController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_autoLogging) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A2E1A), Color(0xFF0D1B0F), Color(0xFF0A0F0A)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset(
                    'assets/images/akjol_logo.png',
                    width: 100,
                    height: 100,
                    errorBuilder: (_, __, ___) => Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AkJolTheme.primary,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: const Icon(
                        Icons.delivery_dining,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'AkJol Pro',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: AkJolTheme.primary,
                    strokeWidth: 2.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A2E1A), Color(0xFF0D1B0F), Color(0xFF0A0F0A)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                    // ── Logo ──
                    Hero(
                      tag: 'akjol_logo',
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: AkJolTheme.primary.withValues(alpha: 0.3),
                              blurRadius: 30,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.asset(
                            'assets/images/akjol_logo.png',
                            width: 100,
                            height: 100,
                            errorBuilder: (_, __, ___) => Container(
                              color: AkJolTheme.primary,
                              child: const Icon(
                                Icons.delivery_dining,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'AkJol Pro',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Доставляй и зарабатывай',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ── Error ──
                    if (_error != null) _buildError(),

                    // ── Phone Input ──
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('🇰🇬', style: TextStyle(fontSize: 22)),
                                SizedBox(width: 6),
                                Text(
                                  '+996',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(9),
                              ],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1,
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                hintText: '700 123 456',
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.25),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                filled: false,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Key Input ──
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                            ),
                            child: Icon(
                              Icons.vpn_key_rounded,
                              color: AkJolTheme.primary.withValues(alpha: 0.7),
                              size: 22,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _keyController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 8,
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                hintText: '• • • • • •',
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  fontSize: 20,
                                  letterSpacing: 8,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                filled: false,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Введите 6-значный ключ от администратора',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Login Button ──
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AkJolTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.login_rounded, size: 20),
                                  SizedBox(width: 10),
                                  Text(
                                    'Войти',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const Spacer(flex: 3),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AkJolTheme.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AkJolTheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AkJolTheme.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: AkJolTheme.error, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _error = null),
            child: const Icon(Icons.close, color: AkJolTheme.error, size: 16),
          ),
        ],
      ),
    );
  }

  // ─── Auth Logic ──────────────────────────────

  Future<void> _login() async {
    final phone = _phoneController.text.replaceAll(' ', '');
    final key = _keyController.text.trim();

    if (phone.length < 9) {
      setState(() => _error = 'Введите корректный номер');
      return;
    }
    if (key.length < 6) {
      setState(() => _error = 'Введите 6-значный ключ');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final fullPhone = '+996$phone';
      final profile = await _courierAuth.loginWithKey(
        phone: fullPhone,
        accessKey: key,
      );

      if (profile == null) {
        setState(() {
          _loading = false;
          _error = 'Неверный номер или ключ.\nПолучите ключ у администратора.';
        });
        return;
      }

      // Save credentials for auto-login
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('courier_phone', fullPhone);
      await prefs.setString('courier_key', key);

      // Store profile
      ref.read(courierProfileProvider.notifier).state = profile;

      if (mounted) context.go('/');
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Ошибка входа: попробуйте позже';
      });
    }
  }
}
