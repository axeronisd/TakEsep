import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:akjol_auth/akjol_auth.dart';

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
    final bg = _isDark ? const Color(0xFF0D1117) : const Color(0xFFF7F8FA);
    final cardBg = _isDark ? const Color(0xFF161B22) : Colors.white;
    final textColor = _isDark ? Colors.white : const Color(0xFF111827);
    final mutedColor = _isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
    final fieldBg = _isDark ? const Color(0xFF0D1117) : const Color(0xFFF3F4F6);
    final borderColor = _isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                // ── Лого ──────────────────────
                _logo(textColor, mutedColor),
                const SizedBox(height: 32),

                // ── Форма ─────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor),
                    boxShadow: _isDark
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                  ),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _isRegister
                        ? _registerForm(textColor, mutedColor, fieldBg, borderColor)
                        : _loginForm(textColor, mutedColor, fieldBg, borderColor),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Футер ─────────────────────
                Text(
                  'Нажимая «${_isRegister ? 'Создать аккаунт' : 'Войти'}», вы принимаете\nусловия использования AkJol',
                  style: TextStyle(fontSize: 11, color: mutedColor.withValues(alpha: 0.6), height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
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
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 34,
              letterSpacing: -1.2,
              fontFamily: 'Inter',
            ),
            children: [
              TextSpan(
                text: 'Ak',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const TextSpan(
                text: 'Jol',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2ECC71),
                ),
              ),
            ],
          ),
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
                fontSize: 26, fontWeight: FontWeight.w800, color: text, height: 1.2, letterSpacing: -0.5, fontFamily: 'Inter')),
        const SizedBox(height: 6),
        Text('Заполните данные для регистрации',
            style: TextStyle(fontSize: 14, color: muted, height: 1.4)),
        const SizedBox(height: 28),

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
        const SizedBox(height: 18),

        // Номер телефона
        _label('Номер телефона', muted),
        const SizedBox(height: 6),
        _phoneInput(fieldBg, border, text, muted, _regPhoneError),
        const SizedBox(height: 18),

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
        const SizedBox(height: 18),

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
        const SizedBox(height: 24),

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
    final borderColor = hasError ? const Color(0xFFEF4444) : border;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: hasError ? 1.5 : 1),
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
    final borderColor = hasError ? const Color(0xFFEF4444) : border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: hasError ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text('🇰🇬  +996',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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
      height: 50,
      child: ElevatedButton(
        onPressed: _loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2ECC71),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF2ECC71).withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3)),
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
    }
    if (password.isEmpty) {
      _loginPassError = 'Введите пароль';
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

    if (name.isEmpty) {
      _regNameError = 'Обязательное поле';
      hasErr = true;
    }
    if (phone.length < 9) {
      _regPhoneError = 'Неполный номер';
      hasErr = true;
    }
    if (username.length < 3) {
      _regUsernameError = 'Минимум 3 символа';
      hasErr = true;
    }
    if (password.length < 6) {
      _regPassError = 'Минимум 6 символов';
      hasErr = true;
    }
    if (password != confirm) {
      _regConfirmError = 'Пароли не совпадают';
      hasErr = true;
    }

    if (hasErr) {
      setState(() {});
      return;
    }

    setState(() { _loading = true; });

    try {
      await _auth.signUp(
        phone: phone,
        username: username,
        password: password,
        name: name,
      );
      if (mounted) context.go('/');
    } on AkJolAuthException catch (e) {
      setState(() { _loading = false; _error = e.message; });
    }
  }
}
