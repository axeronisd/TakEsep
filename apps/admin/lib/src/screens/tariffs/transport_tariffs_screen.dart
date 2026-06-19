import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:takesep_design_system/takesep_design_system.dart';

/// Screen for the super-admin to edit per-kilometer rates for transport types.
class TransportTariffsScreen extends StatefulWidget {
  const TransportTariffsScreen({super.key});

  @override
  State<TransportTariffsScreen> createState() => _TransportTariffsScreenState();
}

class _TransportTariffsScreenState extends State<TransportTariffsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _transports = [];
  double _courierEarningRate = 0.90;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTariffs();
  }

  Future<void> _loadTariffs() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _supabase
          .from('transport_types')
          .select()
          .order('name');

      final settingsData = await _supabase
          .from('system_settings')
          .select('courier_earning_rate')
          .eq('id', 'default')
          .maybeSingle();

      setState(() {
        _transports = List<Map<String, dynamic>>.from(data);
        if (settingsData != null) {
          _courierEarningRate = (settingsData['courier_earning_rate'] as num?)?.toDouble() ?? 0.90;
        }
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading tariffs: $e');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _updateTariff(String id, double pricePerKm) async {
    setState(() => _loading = true);
    try {
      await _supabase
          .from('transport_types')
          .update({'price_per_km': pricePerKm})
          .eq('id', id);
      _loadTariffs();
    } catch (e) {
      debugPrint('Error updating tariff: $e');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _updateCourierRate(double rate) async {
    setState(() => _loading = true);
    try {
      await _supabase
          .from('system_settings')
          .update({'courier_earning_rate': rate})
          .eq('id', 'default');
      _loadTariffs();
    } catch (e) {
      debugPrint('Error updating courier rate: $e');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _showEditDialog(Map<String, dynamic> transport) {
    final name = transport['name'] ?? '';
    final id = transport['id'] as String;
    final currentPrice = (transport['price_per_km'] as num?)?.toDouble() ?? 50.0;
    final ctrl = TextEditingController(text: currentPrice.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
        title: Text(
          'Редактировать тариф: $name',
          style: const TextStyle(color: AppColors.darkTextPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Укажите цену доставки за 1 километр:',
              style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
              ],
              style: const TextStyle(color: AppColors.darkTextPrimary),
              decoration: InputDecoration(
                suffixText: 'сом/км',
                suffixStyle: const TextStyle(color: AppColors.darkTextTertiary),
                filled: true,
                fillColor: AppColors.darkSurfaceVariant,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.darkBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена', style: TextStyle(color: AppColors.darkTextSecondary)),
          ),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text);
              if (val != null) {
                Navigator.pop(ctx);
                _updateTariff(id, val);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Сохранить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  IconData _getIconForTransport(String? iconStr) {
    switch (iconStr) {
      case 'pedal_bike':
        return Icons.pedal_bike_rounded;
      case 'two_wheeler':
        return Icons.two_wheeler_rounded;
      case 'local_shipping':
        return Icons.local_shipping_rounded;
      default:
        return Icons.delivery_dining_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 760;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: isMobile
          ? AppBar(
              backgroundColor: AppColors.darkSurface,
              elevation: 0,
              title: const Text('Тарифы доставки',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.darkTextPrimary)),
              iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
              actions: [
                IconButton(
                  onPressed: _loadTariffs,
                  icon: const Icon(Icons.refresh, size: 20),
                )
              ],
            )
          : null,
      body: _loading && _transports.isEmpty
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.primary)))
          : _error != null
              ? _buildErrorView()
              : _transports.isEmpty
                  ? const Center(child: Text('Нет тарифов в базе', style: TextStyle(color: AppColors.darkTextSecondary)))
                  : SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMobile) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Тарифы транспорта',
                                          style: TextStyle(
                                              fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.darkTextPrimary)),
                                      SizedBox(height: 4),
                                      Text('Настройка стоимости доставки за один километр',
                                          style: TextStyle(fontSize: 13, color: AppColors.darkTextTertiary)),
                                    ],
                                  ),
                                  IconButton(
                                    onPressed: _loadTariffs,
                                    icon: const Icon(Icons.refresh_rounded, color: AppColors.darkTextSecondary),
                                    tooltip: 'Обновить',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                            ],
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _transports.length,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isMobile ? 1 : 3,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                mainAxisExtent: 170,
                              ),
                              itemBuilder: (context, idx) {
                                final transport = _transports[idx];
                                final name = transport['name'] ?? 'Без названия';
                                final id = transport['id'] ?? '';
                                final pricePerKm = (transport['price_per_km'] as num?)?.toDouble() ?? 50.0;
                                final maxWeight = (transport['max_weight_kg'] as num?)?.toDouble() ?? 10.0;
                                final iconData = _getIconForTransport(transport['icon']);

                                return Card(
                                  color: AppColors.darkSurface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: const BorderSide(color: AppColors.darkBorder),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Icon(iconData, color: AppColors.primaryLight, size: 20),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(name,
                                                      style: const TextStyle(
                                                          color: AppColors.darkTextPrimary,
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.bold),
                                                      overflow: TextOverflow.ellipsis),
                                                  Text('ID: $id',
                                                      style: const TextStyle(
                                                          color: AppColors.darkTextTertiary, fontSize: 11)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Spacer(),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('Тариф за 1 км',
                                                    style: TextStyle(color: AppColors.darkTextTertiary, fontSize: 11)),
                                                Text('${pricePerKm.toStringAsFixed(0)} сом',
                                                    style: const TextStyle(
                                                        color: AppColors.primaryLight,
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w800)),
                                              ],
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('Макс. вес',
                                                    style: TextStyle(color: AppColors.darkTextTertiary, fontSize: 11)),
                                                Text('${maxWeight.toStringAsFixed(0)} кг',
                                                    style: const TextStyle(
                                                        color: AppColors.darkTextSecondary,
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w600)),
                                              ],
                                            ),
                                            IconButton.filledTonal(
                                              onPressed: () => _showEditDialog(transport),
                                              style: IconButton.styleFrom(
                                                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                                foregroundColor: AppColors.primaryLight,
                                                ),
                                              icon: const Icon(Icons.edit_rounded, size: 18),
                                            ),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                            _buildCourierRateSettingsCard(),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildCourierRateSettingsCard() {
    return Card(
      color: AppColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.darkBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.monetization_on_rounded, color: AppColors.primaryLight, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Базовая (системная) ставка заработка курьера',
                    style: TextStyle(color: AppColors.darkTextPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Данный процент применяется к стоимости доставки по умолчанию для всех курьеров. Если у курьера задана индивидуальная ставка в профиле, применяется она. Сейчас базовая ставка составляет ${(_courierEarningRate * 100).toStringAsFixed(0)}%, платформа оставляет ${((1.0 - _courierEarningRate) * 100).toStringAsFixed(0)}%.',
                    style: const TextStyle(color: AppColors.darkTextTertiary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: _showEditCourierRateDialog,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.white),
              label: Text(
                '${(_courierEarningRate * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCourierRateDialog() {
    final ctrl = TextEditingController(text: (_courierEarningRate * 100).toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
        title: const Text(
          'Редактировать базовую ставку курьера',
          style: TextStyle(color: AppColors.darkTextPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Укажите базовый процент дохода курьера от стоимости доставки:',
              style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
              ],
              style: const TextStyle(color: AppColors.darkTextPrimary),
              decoration: InputDecoration(
                suffixText: '%',
                suffixStyle: const TextStyle(color: AppColors.darkTextTertiary),
                filled: true,
                fillColor: AppColors.darkSurfaceVariant,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.darkBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена', style: TextStyle(color: AppColors.darkTextSecondary)),
          ),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text);
              if (val != null) {
                Navigator.pop(ctx);
                _updateCourierRate(val / 100.0);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Сохранить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.errorLight),
          const SizedBox(height: 16),
          const Text('Ошибка загрузки тарифов', style: TextStyle(color: AppColors.errorLight, fontSize: 16)),
          const SizedBox(height: 8),
          Text(_error ?? '', style: const TextStyle(color: AppColors.darkTextTertiary, fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadTariffs,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Повторить', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}
