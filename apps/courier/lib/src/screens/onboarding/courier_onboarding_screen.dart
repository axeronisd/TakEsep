import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/akjol_theme.dart';

/// Онбординг-экран для нового курьера
/// Появляется после логина, если профиль курьера ещё не создан
class CourierOnboardingScreen extends StatefulWidget {
  const CourierOnboardingScreen({super.key});

  @override
  State<CourierOnboardingScreen> createState() => _CourierOnboardingScreenState();
}

class _CourierOnboardingScreenState extends State<CourierOnboardingScreen> {
  final _supabase = Supabase.instance.client;
  final _nameCtrl = TextEditingController();
  String _transport = 'bicycle';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Предзаполняем имя из метаданных юзера если есть
    final user = _supabase.auth.currentUser;
    final meta = user?.userMetadata;
    if (meta != null && meta['name'] != null) {
      _nameCtrl.text = meta['name'];
    }
  }

  Future<void> _createProfile() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите ваше имя'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _saving = true);
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Создаём профиль курьера
      await _supabase.from('couriers').insert({
        'user_id': user.id,
        'name': _nameCtrl.text.trim(),
        'phone': user.phone ?? '',
        'transport_type': _transport,
        'courier_type': 'freelance',
        'is_active': true,
        'is_online': false,
      });

      // Проверяем есть ли приглашения по нашему номеру
      if (user.phone != null) {
        final invitations = await _supabase
            .from('courier_invitations')
            .select('id')
            .eq('phone', user.phone!)
            .eq('status', 'pending');

        // Если есть — покажем их на профиле позже
        if (invitations.isNotEmpty) {
          debugPrint('📬 Найдено ${invitations.length} приглашений!');
        }
      }

      if (mounted) {
        // Перезагрузка приложения — роутер направит на главную
        Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AkJolTheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // Header
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AkJolTheme.primaryDark, AkJolTheme.primary],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.delivery_dining, size: 44, color: Colors.white),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text('Добро пожаловать в AkJol!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text('Заполните профиль, чтобы начать доставлять',
                    style: TextStyle(fontSize: 14, color: AkJolTheme.textSecondary),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(height: 40),

              // Имя
              const Text('Ваше имя', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Как к вам обращаться',
                  prefixIcon: const Icon(Icons.person_outline),
                  filled: true,
                  fillColor: AkJolTheme.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Транспорт
              const Text('Ваш транспорт', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _TransportOption(
                    icon: Icons.pedal_bike,
                    label: 'Вело',
                    value: 'bicycle',
                    selected: _transport == 'bicycle',
                    onTap: () => setState(() => _transport = 'bicycle'),
                  ),
                  const SizedBox(width: 12),
                  _TransportOption(
                    icon: Icons.two_wheeler,
                    label: 'Мото',
                    value: 'motorcycle',
                    selected: _transport == 'motorcycle',
                    onTap: () => setState(() => _transport = 'motorcycle'),
                  ),
                  const SizedBox(width: 12),
                  _TransportOption(
                    icon: Icons.local_shipping,
                    label: 'Грузовой',
                    value: 'truck',
                    selected: _transport == 'truck',
                    onTap: () => setState(() => _transport = 'truck'),
                  ),
                ],
              ),

              const Spacer(),

              // Кнопка
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _createProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AkJolTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Начать работу',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransportOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _TransportOption({
    required this.icon,
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: selected
                ? AkJolTheme.primary.withValues(alpha: 0.1)
                : AkJolTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AkJolTheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 32,
                  color: selected ? AkJolTheme.primary : AkJolTheme.textSecondary),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AkJolTheme.primary : AkJolTheme.textSecondary,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
