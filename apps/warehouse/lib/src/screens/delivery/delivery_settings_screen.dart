import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeliverySettingsScreen extends StatefulWidget {
  final String warehouseId;
  const DeliverySettingsScreen({super.key, required this.warehouseId});

  @override
  State<DeliverySettingsScreen> createState() => _DeliverySettingsScreenState();
}

class _DeliverySettingsScreenState extends State<DeliverySettingsScreen> {
  final _supabase = Supabase.instance.client;
  final _addressController = TextEditingController();
  final _radiusController = TextEditingController(text: '3');
  final _minOrderController = TextEditingController(text: '0');
  final _descController = TextEditingController();

  bool _isActive = false;
  bool _loading = true;
  bool _saving = false;
  String? _settingsId;

  // Transport selection
  Set<String> _selectedTransports = {'bicycle'};
  List<Map<String, dynamic>> _allTransports = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadTransports();
  }

  Future<void> _loadTransports() async {
    try {
      final data = await _supabase.from('transport_types').select('*');
      setState(() {
        _allTransports = List<Map<String, dynamic>>.from(data);
      });
    } catch (_) {}
  }

  Future<void> _loadSettings() async {
    try {
      final data = await _supabase
          .from('delivery_settings')
          .select('*')
          .eq('warehouse_id', widget.warehouseId)
          .maybeSingle();

      if (data != null) {
        setState(() {
          _settingsId = data['id'];
          _isActive = data['is_active'] ?? false;
          _addressController.text = data['address'] ?? '';
          _radiusController.text = '${data['delivery_radius_km'] ?? 3}';
          _minOrderController.text = '${data['min_order_amount'] ?? 0}';
          _descController.text = data['description'] ?? '';
          _selectedTransports =
              Set<String>.from(data['available_transports'] ?? ['bicycle']);
        });
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final payload = {
      'warehouse_id': widget.warehouseId,
      'is_active': _isActive,
      'address': _addressController.text,
      'delivery_radius_km': double.tryParse(_radiusController.text) ?? 3,
      'min_order_amount': double.tryParse(_minOrderController.text) ?? 0,
      'description': _descController.text,
      'available_transports': _selectedTransports.toList(),
    };

    try {
      if (_settingsId != null) {
        await _supabase
            .from('delivery_settings')
            .update(payload)
            .eq('id', _settingsId!);
      } else {
        final result = await _supabase
            .from('delivery_settings')
            .insert(payload)
            .select()
            .single();
        _settingsId = result['id'];
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Настройки сохранены'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }

    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Настройки доставки')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки доставки'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: const Text('Сохранить'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Active toggle
          Card(
            child: SwitchListTile(
              title: const Text('Доставка активна',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(_isActive
                  ? 'Покупатели видят ваш магазин'
                  : 'Магазин скрыт от покупателей'),
              value: _isActive,
              activeColor: Colors.green,
              onChanged: (v) => setState(() => _isActive = v),
            ),
          ),
          const SizedBox(height: 16),

          // Address
          const Text('Адрес магазина',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              hintText: 'Улица, номер дома',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 16),

          // Description
          const Text('Описание для покупателей',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(
              hintText: 'Продукты, хозтовары, бытовая химия...',
              prefixIcon: Icon(Icons.description_outlined),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          // Radius
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Радиус доставки (км)',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _radiusController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        suffixText: 'км',
                        prefixIcon: Icon(Icons.radar),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Мин. заказ (сом)',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _minOrderController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        suffixText: 'сом',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Transports
          const Text('Доступные транспорты',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Выберите какие транспорты доступны',
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 12),
          ..._allTransports.map((t) {
            final tId = t['id'] as String;
            final isSelected = _selectedTransports.contains(tId);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: isSelected ? Colors.green.withValues(alpha: 0.05) : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? Colors.green : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: CheckboxListTile(
                value: isSelected,
                activeColor: Colors.green,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedTransports.add(tId);
                    } else if (_selectedTransports.length > 1) {
                      _selectedTransports.remove(tId);
                    }
                  });
                },
                title: Row(
                  children: [
                    Icon(_transportIcon(tId), size: 24),
                    const SizedBox(width: 8),
                    Text(t['name'] ?? tId,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
                subtitle: Text(
                  'до ${(t['max_weight_kg'] as num).toInt()} кг • '
                  'день ${(t['day_price'] as num).toInt()} сом • '
                  'ночь ${(t['night_price'] as num).toInt()} сом',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ),
            );
          }),

          const SizedBox(height: 24),

          // Tariff info
          Card(
            color: Colors.blue.withValues(alpha: 0.05),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.blue),
                      SizedBox(width: 6),
                      Text('Тарифы AkJol',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text('Комиссия: 15% от стоимости доставки\n'
                      'Вы получаете 100% стоимости товаров\n'
                      'Ночной тариф действует с 21:00',
                      style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _transportIcon(String type) {
    switch (type) {
      case 'bicycle':
        return Icons.pedal_bike;
      case 'motorcycle':
        return Icons.two_wheeler;
      case 'truck':
        return Icons.local_shipping;
      default:
        return Icons.delivery_dining;
    }
  }
}
