import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import '../../widgets/admin_page_body.dart';

class AddressModerationScreen extends ConsumerStatefulWidget {
  const AddressModerationScreen({super.key});

  @override
  ConsumerState<AddressModerationScreen> createState() => _AddressModerationScreenState();
}

class _AddressModerationScreenState extends ConsumerState<AddressModerationScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _pendingWarehouses = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final data = await Supabase.instance.client
          .from('warehouses')
          .select('id, name, address, latitude, longitude, pending_address, pending_lat, pending_lng, address_status')
          .eq('address_status', 'pending');
          
      setState(() {
        _pendingWarehouses = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approveAddress(Map<String, dynamic> wh) async {
    try {
      await Supabase.instance.client.from('warehouses').update({
        'address': wh['pending_address'],
        'latitude': wh['pending_lat'],
        'longitude': wh['pending_lng'],
        'address_status': 'verified',
        'pending_address': null,
        'pending_lat': null,
        'pending_lng': null,
      }).eq('id', wh['id']);
      
      // Update delivery_settings too, since it is used as fallback
      await Supabase.instance.client.from('delivery_settings').update({
        'latitude': wh['pending_lat'],
        'longitude': wh['pending_lng'],
      }).eq('warehouse_id', wh['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Адрес одобрен'), backgroundColor: Colors.green));
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _rejectAddress(String id) async {
    try {
      await Supabase.instance.client.from('warehouses').update({
        'address_status': 'verified', // Revert to verified (old address)
        'pending_address': null,
        'pending_lat': null,
        'pending_lng': null,
      }).eq('id', id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Изменения отклонены')));
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AdminSearchField(
                  hint: 'Поиск по заявкам...',
                  onChanged: (v) {}, // Mock search for now
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.darkSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: AppColors.darkBorder),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _pendingWarehouses.isEmpty
                    ? const AdminEmptyState(
                        icon: Icons.check_circle_outline_rounded,
                        title: 'Нет заявок',
                        subtitle: 'Все изменения адресов проверены',
                      )
                    : ListView.separated(
                        itemCount: _pendingWarehouses.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final wh = _pendingWarehouses[index];
                          return _buildModerationCard(wh);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildModerationCard(Map<String, dynamic> wh) {
    final oldAddress = wh['address'] ?? 'Нет старого адреса';
    final newAddress = wh['pending_address'] ?? 'Без адреса';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            wh['name'] ?? 'Склад',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('СТАРЫЙ АДРЕС', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(oldAddress, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('${wh['latitude'] ?? '-'}, ${wh['longitude'] ?? '-'}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Icon(Icons.arrow_forward_rounded, color: Colors.grey),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('НОВЫЙ АДРЕС', style: TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(newAddress, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('${wh['pending_lat'] ?? '-'}, ${wh['pending_lng'] ?? '-'}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.darkBorder),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _rejectAddress(wh['id']),
                icon: const Icon(Icons.close_rounded, color: AppColors.error),
                label: const Text('Отклонить', style: TextStyle(color: AppColors.error)),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _approveAddress(wh),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Одобрить'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
