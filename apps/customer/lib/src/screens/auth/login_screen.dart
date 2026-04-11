import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:akjol_auth/akjol_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AkJolAuthService();
  bool _isRegister = false;

  // Login
  final _loginCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();
  bool _loginPassVisible = false;
  
  // Login Validation
  String? _loginIdError;
  String? _loginPassError;

  // Register
  final _regNameCtrl = TextEditingController();
  final _regPhoneCtrl = TextEditingController();
  final _regUsernameCtrl = TextEditingController();
  final _regPassCtrl = TextEditingController();
  final _regConfirmCtrl = TextEditingController();
  bool _regPassVisible = false;
  bool _regConfirmVisible = false;

  // Register Validation
  String? _regNameError;
  String? _regPhoneError;
  String? _regUsernameError;
  String? _regPassError;
  String? _regConfirmError;

  bool _loading = false;
  String? _error; // Глобальная ошибка (например от сервера)

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void dispose() {
    _loginCtrl.dispose();
    _loginPassCtrl.dispose();
    _regNameCtrl.dispose();
    _regPhoneCtrl.dispose();
    _regUsernameCtrl.dispose();
    _regPassCtrl.dispose();
    _regConfirmCtrl.dispose();
    super.dispose();
  }

  void _clearErrors() {
    setState(() {
      _error = null;
      _loginIdError = null;
      _loginPassError = null;
      _regNameError = null;
      _regPhoneError = null;
      _regUsernameError = null;
      _regPassError = null;
      _regConfirmError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textColor = _isDark ? Colors.white : const Color(0xFF111827);
    final mutedColor = _isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
    final fieldBg = _isDark ? const Color(0xFF0D1117) : const Color(0xFFF3F4F6);
    final borderColor = _isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB);

    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isDark
                    ? [const Color(0xFF0D1117), const Color(0xFF0A0F14), const Color(0xFF0D1117)]
                    : [const Color(0xFFF0FFF4), const Color(0xFFF7F8FA), const Color(0xFFECFDF5)],
              ),
            ),
          ),
          // Green orb top-right
          Positioned(
            top: -60, right: -40,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF2ECC71).withValues(alpha: _isDark ? 0.08 : 0.12),
                  const Color(0xFF2ECC71).withValues(alpha: 0),
                ]),
              ),
            ),
          ),
          // Green orb bottom-left
          Positioned(
            bottom: 100, left: -80,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF1ABC9C).withValues(alpha: _isDark ? 0.06 : 0.08),
                  const Color(0xFF1ABC9C).withValues(alpha: 0),
                ]),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      // ── Лого ──────────────────────
                      _logo(textColor, mutedColor),
                      const SizedBox(height: 32),

                      // ── Форма (Dark Glass) ─────────
                      ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                            decoration: BoxDecoration(
                              color: _isDark
                                  ? const Color(0xFF0D1117).withValues(alpha: 0.7)
                                  : Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: _isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.white.withValues(alpha: 0.6),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: _isDark ? 0.5 : 0.08),
                                  blurRadius: 32,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 350),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, anim) => FadeTransition(
                                opacity: anim,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.05),
                                    end: Offset.zero,
                                  ).animate(anim),
                                  child: child,
                                ),
                              ),
                              child: _isRegister
                                  ? _registerForm(textColor, mutedColor, fieldBg, borderColor)
                                  : _loginForm(textColor, mutedColor, fieldBg, borderColor),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Футер ─────────────────────
                      Text(
                        'Нажимая «${_isRegister ? 'Создать аккаунт' : 'Войти'}», вы принимаете\nусловия использования AkJol',
                        style: TextStyle(fontSize: 11, color: mutedColor.withValues(alpha: 0.5), height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  LOGO
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _logo(Color textColor, Color mutedColor) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2ECC71).withValues(alpha: 0.2),
                blurRadius: 24,
                spreadRadius: -4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/images/akjol_logo.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.location_on, color: Colors.white, size: 36),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'AK',
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w300,
                letterSpacing: 2,
                color: textColor,
              ),
            ),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF2ECC71), Color(0xFF1ABC9C)],
              ).createShader(bounds),
              child: const Text(
                'JOL',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  LOGIN FORM
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _loginForm(Color text, Color muted, Color fieldBg, Color border) {
    return Column(
      key: const ValueKey('login_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок
        Text('Добро пожаловать',
            style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w800, color: text, height: 1.2, letterSpacing: -0.5, fontFamily: 'Inter')),
        const SizedBox(height: 6),
        Text('Войдите в свой аккаунт AkJol',
            style: TextStyle(fontSize: 14, color: muted, height: 1.4)),
        const SizedBox(height: 28),

        // Ошибка сервера
        if (_error != null) ...[_errorWidget(), const SizedBox(height: 16)],

        // Логин
        _label('Телефон или username', muted),
        const SizedBox(height: 6),
        _inputField(
          controller: _loginCtrl,
          hint: '0700 123 456  или  akjol_user',
          fieldBg: fieldBg,
          border: border,
          text: text,
          muted: muted,
          errorText: _loginIdError,
          action: TextInputAction.next,
        ),
        const SizedBox(height: 18),

        // Пароль
        _label('Пароль', muted),
        const SizedBox(height: 6),
        _inputField(
          controller: _loginPassCtrl,
          hint: '••••••••',
          fieldBg: fieldBg,
          border: border,
          text: text,
          muted: muted,
          obscure: !_loginPassVisible,
          errorText: _loginPassError,
          action: TextInputAction.done,
          onSubmit: (_) => _handleLogin(),
          suffixIcon: _eyeButton(
            visible: _loginPassVisible,
            muted: muted,
            onTap: () => setState(() => _loginPassVisible = !_loginPassVisible),
          ),
        ),

        // Забыл пароль
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              padding: const EdgeInsets.only(top: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('Забыли пароль?',
                style: TextStyle(fontSize: 13, color: muted, fontWeight: FontWeight.w500)),
          ),
        ),
        const SizedBox(height: 20),

        // Кнопка
        _primaryButton('Войти', _handleLogin),
        const SizedBox(height: 20),

        // Переключатель
        _switchRow(
          'Ещё нет аккаунта?',
          'Создать',
          () => setState(() { _isRegister = true; _clearErrors(); }),
          text,
          muted,
        ),
      ],
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  REGISTER FORM
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _registerForm(Color text, Color muted, Color fieldBg, Color border) {
    return Column(
      key: const ValueKey('register_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Создать аккаунт',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800, color: text, height: 1.2, letterSpacing: -0.5, fontFamily: 'Inter')),
        const SizedBox(height: 4),
        Text('Заполните данные для регистрации',
            style: TextStyle(fontSize: 13, color: muted, height: 1.4)),
        const SizedBox(height: 20),

        if (_error != null) ...[_errorWidget(), const SizedBox(height: 16)],

        // Имя
        _label('Имя', muted),
        const SizedBox(height: 6),
        _inputField(
          controller: _regNameCtrl,
          hint: 'Как вас зовут',
          fieldBg: fieldBg,
          border: border,
          text: text,
          muted: muted,
          errorText: _regNameError,
          capitalization: TextCapitalization.words,
          action: TextInputAction.next,
        ),
        const SizedBox(height: 14),

        // Номер телефона
        _label('Номер телефона', muted),
        const SizedBox(height: 6),
        _phoneInput(fieldBg, border, text, muted, _regPhoneError),
        const SizedBox(height: 14),

        // Username
        _label('Username', muted),
        const SizedBox(height: 6),
        _inputField(
          controller: _regUsernameCtrl,
          hint: 'akjol_user',
          prefix: Text('@  ',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: muted)),
          fieldBg: fieldBg,
          border: border,
          text: text,
          muted: muted,
          errorText: _regUsernameError,
          action: TextInputAction.next,
          formatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._]')),
            LengthLimitingTextInputFormatter(20),
          ],
        ),
        const SizedBox(height: 14),

        // Пароль
        _label('Пароль', muted),
        const SizedBox(height: 6),
        _inputField(
          controller: _regPassCtrl,
          hint: 'Минимум 6 символов',
          fieldBg: fieldBg,
          border: border,
          text: text,
          muted: muted,
          errorText: _regPassError,
          obscure: !_regPassVisible,
          action: TextInputAction.next,
          suffixIcon: _eyeButton(
            visible: _regPassVisible,
            muted: muted,
            onTap: () => setState(() => _regPassVisible = !_regPassVisible),
          ),
        ),
        const SizedBox(height: 18),

        // Подтверждение пароля
        _label('Подтвердите пароль', muted),
        const SizedBox(height: 6),
        _inputField(
          controller: _regConfirmCtrl,
          hint: 'Повторите пароль',
          fieldBg: fieldBg,
          border: border,
          text: text,
          muted: muted,
          errorText: _regConfirmError,
          obscure: !_regConfirmVisible,
          action: TextInputAction.done,
          onSubmit: (_) => _handleRegister(),
          suffixIcon: _eyeButton(
            visible: _regConfirmVisible,
            muted: muted,
            onTap: () => setState(() => _regConfirmVisible = !_regConfirmVisible),
          ),
        ),
        const SizedBox(height: 20),

        _primaryButton('Создать аккаунт', _handleRegister),
        const SizedBox(height: 20),

        _switchRow(
          'Уже есть аккаунт?',
          'Войти',
          () => setState(() { _isRegister = false; _clearErrors(); }),
          text,
          muted,
        ),
      ],
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  UI COMPONENTS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _label(String text, Color muted) {
    return Text(text,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: muted,
            letterSpacing: 0.2));
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required Color fieldBg,
    required Color border,
    required Color text,
    required Color muted,
    String? errorText,
    bool obscure = false,
    Widget? suffixIcon,
    Widget? prefix,
    TextInputAction? action,
    TextCapitalization capitalization = TextCapitalization.none,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    void Function(String)? onSubmit,
  }) {
    final hasError = errorText != null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Container(
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(12),
            border: hasError
                ? Border.all(color: const Color(0xFFEF4444), width: 1.5)
                : null,
          ),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            textCapitalization: capitalization,
            textInputAction: action,
            keyboardType: keyboard,
            inputFormatters: formatters,
            onSubmitted: onSubmit,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: text,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: muted.withValues(alpha: 0.4),
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
              prefixIcon: prefix != null ? Padding(padding: const EdgeInsets.only(left: 16, right: 0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [prefix])) : null,
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(errorText, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w500)),
          ),
      ],
    );
  }

  Widget _phoneInput(Color fieldBg, Color border, Color text, Color muted, String? errorText) {
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(12),
            border: hasError
                ? Border.all(color: const Color(0xFFEF4444), width: 1.5)
                : null,
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text('KG  +996',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: text.withValues(alpha: 0.7))),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(width: 1, height: 20, color: border),
              ),
              Expanded(
                child: TextField(
                  controller: _regPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: text,
                    letterSpacing: 0.5,
                  ),
                  decoration: InputDecoration(
                    hintText: '700 123 456',
                    hintStyle: TextStyle(
                        color: muted.withValues(alpha: 0.35),
                        fontWeight: FontWeight.w400,
                        fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(errorText, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w500)),
          ),
      ],
    );
  }

  Widget _eyeButton({
    required bool visible,
    required Color muted,
    required VoidCallback onTap,
  }) {
    return IconButton(
      icon: Icon(
        visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 18,
        color: muted.withValues(alpha: 0.5),
      ),
      onPressed: onTap,
      splashRadius: 20,
    );
  }

  Widget _primaryButton(String label, VoidCallback onTap) {
    return SizedBox(
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
          onPressed: _loading ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(label,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
        ),
      ),
    );
  }

  Widget _switchRow(String text, String action, VoidCallback onTap, Color textColor, Color muted) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(text, style: TextStyle(fontSize: 13, color: muted)),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onTap,
          child: Text(action,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2ECC71))),
        ),
      ],
    );
  }

  Widget _errorWidget() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.info_outline, color: Color(0xFFDC2626), size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_error!,
                style: const TextStyle(
                    color: Color(0xFFDC2626), fontSize: 13, fontWeight: FontWeight.w500, height: 1.4)),
          ),
          GestureDetector(
            onTap: () => setState(() => _error = null),
            child: const Icon(Icons.close, color: Color(0xFFDC2626), size: 14),
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  AUTH LOGIC
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> _handleLogin() async {
    final login = _loginCtrl.text.trim();
    final password = _loginPassCtrl.text;

    _clearErrors();
    bool hasErr = false;

    if (login.isEmpty) {
      _loginIdError = 'Введите номер или username';
      hasErr = true;
    } else if (!RegExp(r'^\d').hasMatch(login) && !RegExp(r'^@?[a-zA-Z0-9._]{3,}$').hasMatch(login)) {
      _loginIdError = 'Некорректный формат';
      hasErr = true;
    }
    if (password.isEmpty) {
      _loginPassError = 'Введите пароль';
      hasErr = true;
    } else if (password.length < 6) {
      _loginPassError = 'Пароль минимум 6 символов';
      hasErr = true;
    }

    if (hasErr) {
      setState(() {});
      return;
    }

    setState(() { _loading = true; });

    try {
      await _auth.signIn(login: login, password: password);
      if (mounted) context.go('/');
    } on AkJolAuthException catch (e) {
      setState(() { _loading = false; _error = e.message; });
    } catch (e) {
      setState(() { _loading = false; _error = 'Ошибка соединения. Проверьте интернет.'; });
    }
  }

  Future<void> _handleRegister() async {
    final name = _regNameCtrl.text.trim();
    final phone = _regPhoneCtrl.text.trim();
    final username = _regUsernameCtrl.text.trim();
    final password = _regPassCtrl.text;
    final confirm = _regConfirmCtrl.text;

    _clearErrors();
    bool hasErr = false;

    // Имя
    if (name.isEmpty) {
      _regNameError = 'Введите ваше имя';
      hasErr = true;
    } else if (name.length < 2) {
      _regNameError = 'Имя слишком короткое';
      hasErr = true;
    } else if (name.length > 50) {
      _regNameError = 'Имя слишком длинное';
      hasErr = true;
    }

    // Телефон
    if (phone.isEmpty) {
      _regPhoneError = 'Введите номер телефона';
      hasErr = true;
    } else if (phone.length < 9) {
      _regPhoneError = 'Номер должен быть 9 цифр (напр. 700123456)';
      hasErr = true;
    } else if (!RegExp(r'^[0-9]{9}$').hasMatch(phone)) {
      _regPhoneError = 'Некорректный формат номера';
      hasErr = true;
    }

    // Username
    if (username.isEmpty) {
      _regUsernameError = 'Придумайте username';
      hasErr = true;
    } else if (username.length < 3) {
      _regUsernameError = 'Минимум 3 символа';
      hasErr = true;
    } else if (username.length > 20) {
      _regUsernameError = 'Максимум 20 символов';
      hasErr = true;
    } else if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(username)) {
      _regUsernameError = 'Только латинские буквы, цифры, точка и _';
      hasErr = true;
    } else if (RegExp(r'^[0-9]').hasMatch(username)) {
      _regUsernameError = 'Username не может начинаться с цифры';
      hasErr = true;
    }

    // Пароль
    if (password.isEmpty) {
      _regPassError = 'Введите пароль';
      hasErr = true;
    } else if (password.length < 6) {
      _regPassError = 'Минимум 6 символов';
      hasErr = true;
    } else if (!RegExp(r'[a-zA-Z]').hasMatch(password)) {
      _regPassError = 'Добавьте хотя бы одну букву';
      hasErr = true;
    } else if (!RegExp(r'[0-9]').hasMatch(password)) {
      _regPassError = 'Добавьте хотя бы одну цифру';
      hasErr = true;
    }

    // Подтверждение
    if (confirm.isEmpty) {
      _regConfirmError = 'Подтвердите пароль';
      hasErr = true;
    } else if (password != confirm) {
      _regConfirmError = 'Пароли не совпадают';
      hasErr = true;
    }

    if (hasErr) {
      setState(() {});
      return;
    }

    setState(() { _loading = true; });

    try {
      // Проверить уникальность username
      final existing = await Supabase.instance.client
          .from('user_profiles')
          .select('id')
          .eq('username', username.toLowerCase())
          .maybeSingle();

      if (existing != null) {
        setState(() {
          _loading = false;
          _regUsernameError = 'Этот username уже занят';
        });
        return;
      }

      // Проверить уникальность телефона
      final existingPhone = await Supabase.instance.client
          .from('user_profiles')
          .select('id')
          .eq('phone', '+996$phone')
          .maybeSingle();

      if (existingPhone != null) {
        setState(() {
          _loading = false;
          _regPhoneError = 'Этот номер уже зарегистрирован';
        });
        return;
      }

      await _auth.signUp(
        phone: phone,
        username: username,
        password: password,
        name: name,
      );
      if (mounted) context.go('/');
    } on AkJolAuthException catch (e) {
      setState(() { _loading = false; _error = e.message; });
    } catch (e) {
      setState(() { _loading = false; _error = 'Ошибка регистрации. Проверьте интернет и попробуйте снова.'; });
    }
  }
}
