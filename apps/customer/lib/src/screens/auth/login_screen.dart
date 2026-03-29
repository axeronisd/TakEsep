import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../theme/akjol_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;

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
                  'Код отправлен на +996 ${_phoneController.text}',
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
                  onPressed: () => setState(() => _codeSent = false),
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
    if (_phoneController.text.length < 9) return;
    setState(() => _loading = true);
    // TODO: Supabase OTP
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _loading = false;
      _codeSent = true;
    });
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.length < 6) return;
    setState(() => _loading = true);
    // TODO: Verify OTP → navigate
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _loading = false);
    if (mounted) context.go('/');
  }
}
