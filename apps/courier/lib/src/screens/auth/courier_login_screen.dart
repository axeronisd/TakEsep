import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:akjol_auth/akjol_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/akjol_theme.dart';

/// Курьерский вход — единый аккаунт AkJol
/// Проверяет что номер зарегистрирован как курьер
class CourierLoginScreen extends StatefulWidget {
  const CourierLoginScreen({super.key});

  @override
  State<CourierLoginScreen> createState() => _CourierLoginScreenState();
}

class _CourierLoginScreenState extends State<CourierLoginScreen>
    with SingleTickerProviderStateMixin {
  final _auth = AkJolAuthService();
  final _supabase = Supabase.instance.client;
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  String? _error;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF0FFF4), Colors.white, Colors.white],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Logo
                  Hero(
                    tag: 'akjol_logo',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/images/akjol_logo.png',
                        width: 100,
                        height: 100,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'AkJol Курьер',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Единый аккаунт • Доставляй и зарабатывай',
                    style: TextStyle(
                      fontSize: 14,
                      color: AkJolTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 40),

                  if (_error != null) _buildError(),

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _codeSent ? _buildCodeInput() : _buildPhoneInput(),
                  ),

                  const Spacer(flex: 3),
                ],
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
        color: AkJolTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AkJolTheme.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AkJolTheme.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_error!,
                style: const TextStyle(color: AkJolTheme.error, fontSize: 13)),
          ),
          GestureDetector(
            onTap: () => setState(() => _error = null),
            child: const Icon(Icons.close, color: AkJolTheme.error, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneInput() {
    return Column(
      key: const ValueKey('phone'),
      children: [
        Container(
          decoration: BoxDecoration(
            color: AkJolTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AkJolTheme.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: AkJolTheme.border)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🇰🇬', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 6),
                    const Text('+996',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w500, letterSpacing: 1),
                  decoration: const InputDecoration(
                    hintText: '700 123 456',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('Получить SMS код',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeInput() {
    return Column(
      key: const ValueKey('code'),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AkJolTheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.sms_outlined, color: AkJolTheme.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Код отправлен на +996 ${_phoneController.text}',
                    style: const TextStyle(fontSize: 14, color: AkJolTheme.primary)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofocus: true,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: 12),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: InputDecoration(
            hintText: '• • • • • •',
            hintStyle: TextStyle(color: AkJolTheme.textTertiary, fontSize: 28, letterSpacing: 12),
          ),
          onChanged: (val) {
            if (val.length == 6) _verifyCode();
          },
        ),
        const SizedBox(height: 16),
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
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('Подтвердить',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => setState(() {
            _codeSent = false;
            _codeController.clear();
            _error = null;
          }),
          icon: const Icon(Icons.arrow_back_ios, size: 14),
          label: const Text('Изменить номер'),
        ),
      ],
    );
  }

  // ─── Auth Logic ──────────────────────────────

  Future<void> _sendCode() async {
    final phone = _phoneController.text.replaceAll(' ', '');
    if (phone.length < 9) {
      setState(() => _error = 'Введите корректный номер');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      // Проверяем что номер зарегистрирован как курьер
      final courier = await _supabase
          .from('couriers')
          .select('id')
          .eq('phone', '+996$phone')
          .maybeSingle();

      if (courier == null) {
        setState(() {
          _loading = false;
          _error = 'Этот номер не зарегистрирован как курьер.\nПопросите бизнес добавить вас.';
        });
        return;
      }

      await _auth.sendOtp(phone);
      setState(() { _loading = false; _codeSent = true; });
    } on AkJolAuthException catch (e) {
      setState(() { _loading = false; _error = e.message; });
    } catch (e) {
      setState(() { _loading = false; _error = 'Ошибка: попробуйте позже'; });
    }
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.length < 6) return;
    final phone = _phoneController.text.replaceAll(' ', '');

    setState(() { _loading = true; _error = null; });

    try {
      final profile = await _auth.verifyOtp(phone, _codeController.text);

      // Активировать роль курьера + привязать к courier record
      await _auth.enableCourierRole();
      await _supabase.from('couriers').update({
        'user_id': profile.id,
      }).eq('phone', '+996$phone');

      if (mounted) context.go('/');
    } on AkJolAuthException catch (e) {
      setState(() { _loading = false; _error = e.message; });
    } catch (e) {
      setState(() { _loading = false; _error = 'Ошибка: попробуйте позже'; });
    }
  }
}
