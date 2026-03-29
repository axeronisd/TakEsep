import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/akjol_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _supabase = Supabase.instance.client;
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AkJolTheme.primary, AkJolTheme.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.local_shipping_rounded,
                    color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'AkJol',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Доставка к вашей двери',
                style: TextStyle(
                  fontSize: 16,
                  color: AkJolTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 48),

              // Error
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AkJolTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AkJolTheme.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AkJolTheme.error, fontSize: 13)),
                      ),
                    ],
                  ),
                ),

              // Phone input
              if (!_codeSent) ...[
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    hintText: 'Номер телефона',
                    prefixText: '+996 ',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loading ? null : _sendCode,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Получить код'),
                ),
              ],

              // Code input
              if (_codeSent) ...[
                Text(
                  'Код отправлен на +996${_phoneController.text}',
                  style: TextStyle(color: AkJolTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 8),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(
                    hintText: '------',
                  ),
                  onChanged: (val) {
                    if (val.length == 6) _verifyCode();
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loading ? null : _verifyCode,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Войти'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() {
                    _codeSent = false;
                    _error = null;
                  }),
                  child: const Text('Изменить номер'),
                ),
              ],

              const Spacer(),

              Text(
                'Продолжая, вы соглашаетесь с условиями использования',
                style: TextStyle(
                  fontSize: 12,
                  color: AkJolTheme.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.replaceAll(' ', '');
    if (phone.length < 9) {
      setState(() => _error = 'Введите корректный номер');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _supabase.auth.signInWithOtp(
        phone: '+996$phone',
      );

      // Ensure customer record exists
      // Will be created/updated after OTP verification

      setState(() {
        _loading = false;
        _codeSent = true;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Ошибка отправки SMS: ${_parseError(e)}';
      });
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text;
    if (code.length < 6) return;

    final phone = _phoneController.text.replaceAll(' ', '');

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _supabase.auth.verifyOTP(
        phone: '+996$phone',
        token: code,
        type: OtpType.sms,
      );

      if (response.user != null) {
        // Upsert customer record
        await _upsertCustomer(response.user!);

        if (mounted) context.go('/');
      } else {
        setState(() {
          _loading = false;
          _error = 'Неверный код';
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Ошибка: ${_parseError(e)}';
      });
    }
  }

  Future<void> _upsertCustomer(User user) async {
    try {
      await _supabase.from('customers').upsert({
        'id': user.id,
        'phone': user.phone,
        'name': user.phone, // Will be updated later in profile
      }, onConflict: 'id');
    } catch (_) {
      // Non-critical — customer can update later
    }
  }

  String _parseError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('Invalid login credentials')) {
      return 'Неверный код';
    }
    if (msg.contains('Phone number')) {
      return 'Некорректный номер';
    }
    if (msg.contains('rate limit')) {
      return 'Слишком много попыток, подождите';
    }
    return 'Попробуйте позже';
  }
}
