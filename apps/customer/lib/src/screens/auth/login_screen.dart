import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:akjol_auth/akjol_auth.dart';

/// Единый экран входа AkJol
/// Один аккаунт для всех сервисов экосистемы
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _AuthMode { welcome, login, register, otp }

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _auth = AkJolAuthService();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  _AuthMode _mode = _AuthMode.welcome;
  bool _loading = false;
  String? _error;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  ColorScheme get _colors => Theme.of(context).colorScheme;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isDark
                ? [
                    const Color(0xFF0A1F12),
                    const Color(0xFF0D1117),
                    const Color(0xFF0D1117),
                  ]
                : [
                    const Color(0xFFE8FFF0),
                    const Color(0xFFF8F9FA),
                    Colors.white,
                  ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),

                    // ─── Logo ─────────────────────
                    _buildLogo(),
                    const SizedBox(height: 32),

                    // ─── Error ────────────────────
                    if (_error != null) _buildErrorBanner(),

                    // ─── Auth Content ─────────────
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.05),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: _buildContent(),
                    ),

                    const SizedBox(height: 40),

                    // ─── Services ─────────────────
                    _buildServicesBadges(),
                    const SizedBox(height: 16),

                    Text(
                      'Продолжая, вы соглашаетесь с условиями использования',
                      style: TextStyle(
                        fontSize: 11,
                        color: _colors.onSurface.withValues(alpha: 0.4),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Logo ──────────────────────────────────────

  Widget _buildLogo() {
    return Column(
      children: [
        Hero(
          tag: 'akjol_logo',
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2ECC71).withValues(alpha: _isDark ? 0.3 : 0.15),
                  blurRadius: 32,
                  spreadRadius: 0,
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
                  color: const Color(0xFF2ECC71),
                  child: const Icon(Icons.location_on, color: Colors.white, size: 48),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'AkJol',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.5,
            color: _colors.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _mode == _AuthMode.register
              ? 'Создайте аккаунт — один для всего'
              : 'Единый аккаунт для всех сервисов',
          style: TextStyle(
            fontSize: 15,
            color: _colors.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  // ─── Content Router ────────────────────────────

  Widget _buildContent() {
    switch (_mode) {
      case _AuthMode.welcome:
        return _buildWelcome();
      case _AuthMode.login:
        return _buildPhoneInput(isLogin: true);
      case _AuthMode.register:
        return _buildPhoneInput(isLogin: false);
      case _AuthMode.otp:
        return _buildCodeInput();
    }
  }

  // ─── Welcome Screen ────────────────────────────

  Widget _buildWelcome() {
    return Column(
      key: const ValueKey('welcome'),
      children: [
        // Войти
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: () => setState(() {
              _mode = _AuthMode.login;
              _error = null;
            }),
            icon: const Icon(Icons.login_rounded, size: 20),
            label: const Text('Войти'),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Зарегистрироваться
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: () => setState(() {
              _mode = _AuthMode.register;
              _error = null;
            }),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
            label: const Text('Зарегистрироваться'),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              side: BorderSide(
                color: _isDark
                    ? const Color(0xFF2ECC71).withValues(alpha: 0.5)
                    : const Color(0xFF2ECC71),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Phone Input ───────────────────────────────

  Widget _buildPhoneInput({required bool isLogin}) {
    return Column(
      key: ValueKey(isLogin ? 'login' : 'register'),
      children: [
        // Имя (только при регистрации)
        if (!isLogin) ...[
          Container(
            decoration: BoxDecoration(
              color: _colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE9ECEF),
              ),
            ),
            child: TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _colors.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Ваше имя',
                prefixIcon: Icon(Icons.person_outline,
                    color: _colors.onSurface.withValues(alpha: 0.4)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Номер телефона
        Container(
          decoration: BoxDecoration(
            color: _colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE9ECEF),
            ),
          ),
          child: Row(
            children: [
              // Код страны
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: _isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE9ECEF),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🇰🇬', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 6),
                    Text(
                      '+996',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              // Поле номера
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                    color: _colors.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: '700 123 456',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    hintStyle: TextStyle(
                      color: _colors.onSurface.withValues(alpha: 0.3),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Кнопка
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _loading ? null : _sendCode,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _loading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
                : Text(
                    isLogin ? 'Получить SMS код' : 'Зарегистрироваться',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 8),

        // Назад
        TextButton.icon(
          onPressed: () => setState(() {
            _mode = _AuthMode.welcome;
            _error = null;
            _phoneController.clear();
            _nameController.clear();
          }),
          icon: const Icon(Icons.arrow_back_ios, size: 14),
          label: Text(isLogin ? 'Назад' : 'Уже есть аккаунт? Войти'),
        ),
      ],
    );
  }

  // ─── OTP Code Input ────────────────────────────

  Widget _buildCodeInput() {
    return Column(
      key: const ValueKey('otp'),
      children: [
        // Баннер "код отправлен"
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2ECC71).withValues(alpha: _isDark ? 0.12 : 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF2ECC71).withValues(alpha: _isDark ? 0.2 : 0.1),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.sms_outlined, color: Color(0xFF2ECC71), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Код отправлен на +996 ${_phoneController.text}',
                  style: TextStyle(
                    fontSize: 14,
                    color: _isDark ? const Color(0xFF2ECC71) : const Color(0xFF27AE60),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Поле ввода кода
        Container(
          decoration: BoxDecoration(
            color: _colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE9ECEF),
            ),
          ),
          child: TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            autofocus: true,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: 12,
              color: _colors.onSurface,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              hintText: '• • • • • •',
              border: InputBorder.none,
              hintStyle: TextStyle(
                color: _colors.onSurface.withValues(alpha: 0.2),
                fontSize: 28,
                letterSpacing: 12,
              ),
            ),
            onChanged: (val) {
              if (val.length == 6) _verifyCode();
            },
          ),
        ),
        const SizedBox(height: 16),

        // Подтвердить
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _loading ? null : _verifyCode,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _loading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
                : const Text(
                    'Подтвердить',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 8),

        // Назад
        TextButton.icon(
          onPressed: () => setState(() {
            _mode = _AuthMode.login;
            _codeController.clear();
            _error = null;
          }),
          icon: const Icon(Icons.arrow_back_ios, size: 14),
          label: const Text('Изменить номер'),
        ),
      ],
    );
  }

  // ─── Error Banner ──────────────────────────────

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE74C3C).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE74C3C).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFE74C3C), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Color(0xFFE74C3C), fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _error = null),
            child: const Icon(Icons.close, color: Color(0xFFE74C3C), size: 16),
          ),
        ],
      ),
    );
  }

  // ─── Services Badges ───────────────────────────

  Widget _buildServicesBadges() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _serviceBadge(Icons.shopping_bag_outlined, 'Маркетплейс'),
        _serviceBadge(Icons.delivery_dining_outlined, 'Доставка'),
        _serviceBadge(Icons.local_taxi_outlined, 'Такси'),
        _serviceBadge(Icons.chat_bubble_outline, 'Чаты'),
      ],
    );
  }

  Widget _serviceBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _colors.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                fontSize: 12,
                color: _colors.onSurface.withValues(alpha: 0.5),
              )),
        ],
      ),
    );
  }

  // ─── Auth Logic ────────────────────────────────

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 9) {
      setState(() => _error = 'Введите полный номер телефона');
      return;
    }

    if (_mode == _AuthMode.register && _nameController.text.trim().isEmpty) {
      setState(() => _error = 'Введите ваше имя');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      await _auth.sendOtp(phone);
      setState(() { _loading = false; _mode = _AuthMode.otp; });
    } on AkJolAuthException catch (e) {
      setState(() { _loading = false; _error = e.message; });
    }
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.length < 6) return;

    setState(() { _loading = true; _error = null; });

    try {
      await _auth.verifyOtp(_phoneController.text, _codeController.text);

      // Если регистрация — сохраняем имя
      if (_mode == _AuthMode.register || _nameController.text.isNotEmpty) {
        final name = _nameController.text.trim();
        if (name.isNotEmpty) {
          try {
            await _auth.updateProfile(name: name);
          } catch (_) {
            // Не критично
          }
        }
      }

      if (mounted) context.go('/');
    } on AkJolAuthException catch (e) {
      setState(() { _loading = false; _error = e.message; });
    }
  }
}
