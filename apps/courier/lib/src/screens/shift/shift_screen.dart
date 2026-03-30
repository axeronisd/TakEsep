import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/order_service.dart';
import '../../theme/akjol_theme.dart';

class ShiftScreen extends StatefulWidget {
  const ShiftScreen({super.key});

  @override
  State<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends State<ShiftScreen> {
  final _supabase = Supabase.instance.client;
  final _orderService = OrderService();
  final _bankController = TextEditingController(text: '1000');

  Map<String, dynamic>? _courier;
  Map<String, dynamic>? _activeShift;
  bool _loading = true;
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadCourierAndShift();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadCourierAndShift() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final courier = await _supabase
          .from('couriers')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (courier != null) {
        _courier = courier;

        // Check for active shift
        final shift = await _supabase
            .from('courier_shifts')
            .select()
            .eq('courier_id', courier['id'])
            .isFilter('ended_at', null)
            .order('started_at', ascending: false)
            .maybeSingle();

        if (shift != null) {
          _activeShift = shift;
          _startTimer(DateTime.parse(shift['started_at']));
        }
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _startTimer(DateTime startedAt) {
    _elapsed = DateTime.now().difference(startedAt);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsed = DateTime.now().difference(startedAt);
      });
    });
  }

  Future<void> _startShift() async {
    if (_courier == null) return;

    final bank = double.tryParse(_bankController.text) ?? 0;

    try {
      final shift = await _orderService.startShift(_courier!['id'], bank);
      setState(() {
        _activeShift = shift;
      });
      _startTimer(DateTime.parse(shift['started_at']));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AkJolTheme.error),
        );
      }
    }
  }

  Future<void> _endShift() async {
    if (_courier == null || _activeShift == null) return;

    try {
      final result = await _orderService.endShift(
        _activeShift!['id'],
        _courier!['id'],
      );

      _timer?.cancel();

      if (mounted) {
        _showShiftSummary(result);
      }

      setState(() {
        _activeShift = null;
        _elapsed = Duration.zero;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AkJolTheme.error),
        );
      }
    }
  }

  void _showShiftSummary(Map<String, dynamic> shift) {
    final totalOrders = shift['total_orders'] ?? 0;
    final totalCollected = (shift['total_collected'] as num?)?.toDouble() ?? 0;
    final earning = (shift['courier_earning'] as num?)?.toDouble() ?? 0;
    final amountToReturn = (shift['amount_to_return'] as num?)?.toDouble() ?? 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.check_circle,
            color: AkJolTheme.primary, size: 48),
        title: const Text('Смена завершена'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SummaryRow('Заказов выполнено', '$totalOrders'),
            _SummaryRow(
                'Собрано наличных', '${totalCollected.toStringAsFixed(0)} сом'),
            _SummaryRow('Ваш заработок', '${earning.toStringAsFixed(0)} сом',
                highlight: true),
            const Divider(),
            _SummaryRow(
              'К сдаче бизнесу',
              '${amountToReturn.toStringAsFixed(0)} сом',
              bold: true,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Смена')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Смена')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _activeShift != null ? _buildActiveShift() : _buildStartShift(),
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
        Text('Укажите стартовый банк (наличные на размен)',
            style: TextStyle(color: AkJolTheme.textSecondary),
            textAlign: TextAlign.center),
        const SizedBox(height: 32),

        // Bank amount
        TextField(
          controller: _bankController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            suffixText: 'сом',
            suffixStyle:
                TextStyle(fontSize: 18, color: AkJolTheme.textSecondary),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _startShift,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Начать'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(200, 52),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveShift() {
    final hours = _elapsed.inHours;
    final minutes = _elapsed.inMinutes % 60;
    final seconds = _elapsed.inSeconds % 60;

    final startBank =
        (_activeShift!['start_bank'] as num?)?.toDouble() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timer card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AkJolTheme.primary, AkJolTheme.primaryDark],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('Смена активна',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$hoursч ${minutes.toString().padLeft(2, '0')}мин '
                '${seconds.toString().padLeft(2, '0')}сек',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Stats
        _StatRow(
            label: 'Стартовый банк',
            value: '${startBank.toStringAsFixed(0)} сом'),
        const Divider(),
        const _StatRow(label: 'Выполнено заказов', value: '—'),
        const _StatRow(label: 'Собрано наличных', value: '—'),
        const _StatRow(label: 'Заработок', value: '—'),

        const SizedBox(height: 8),
        Text(
          'Итоги рассчитываются при завершении смены',
          style: TextStyle(
              fontSize: 12,
              color: AkJolTheme.textTertiary,
              fontStyle: FontStyle.italic),
        ),

        const Spacer(),

        // End shift
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showEndShiftConfirm,
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

  void _showEndShiftConfirm() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Завершить смену?'),
        content: const Text(
            'Будет рассчитан итог по всем доставленным заказам за смену.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _endShift();
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
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final bool bold;
  const _SummaryRow(this.label, this.value,
      {this.highlight = false, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                color: bold ? null : AkJolTheme.textSecondary,
                fontWeight: bold ? FontWeight.w700 : null,
              )),
          Text(value,
              style: TextStyle(
                fontWeight: bold || highlight ? FontWeight.w700 : FontWeight.w500,
                color: highlight ? AkJolTheme.primary : null,
                fontSize: bold ? 18 : null,
              )),
        ],
      ),
    );
  }
}
