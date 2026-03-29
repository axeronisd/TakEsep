import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/akjol_theme.dart';

class CourierLoginScreen extends StatefulWidget {
  const CourierLoginScreen({super.key});

  @override
  State<CourierLoginScreen> createState() => _CourierLoginScreenState();
}

class _CourierLoginScreenState extends State<CourierLoginScreen> {
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
                    colors: [AkJolTheme.primaryDark, AkJolTheme.primary],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.delivery_dining,
                    color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),

              const Text(
                'AkJol Курьер',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Доставляй и зарабатывай',
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

              // OTP input
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
                  decoration: const InputDecoration(hintText: '------'),
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
      // Check if this phone belongs to a registered courier
      final courier = await _supabase
          .from('couriers')
          .select('id, phone')
          .eq('phone', '+996$phone')
          .maybeSingle();

      if (courier == null) {
        setState(() {
          _loading = false;
          _error = 'Этот номер не зарегистрирован как курьер.\n'
              'Попросите бизнес добавить вас.';
        });
        return;
      }

      await _supabase.auth.signInWithOtp(phone: '+996$phone');

      setState(() {
        _loading = false;
        _codeSent = true;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Ошибка: ${_parseError(e)}';
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
        // Link auth user to courier record
        await _supabase.from('couriers').update({
          'user_id': response.user!.id,
        }).eq('phone', '+996$phone');

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

  String _parseError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('Invalid login credentials')) return 'Неверный код';
    if (msg.contains('rate limit')) return 'Слишком много попыток';
    return 'Попробуйте позже';
  }
}
