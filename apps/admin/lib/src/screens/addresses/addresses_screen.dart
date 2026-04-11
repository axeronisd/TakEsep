import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Карта-песочница для управления адресами.
/// Тайлы 2GIS как ориентир. Клик → добавляет точку → редактируем улицу/дом.
class AddressesScreen extends ConsumerStatefulWidget {
  const AddressesScreen({super.key});

  @override
  ConsumerState<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends ConsumerState<AddressesScreen> {
  final _supabase = Supabase.instance.client;
  final _mapController = MapController();

  List<Map<String, dynamic>> _addresses = [];
  Map<String, dynamic>? _selectedAddress;
  bool _loading = true;
  String _search = '';
  String _filterStatus = ''; // '', 'pending', 'verified'

  // Edit controllers
  final _streetC = TextEditingController();
  final _houseC = TextEditingController();
  final _buildingC = TextEditingController();
  final _cityC = TextEditingController(text: 'Бишкек');
  final _districtC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  @override
  void dispose() {
    _streetC.dispose();
    _houseC.dispose();
    _buildingC.dispose();
    _cityC.dispose();
    _districtC.dispose();
    super.dispose();
  }

  // ═══ Data ═══

  Future<void> _loadAddresses() async {
    setState(() => _loading = true);
    try {
      final data = await _supabase
          .from('addresses')
          .select()
          .order('created_at', ascending: false)
          .limit(2000);
      setState(() {
        _addresses = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('⚠️ Load addresses: $e');
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredAddresses {
    var list = _addresses;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((a) {
        final street = (a['street'] as String? ?? '').toLowerCase();
        final house = (a['house_number'] as String? ?? '').toLowerCase();
        return street.contains(q) || house.contains(q);
      }).toList();
    }
    if (_filterStatus == 'pending') {
      list = list.where((a) => a['verified'] != true).toList();
    } else if (_filterStatus == 'verified') {
      list = list.where((a) => a['verified'] == true).toList();
    }
    return list;
  }

  int get _pendingCount => _addresses.where((a) => a['verified'] != true).length;
  int get _verifiedCount => _addresses.where((a) => a['verified'] == true).length;

  void _selectAddress(Map<String, dynamic> addr) {
    setState(() {
      _selectedAddress = addr;
      _streetC.text = addr['street'] ?? '';
      _houseC.text = addr['house_number'] ?? '';
      _buildingC.text = addr['building_name'] ?? '';
      _cityC.text = addr['city'] ?? 'Бишкек';
      _districtC.text = addr['district'] ?? '';
    });

    // Center map on selected address
    final lat = (addr['lat'] as num?)?.toDouble();
    final lng = (addr['lng'] as num?)?.toDouble();
    if (lat != null && lng != null) {
      _mapController.move(LatLng(lat, lng), 18);
    }
  }

  void _onMapTap(TapPosition tapPos, LatLng point) {
    // Create new address at tap point
    setState(() {
      _selectedAddress = {
        '_isNew': true,
        'lat': point.latitude,
        'lng': point.longitude,
        'street': '',
        'house_number': '',
        'city': 'Бишкек',
        'verified': false,
      };
      _streetC.clear();
      _houseC.clear();
      _buildingC.clear();
      _cityC.text = 'Бишкек';
      _districtC.clear();
    });
  }

  Future<void> _saveAddress() async {
    if (_selectedAddress == null) return;
    if (_streetC.text.trim().isEmpty) {
      _showSnack('Введите название улицы');
      return;
    }

    final data = {
      'street': _streetC.text.trim(),
      'house_number': _houseC.text.trim().isEmpty ? null : _houseC.text.trim(),
      'building_name': _buildingC.text.trim().isEmpty ? null : _buildingC.text.trim(),
      'city': _cityC.text.trim(),
      'district': _districtC.text.trim().isEmpty ? null : _districtC.text.trim(),
      'lat': _selectedAddress!['lat'],
      'lng': _selectedAddress!['lng'],
      'verified': true,
    };

    try {
      if (_selectedAddress!['_isNew'] == true) {
        await _supabase.from('addresses').insert(data);
        _showSnack('Адрес добавлен', isSuccess: true);
      } else {
        await _supabase
            .from('addresses')
            .update(data)
            .eq('id', _selectedAddress!['id']);
        _showSnack('Адрес обновлён', isSuccess: true);
      }
      setState(() => _selectedAddress = null);
      _loadAddresses();
    } catch (e) {
      _showSnack('Ошибка: $e');
    }
  }

  Future<void> _deleteAddress() async {
    if (_selectedAddress == null || _selectedAddress!['_isNew'] == true) {
      setState(() => _selectedAddress = null);
      return;
    }

    try {
      await _supabase
          .from('addresses')
          .delete()
          .eq('id', _selectedAddress!['id']);
      _showSnack('Адрес удалён', isSuccess: true);
      setState(() => _selectedAddress = null);
      _loadAddresses();
    } catch (e) {
      _showSnack('Ошибка: $e');
    }
  }

  Future<void> _verifyAddress(Map<String, dynamic> addr) async {
    try {
      final newVal = !(addr['verified'] == true);
      await _supabase
          .from('addresses')
          .update({'verified': newVal})
          .eq('id', addr['id']);
      _loadAddresses();
    } catch (e) {
      _showSnack('Ошибка: $e');
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isSuccess ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
      duration: const Duration(seconds: 2),
    ));
  }

  // ═══ UI ═══

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 720;
    if (isMobile) return _buildMobileLayout();
    return _buildDesktopLayout();
  }

  // ── Mobile: full-screen map + draggable bottom sheet ──
  Widget _buildMobileLayout() {
    const cardBg = Color(0xFF1A1A3E);
    const accent = Color(0xFF2ECC71);
    const purple = Color(0xFFA29BFE);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F23),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(42.8746, 74.5698),
              initialZoom: 14, minZoom: 4, maxZoom: 19,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.takesep.admin',
                maxZoom: 19,
              ),
              _buildMarkerLayer(accent, purple),
            ],
          ),
          // Top bar
          Positioned(
            top: 8, left: 8, right: 8,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cardBg.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.map_rounded, color: accent, size: 20),
                    const SizedBox(width: 8),
                    const Text('Адреса', style: TextStyle(
                        color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 10),
                    _badge('$_verifiedCount', accent),
                    const SizedBox(width: 6),
                    _badge('$_pendingCount', Colors.orange),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 18),
                      onPressed: _loadAddresses,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Bottom sheet
          DraggableScrollableSheet(
            initialChildSize: 0.12, minChildSize: 0.08, maxChildSize: 0.65,
            builder: (context, sc) {
              return Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 15)],
                ),
                child: _selectedAddress != null
                    ? _buildMobileEditor(sc)
                    : _buildMobileAddressList(sc),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMobileAddressList(ScrollController sc) {
    final filtered = _filteredAddresses;
    return ListView(
      controller: sc,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Center(child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
        )),
        TextField(
          onChanged: (v) => setState(() => _search = v),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Поиск адреса...', hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
            prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 18),
            filled: true, fillColor: const Color(0xFF12122B),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          _filterTab('Все', '', filtered.length),
          const SizedBox(width: 6),
          _filterTab('Ожидают', 'pending', _pendingCount),
          const SizedBox(width: 6),
          _filterTab('Готово', 'verified', _verifiedCount),
        ]),
        const SizedBox(height: 10),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF2ECC71))))
        else if (filtered.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Нет адресов', style: TextStyle(color: Colors.grey[500]))))
        else
          ...filtered.map((addr) {
            final verified = addr['verified'] == true;
            return GestureDetector(
              onTap: () => _selectAddress(addr),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF12122B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF2A2A4E)),
                ),
                child: Row(children: [
                  Icon(verified ? Icons.check_circle : Icons.pending_actions_rounded,
                      color: verified ? const Color(0xFF2ECC71) : Colors.orange, size: 16),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${addr['street'] ?? '?'} ${addr['house_number'] ?? ''}',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  IconButton(
                    icon: Icon(verified ? Icons.verified_rounded : Icons.check_circle_outline_rounded,
                        color: verified ? const Color(0xFF2ECC71) : Colors.grey[600], size: 18),
                    onPressed: () => _verifyAddress(addr),
                    padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                  ),
                ]),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildMobileEditor(ScrollController sc) {
    return ListView(
      controller: sc,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Center(child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
        )),
        Row(children: [
          Icon(_selectedAddress!['_isNew'] == true ? Icons.add_location_rounded : Icons.edit_location_rounded,
              color: const Color(0xFF2ECC71), size: 20),
          const SizedBox(width: 8),
          Text(_selectedAddress!['_isNew'] == true ? 'Новая точка' : 'Редактировать',
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
              onPressed: () => setState(() => _selectedAddress = null)),
        ]),
        const SizedBox(height: 8),
        _editField(_streetC, 'Улица *', Icons.signpost_rounded),
        const SizedBox(height: 10),
        _editField(_houseC, 'Дом №', Icons.home_rounded),
        const SizedBox(height: 10),
        _editField(_buildingC, 'Здание', Icons.business_rounded),
        const SizedBox(height: 10),
        _editField(_cityC, 'Город', Icons.location_city_rounded),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 44,
          child: ElevatedButton.icon(
            onPressed: _saveAddress,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text(_selectedAddress!['_isNew'] == true ? 'Добавить' : 'Сохранить'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2ECC71),
                foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          ),
        ),
        if (_selectedAddress!['_isNew'] != true) ...[
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, height: 44,
            child: OutlinedButton.icon(
              onPressed: _deleteAddress,
              icon: const Icon(Icons.delete_rounded, size: 16),
              label: const Text('Удалить'),
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFE74C3C),
                  side: const BorderSide(color: Color(0xFFE74C3C)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
        ],
      ],
    );
  }

  MarkerLayer _buildMarkerLayer(Color accent, Color purple) {
    return MarkerLayer(markers: [
      ..._filteredAddresses.where((a) => a['lat'] != null && a['lng'] != null).map((a) {
        final lat = (a['lat'] as num).toDouble();
        final lng = (a['lng'] as num).toDouble();
        final verified = a['verified'] == true;
        final isSelected = _selectedAddress?['id'] == a['id'];
        return Marker(
          point: LatLng(lat, lng), width: isSelected ? 44 : 32, height: isSelected ? 44 : 32,
          child: GestureDetector(
            onTap: () => _selectAddress(a),
            child: Container(
              decoration: BoxDecoration(
                color: verified ? accent : Colors.orange,
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: isSelected ? 3 : 0),
                boxShadow: [BoxShadow(color: (verified ? accent : Colors.orange).withValues(alpha: 0.4), blurRadius: 6)],
              ),
              child: Center(child: Text(a['house_number'] ?? '?',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800), textAlign: TextAlign.center)),
            ),
          ),
        );
      }),
      if (_selectedAddress?['_isNew'] == true)
        Marker(
          point: LatLng((_selectedAddress!['lat'] as num).toDouble(), (_selectedAddress!['lng'] as num).toDouble()),
          width: 44, height: 44,
          child: Container(
            decoration: BoxDecoration(
              color: purple, shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [BoxShadow(color: purple.withValues(alpha: 0.5), blurRadius: 10)],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
          ),
        ),
    ]);
  }

  // ── Desktop: original 3-panel layout ──
  Widget _buildDesktopLayout() {
    const bg = Color(0xFF0F0F23);
    const cardBg = Color(0xFF1A1A3E);
    const border = Color(0xFF2A2A4E);
    const accent = Color(0xFF2ECC71);
    const purple = Color(0xFFA29BFE);
    final filtered = _filteredAddresses;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Row(
              children: [
                const Icon(Icons.map_rounded, color: accent, size: 26),
                const SizedBox(width: 10),
                const Text('Карта адресов', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(width: 16),
                _badge('$_verifiedCount', accent),
                const SizedBox(width: 8),
                _badge('$_pendingCount', Colors.orange),
                const Spacer(),
                IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20), tooltip: 'Обновить', onPressed: _loadAddresses),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 340,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: Column(children: [
                          TextField(
                            onChanged: (v) => setState(() => _search = v),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Поиск...', hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                              prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 18),
                              filled: true, fillColor: cardBg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(children: [
                            _filterTab('Все', '', filtered.length),
                            const SizedBox(width: 6),
                            _filterTab('Ожидают', 'pending', _pendingCount),
                            const SizedBox(width: 6),
                            _filterTab('Готово', 'verified', _verifiedCount),
                          ]),
                        ]),
                      ),
                      Expanded(
                        child: _loading
                            ? const Center(child: CircularProgressIndicator(color: accent))
                            : filtered.isEmpty
                                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.location_off_rounded, size: 40, color: Colors.grey[700]),
                                    const SizedBox(height: 8),
                                    Text('Нет адресов', style: TextStyle(color: Colors.grey[600])),
                                  ]))
                                : ListView.builder(
                                    itemCount: filtered.length,
                                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                    itemBuilder: (_, i) {
                                      final addr = filtered[i];
                                      final isSelected = _selectedAddress?['id'] == addr['id'];
                                      final verified = addr['verified'] == true;
                                      return GestureDetector(
                                        onTap: () => _selectAddress(addr),
                                        child: Container(
                                          margin: const EdgeInsets.only(bottom: 6),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isSelected ? accent.withValues(alpha: 0.12) : cardBg,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: isSelected ? accent : border, width: isSelected ? 1.5 : 0.5),
                                          ),
                                          child: Row(children: [
                                            Container(width: 32, height: 32,
                                              decoration: BoxDecoration(
                                                color: verified ? accent.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(8)),
                                              child: Icon(verified ? Icons.check_circle : Icons.pending_actions_rounded,
                                                  color: verified ? accent : Colors.orange, size: 16)),
                                            const SizedBox(width: 10),
                                            Expanded(child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('${addr['street'] ?? '?'} ${addr['house_number'] ?? ''}',
                                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                                if (addr['building_name'] != null && addr['building_name'].toString().isNotEmpty)
                                                  Text(addr['building_name'], style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                              ],
                                            )),
                                            IconButton(
                                              icon: Icon(verified ? Icons.verified_rounded : Icons.check_circle_outline_rounded,
                                                  color: verified ? accent : Colors.grey[600], size: 18),
                                              tooltip: verified ? 'Снять верификацию' : 'Верифицировать',
                                              onPressed: () => _verifyAddress(addr)),
                                          ]),
                                        ),
                                      );
                                    }),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(initialCenter: const LatLng(42.8746, 74.5698), initialZoom: 14, minZoom: 4, maxZoom: 19, onTap: _onMapTap),
                      children: [
                        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.takesep.admin', maxZoom: 19),
                        _buildMarkerLayer(accent, purple),
                      ],
                    ),
                    Positioned(top: 12, left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: cardBg.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(10)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.touch_app_rounded, color: purple, size: 16),
                          const SizedBox(width: 6),
                          Text('Кликните на карту для добавления адреса', style: TextStyle(color: Colors.grey[300], fontSize: 12)),
                        ]),
                      ),
                    ),
                  ]),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: _selectedAddress != null ? 300 : 0,
                  child: _selectedAddress != null
                      ? Container(
                          color: cardBg,
                          child: Column(children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: border, width: 0.5))),
                              child: Row(children: [
                                Icon(_selectedAddress!['_isNew'] == true ? Icons.add_location_rounded : Icons.edit_location_rounded, color: accent, size: 20),
                                const SizedBox(width: 8),
                                Text(_selectedAddress!['_isNew'] == true ? 'Новая точка' : 'Редактировать',
                                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                                const Spacer(),
                                IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                                    onPressed: () => setState(() => _selectedAddress = null)),
                              ]),
                            ),
                            Container(
                              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: const Color(0xFF0F0F23), borderRadius: BorderRadius.circular(8)),
                              child: Row(children: [
                                Icon(Icons.gps_fixed_rounded, color: Colors.grey[500], size: 14),
                                const SizedBox(width: 8),
                                Text('${(_selectedAddress!['lat'] as num?)?.toStringAsFixed(6)}, ${(_selectedAddress!['lng'] as num?)?.toStringAsFixed(6)}',
                                    style: TextStyle(color: Colors.grey[400], fontSize: 11, fontFamily: 'monospace')),
                              ]),
                            ),
                            Expanded(child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Column(children: [
                                _editField(_streetC, 'Улица *', Icons.signpost_rounded),
                                const SizedBox(height: 10),
                                _editField(_houseC, 'Дом №', Icons.home_rounded),
                                const SizedBox(height: 10),
                                _editField(_buildingC, 'Здание', Icons.business_rounded),
                                const SizedBox(height: 10),
                                _editField(_cityC, 'Город', Icons.location_city_rounded),
                                const SizedBox(height: 10),
                                _editField(_districtC, 'Район', Icons.map_rounded),
                              ]),
                            )),
                            Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                              SizedBox(width: double.infinity, height: 44,
                                child: ElevatedButton.icon(
                                  onPressed: _saveAddress,
                                  icon: const Icon(Icons.check_rounded, size: 18),
                                  label: Text(_selectedAddress!['_isNew'] == true ? 'Добавить' : 'Сохранить'),
                                  style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                )),
                              const SizedBox(height: 8),
                              if (_selectedAddress!['_isNew'] != true)
                                SizedBox(width: double.infinity, height: 44,
                                  child: OutlinedButton.icon(
                                    onPressed: _deleteAddress,
                                    icon: const Icon(Icons.delete_rounded, size: 16),
                                    label: const Text('Удалить'),
                                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFE74C3C),
                                        side: const BorderSide(color: Color(0xFFE74C3C)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                  )),
                            ])),
                          ]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══ Widgets ═══

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Widget _filterTab(String label, String value, int count) {
    final isActive = _filterStatus == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filterStatus = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF2ECC71).withValues(alpha: 0.15)
                : const Color(0xFF1A1A3E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF2ECC71)
                  : const Color(0xFF2A2A4E),
              width: isActive ? 1 : 0.5,
            ),
          ),
          child: Center(
            child: Text(
              '$label ($count)',
              style: TextStyle(
                color: isActive ? const Color(0xFF2ECC71) : Colors.grey[500],
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _editField(
      TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
        prefixIcon: Icon(icon, size: 16, color: Colors.grey[600]),
        filled: true,
        fillColor: const Color(0xFF12122B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2A2A4E)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2A2A4E)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF6C5CE7)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
