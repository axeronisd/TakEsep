import 'package:flutter/material.dart';
import '../../theme/akjol_theme.dart';

class ShiftScreen extends StatefulWidget {
  const ShiftScreen({super.key});

  @override
  State<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends State<ShiftScreen> {
  bool _shiftActive = false;
  final _bankController = TextEditingController(text: '1000');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Смена')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _shiftActive ? _buildActiveShift() : _buildStartShift(),
      ),
    );
  }

  Widget _buildStartShift() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AkJolTheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.play_arrow_rounded,
              size: 50, color: AkJolTheme.primary),
        ),
        const SizedBox(height: 24),
        const Text('Начать смену',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Укажите стартовый банк',
            style: TextStyle(color: AkJolTheme.textSecondary)),
        const SizedBox(height: 32),

        // Bank amount input
        TextField(
          controller: _bankController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            suffixText: 'сом',
            suffixStyle: TextStyle(fontSize: 18, color: AkJolTheme.textSecondary),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            setState(() => _shiftActive = true);
          },
          icon: const Icon(Icons.play_arrow),
          label: const Text('Начать'),
        ),
      ],
    );
  }

  Widget _buildActiveShift() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AkJolTheme.primary, AkJolTheme.primaryDark],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Смена активна',
                  style: TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
              SizedBox(height: 4),
              Text('3ч 24мин',
                  style: TextStyle(
                      color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Stats
        _StatRow(label: 'Выполнено заказов', value: '0'),
        _StatRow(label: 'Собрано наличных', value: '0 сом'),
        _StatRow(label: 'Заработок', value: '0 сом'),
        _StatRow(label: 'Стартовый банк', value: '${_bankController.text} сом'),

        const Spacer(),

        // End shift
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              _showEndShiftDialog();
            },
            icon: const Icon(Icons.stop, color: AkJolTheme.error),
            label: const Text('Завершить смену',
                style: TextStyle(color: AkJolTheme.error)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AkJolTheme.error),
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
        ),
      ],
    );
  }

  void _showEndShiftDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Завершить смену?'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Итоги смены:'),
            SizedBox(height: 12),
            // TODO: Show actual shift summary
            Text('Заказов: 0\nСобрано: 0 сом\nК сдаче: 0 сом'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _shiftActive = false);
            },
            child: const Text('Завершить'),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AkJolTheme.textSecondary)),
          Text(value,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
