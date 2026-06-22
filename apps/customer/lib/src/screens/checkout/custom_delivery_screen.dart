import 'dart:math' as math;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../../theme/akjol_theme.dart';
import '../../services/route_service.dart';
import '../../providers/location_provider.dart';

class CustomDeliveryScreen extends ConsumerStatefulWidget {
  const CustomDeliveryScreen({super.key});

  @override
  ConsumerState<CustomDeliveryScreen> createState() => _CustomDeliveryScreenState();
}

class _CustomDeliveryScreenState extends ConsumerState<CustomDeliveryScreen> {
  final _supabase = Supabase.instance.client;
  final _mapController = MapController();
  final _noteCtrl = TextEditingController();
  final _addressACtrl = TextEditingController();
  final _addressBCtrl = TextEditingController();

  final _focusNodeA = FocusNode();
  final _focusNodeB = FocusNode();

  String? _addressA;
  LatLng? _coordsA;

  String? _addressB;
  LatLng? _coordsB;

  String _activeField = 'A'; // 'A' or 'B'
  static const double _sheetHeight = 310.0; // Fixed sheet height (approx 1/3 of screen)

  String _selectedTransport = 'bicycle';
  bool _needLoader = false;
  bool _loadingRoute = false;
  bool _loadingStores = true;
  bool _submitting = false;
  String? _error;

  List<LatLng> _routePoints = [];
  double _distanceKm = 0.0;
  int _durationMin = 0;

  Map<String, double> _transportRates = {
    'bicycle': 50.0,
    'scooter': 75.0,
  };

  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadRates();
    _loadStores();

    // Prefill Point A from locationProvider on startup
    final loc = ref.read(locationProvider);
    if (loc.lat != null && loc.lng != null) {
      _coordsA = LatLng(loc.lat!, loc.lng!);
      _addressA = loc.street ?? 'Мое местоположение';
      _addressACtrl.text = _addressA!;
    }

    // Listeners for manual typing autocomplete
    _addressACtrl.addListener(() {
      if (_activeField == 'A' && _addressACtrl.text != _addressA) {
        _onAddressSearchChanged(_addressACtrl.text);
      }
    });

    _addressBCtrl.addListener(() {
      if (_activeField == 'B' && _addressBCtrl.text != _addressB) {
        _onAddressSearchChanged(_addressBCtrl.text);
      }
    });

    // Auto toggle active field on focus
    _focusNodeA.addListener(() {
      if (_focusNodeA.hasFocus) {
        setState(() {
          _activeField = 'A';
        });
      }
    });

    _focusNodeB.addListener(() {
      if (_focusNodeB.hasFocus) {
        setState(() {
          _activeField = 'B';
        });
      }
    });
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _addressACtrl.dispose();
    _addressBCtrl.dispose();
    _focusNodeA.dispose();
    _focusNodeB.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadRates() async {
    try {
      final transportsData = await _supabase
          .from('transport_types')
          .select('id, price_per_km');
      final rates = {
        for (var t in transportsData)
          (t['id'] as String): (t['price_per_km'] as num).toDouble()
      };
      setState(() {
        _transportRates = rates;
      });
    } catch (e) {
      debugPrint('⚠️ Fetch transport rates error: $e');
    }
  }

  Future<void> _loadStores() async {
    try {
      final data = await _supabase
          .from('delivery_settings')
          .select('*, warehouses(name, address, latitude, longitude)')
          .eq('is_active', true);
      if (!mounted) return;
      setState(() {
        _stores = List<Map<String, dynamic>>.from(data);
        _loadingStores = false;
      });
    } catch (e) {
      debugPrint('⚠️ Fetch map stores error: $e');
      if (mounted) setState(() => _loadingStores = false);
    }
  }

  Future<void> _calculateRoute() async {
    if (_coordsA == null || _coordsB == null) return;

    setState(() => _loadingRoute = true);
    try {
      final profile = _selectedTransport == 'scooter' ? 'driving' : 'cycling';
      final routeInfo = await RouteService.getRouteWithInfo(_coordsA!, _coordsB!, profile: profile);
      setState(() {
        _routePoints = routeInfo.points;
        _distanceKm = routeInfo.distanceKm;
        _durationMin = routeInfo.durationMin;
        _loadingRoute = false;
        _error = null;
      });
      _fitRouteBounds();
    } catch (e) {
      setState(() {
        _routePoints = [_coordsA!, _coordsB!];
        _distanceKm = _haversineDistance(
          _coordsA!.latitude,
          _coordsA!.longitude,
          _coordsB!.latitude,
          _coordsB!.longitude,
        );
        _durationMin = 25;
        _loadingRoute = false;
      });
      _fitRouteBounds();
    }
  }

  void _fitRouteBounds() {
    if (_coordsA == null || _coordsB == null) return;
    final bounds = LatLngBounds(_coordsA!, _coordsB!);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.only(top: 80, bottom: _sheetHeight + 40, left: 50, right: 50),
      ),
    );
  }

  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0; // km
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double get _deliveryFee {
    final rate = _transportRates[_selectedTransport] ?? 50.0;
    final calculated = _distanceKm * rate;
    final baseFee = calculated < 50.0 ? 50.0 : calculated.roundToDouble();
    final extraLoader = (_selectedTransport == 'scooter' && _needLoader) ? 100.0 : 0.0;
    return baseFee + extraLoader;
  }

  double _calculateTempFee(String transport) {
    final rate = _transportRates[transport] ?? (transport == 'scooter' ? 75.0 : 50.0);
    final calculated = _distanceKm * rate;
    final baseFee = calculated < 50.0 ? 50.0 : calculated.roundToDouble();
    final extraLoader = (transport == 'scooter' && _needLoader) ? 100.0 : 0.0;
    return baseFee + extraLoader;
  }

  bool get _isReady => _coordsA != null && _coordsB != null && !_loadingRoute && !_submitting;

  Future<String> _getOrCreateCustomer(String userId) async {
    String phone = _supabase.auth.currentUser?.phone ??
        _supabase.auth.currentUser?.userMetadata?['phone'] as String? ??
        _supabase.auth.currentUser?.userMetadata?['phone_number'] as String? ??
        '';

    if (phone.trim().replaceAll(RegExp(r'[^0-9+]'), '').isEmpty) {
      try {
        final profile = await _supabase
            .from('user_profiles')
            .select('phone')
            .eq('id', userId)
            .maybeSingle();
        if (profile != null && profile['phone'] != null) {
          final profilePhone = profile['phone'].toString();
          if (profilePhone.trim().isNotEmpty) {
            phone = profilePhone;
          }
        }
      } catch (_) {}
    }

    final existing = await _supabase
        .from('customers')
        .select('id, phone')
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      try {
        final existingPhone = existing['phone']?.toString() ?? '';
        if (phone.isNotEmpty &&
            existingPhone.trim().replaceAll(RegExp(r'[^0-9+]'), '').isEmpty) {
          await _supabase
              .from('customers')
              .update({'phone': phone})
              .eq('id', existing['id']);
        }
      } catch (_) {}
      return existing['id'] as String;
    }

    final user = _supabase.auth.currentUser;
    final name = user?.userMetadata?['name'] ??
        user?.userMetadata?['full_name'] ??
        user?.email ??
        'Клиент';

    final newCustomer = await _supabase
        .from('customers')
        .insert({
          'user_id': userId,
          'name': name,
          'phone': phone.isNotEmpty ? phone : '',
        })
        .select('id')
        .single();

    return newCustomer['id'] as String;
  }

  Future<void> _onSubmit() async {
    if (!_isReady) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Необходима авторизация');
      }

      // 1. Find the nearest active warehouse
      final activeSettings = await _supabase
          .from('delivery_settings')
          .select('warehouse_id, warehouses(id, latitude, longitude)')
          .eq('is_active', true);

      if ((activeSettings as List).isEmpty) {
        throw Exception('Нет доступных активных складов');
      }

      String? bestWhId;
      double minDistance = double.infinity;

      for (final s in activeSettings) {
        final w = s['warehouses'] as Map<String, dynamic>?;
        if (w == null) continue;
        final wLat = (w['latitude'] as num?)?.toDouble() ?? 0.0;
        final wLng = (w['longitude'] as num?)?.toDouble() ?? 0.0;
        final dist = _haversineDistance(_coordsA!.latitude, _coordsA!.longitude, wLat, wLng);
        if (dist < minDistance) {
          minDistance = dist;
          bestWhId = w['id'] as String;
        }
      }

      if (bestWhId == null) {
        final firstW = activeSettings.first['warehouses'] as Map<String, dynamic>?;
        bestWhId = firstW?['id'] as String?;
      }

      if (bestWhId == null) {
        throw Exception('Не удалось определить активный склад');
      }

      // 2. Lookup customer ID
      final customerId = await _getOrCreateCustomer(userId);

      // 3. Prepare Dummy items
      final dummyItems = [
        {
          'product_id': '00000000-0000-0000-0000-000000000000',
          'name': 'Свободная доставка',
          'quantity': 1,
          'unit_price': 0.0,
          'total': 0.0,
        }
      ];

      // Form customer note with loader details
      String finalNote = _noteCtrl.text.trim();
      if (_selectedTransport == 'scooter' && _needLoader) {
        finalNote = finalNote.isEmpty
            ? '[Грузчик: Нужен, +100 сом курьеру при получении]'
            : '$finalNote\n[Грузчик: Нужен, +100 сом курьеру при получении]';
      }

      // 4. Create initial customer order
      final result = await _supabase.rpc(
        'create_customer_order',
        params: {
          'p_warehouse_id': bestWhId,
          'p_customer_id': customerId,
          'p_requested_transport': _selectedTransport,
          'p_delivery_address': _addressB ?? '',
          'p_delivery_lat': _coordsB!.latitude,
          'p_delivery_lng': _coordsB!.longitude,
          'p_delivery_fee': _deliveryFee,
          'p_payment_method': 'prepaid',
          'p_customer_note': finalNote,
          'p_items': dummyItems,
          'p_distance_km': _distanceKm,
        },
      );

      final orderData = result as Map<String, dynamic>;
      final orderId = orderData['id'] ?? orderData['order_id'];

      if (orderId == null) {
        throw Exception('Не удалось создать заказ');
      }

      // 5. Update order to set freelance coordinates and types directly
      await _supabase.from('delivery_orders').update({
        'pickup_address': _addressA ?? '',
        'pickup_lat': _coordsA!.latitude,
        'pickup_lng': _coordsA!.longitude,
        'delivery_type': 'freelance',
        'delivery_fee': _deliveryFee,
        'total': _deliveryFee,
      }).eq('id', orderId);

      // 6. Insert Order Items via RPC
      try {
        await _supabase.rpc(
          'insert_order_items',
          params: {
            'p_order_id': orderId,
            'p_items': dummyItems,
          },
        );
      } catch (rpcErr) {
        debugPrint('⚠️ RPC insert_order_items fallback: $rpcErr');
        await _supabase.from('delivery_order_items').insert({
          'order_id': orderId,
          'product_id': '00000000-0000-0000-0000-000000000000',
          'name': 'Свободная доставка',
          'quantity': 1,
          'unit_price': 0.0,
          'total': 0.0,
        });
      }

      if (mounted) {
        final orderNumber = (orderData['order_number'] ?? '')?.toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Заказ $orderNumber на доставку оформлен!'),
          backgroundColor: AkJolTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        context.go('/order/$orderId');
      }
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = 'Ошибка создания заказа: $e';
      });
    }
  }

  // ═══════════════════════════════════════
  // Address Geocoding & Autocomplete
  // ═══════════════════════════════════════

  Future<void> _handleMapTap(TapPosition tapPosition, LatLng point) async {
    final field = _activeField;
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json'
        '&lat=${point.latitude}'
        '&lon=${point.longitude}'
        '&zoom=19'
        '&addressdetails=1'
        '&accept-language=ru,ky',
      );

      final response = await http.get(url, headers: {
        'User-Agent': 'AkJol-SuperApp/1.0',
      });

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final addr = data['address'] as Map<String, dynamic>?;

        String address = 'Неизвестный адрес';
        if (addr != null) {
          final road = addr['road'] ?? addr['pedestrian'] ?? addr['footway']
              ?? addr['path'] ?? addr['residential'] ?? addr['tertiary'] ?? '';
          final houseNumber = addr['house_number'] ?? '';
          final city = addr['city'] ?? addr['town'] ?? addr['village'] ?? '';

          String street = road.toString();
          if (street.isNotEmpty && houseNumber.toString().isNotEmpty) {
            street = '$street, $houseNumber';
          }

          final parts = <String>[];
          if (street.isNotEmpty) parts.add(street);
          if (city.toString().isNotEmpty) parts.add(city.toString());

          address = parts.isNotEmpty
              ? parts.join(', ')
              : data['display_name'] as String? ?? 'Неизвестный адрес';
        }

        setState(() {
          if (field == 'A') {
            _addressA = address;
            _coordsA = point;
            _addressACtrl.text = address;
          } else {
            _addressB = address;
            _coordsB = point;
            _addressBCtrl.text = address;
          }
        });

        _calculateRoute();
      }
    } catch (e) {
      debugPrint('⚠️ Nominatim tap geocode error: $e');
    }
  }

  void _onAddressSearchChanged(String val) {
    _searchDebounce?.cancel();
    if (val.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _executeAddressSearch(val.trim());
    });
  }

  Future<void> _executeAddressSearch(String query) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?format=json'
        '&q=$query'
        '&countrycodes=kg'
        '&limit=5'
        '&addressdetails=1'
        '&accept-language=ru,ky',
      );

      final response = await http.get(url, headers: {
        'User-Agent': 'AkJol-SuperApp/1.0',
      });

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        setState(() {
          _searchResults = data.map((item) {
            final addr = item['address'] as Map<String, dynamic>? ?? {};
            final road = addr['road'] ?? addr['pedestrian'] ?? addr['footway']
                ?? addr['path'] ?? addr['residential'] ?? addr['tertiary'] ?? addr['secondary'] ?? '';
            final houseNumber = (addr['house_number'] ?? '').toString();
            final city = addr['city'] ?? addr['town'] ?? addr['village'] ?? '';

            String street = road.toString();
            String fullLabel = street;
            if (houseNumber.isNotEmpty) {
              fullLabel = '$street, $houseNumber';
            }
            if (city.toString().isNotEmpty) {
              fullLabel = '$fullLabel, $city';
            } else {
              fullLabel = '$fullLabel, ${item['display_name']}';
            }

            return {
              'display_name': item['display_name'],
              'street': street,
              'house_number': houseNumber,
              'city': city,
              'lat': double.tryParse(item['lat']?.toString() ?? '') ?? 0.0,
              'lng': double.tryParse(item['lon']?.toString() ?? '') ?? 0.0,
              'full_label': fullLabel,
              'street_and_house': houseNumber.isNotEmpty ? '$street, $houseNumber' : street,
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('⚠️ Nominatim search suggestions error: $e');
    }
  }

  void _selectSuggestion(Map<String, dynamic> item) {
    _focusNodeA.unfocus();
    _focusNodeB.unfocus();
    
    setState(() {
      _searchResults = [];
      final lat = item['lat'] as double;
      final lng = item['lng'] as double;
      final address = item['street_and_house'] as String;

      if (_activeField == 'A') {
        _addressA = address;
        _coordsA = LatLng(lat, lng);
        _addressACtrl.text = address;
      } else {
        _addressB = address;
        _coordsB = LatLng(lat, lng);
        _addressBCtrl.text = address;
      }
    });

    _mapController.move(LatLng(item['lat'] as double, item['lng'] as double), 16);
    _calculateRoute();
  }

  Future<void> _setCurrentLocation() async {
    final notifier = ref.read(locationProvider.notifier);
    await notifier.determinePosition();
    final updatedLoc = ref.read(locationProvider);
    if (updatedLoc.lat != null && updatedLoc.lng != null) {
      final pt = LatLng(updatedLoc.lat!, updatedLoc.lng!);
      _mapController.move(pt, 16);

      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse'
          '?format=json'
          '&lat=${pt.latitude}'
          '&lon=${pt.longitude}'
          '&zoom=19'
          '&addressdetails=1'
          '&accept-language=ru,ky',
        );

        final response = await http.get(url, headers: {
          'User-Agent': 'AkJol-SuperApp/1.0',
        });

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final addr = data['address'] as Map<String, dynamic>?;

          String address = 'Мое местоположение';
          if (addr != null) {
            final road = addr['road'] ?? addr['pedestrian'] ?? addr['footway']
                ?? addr['path'] ?? addr['residential'] ?? addr['tertiary'] ?? '';
            final houseNumber = addr['house_number'] ?? '';
            final city = addr['city'] ?? addr['town'] ?? addr['village'] ?? '';

            String street = road.toString();
            if (street.isNotEmpty && houseNumber.toString().isNotEmpty) {
              street = '$street, $houseNumber';
            }

            final parts = <String>[];
            if (street.isNotEmpty) parts.add(street);
            if (city.toString().isNotEmpty) parts.add(city.toString());

            address = parts.isNotEmpty
                ? parts.join(', ')
                : data['display_name'] as String? ?? 'Мое местоположение';
          }

          setState(() {
            if (_activeField == 'A') {
              _addressA = address;
              _coordsA = pt;
              _addressACtrl.text = address;
            } else {
              _addressB = address;
              _coordsB = pt;
              _addressBCtrl.text = address;
            }
          });
          _calculateRoute();
        }
      } catch (e) {
        debugPrint('⚠️ GPS reverse geocoding error: $e');
        setState(() {
          if (_activeField == 'A') {
            _addressA = 'Текущее местоположение';
            _coordsA = pt;
            _addressACtrl.text = 'Текущее местоположение';
          } else {
            _addressB = 'Текущее местоположение';
            _coordsB = pt;
            _addressBCtrl.text = 'Текущее местоположение';
          }
        });
        _calculateRoute();
      }
    }
  }

  void _showStoreSelectionSheet(Map<String, dynamic> store) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = store['warehouses']?['name'] ?? 'Магазин';
    final address = store['warehouses']?['address'] ?? store['address'] ?? '';
    final lat = (store['warehouses']?['latitude'] as num?)?.toDouble() ?? (store['latitude'] as num?)?.toDouble();
    final lng = (store['warehouses']?['longitude'] as num?)?.toDouble() ?? (store['longitude'] as num?)?.toDouble();

    if (lat == null || lng == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
        final textSecondary = isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary),
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: TextStyle(fontSize: 13, color: textSecondary),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00B15E).withValues(alpha: 0.15),
                          foregroundColor: const Color(0xFF00B15E),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _coordsA = LatLng(lat, lng);
                            _addressA = address.isNotEmpty ? address : name;
                            _addressACtrl.text = _addressA!;
                          });
                          _calculateRoute();
                        },
                        icon: const Icon(Icons.radio_button_checked_rounded, color: Colors.green),
                        label: const Text('Отсюда (Точка А)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.withValues(alpha: 0.15),
                          foregroundColor: Colors.blue,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _coordsB = LatLng(lat, lng);
                            _addressB = address.isNotEmpty ? address : name;
                            _addressBCtrl.text = _addressB!;
                          });
                          _calculateRoute();
                        },
                        icon: const Icon(Icons.location_on_rounded, color: Colors.blue),
                        label: const Text('Сюда (Точка Б)'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════
  // Build
  // ═══════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(locationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D1117) : Colors.white;
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final border = isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);
    final text = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
    final fieldBg = isDark ? const Color(0xFF21262D) : const Color(0xFFF3F4F6);

    // Initial center on current position or Bishkek
    final initialCenter = _coordsA ?? ((location.lat != null && location.lng != null)
        ? LatLng(location.lat!, location.lng!)
        : const LatLng(42.8746, 74.5698));

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ── 1. Map ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 14.0,
              minZoom: 4,
              maxZoom: 19,
              onTap: (tapPos, pt) => _handleMapTap(tapPos, pt),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.takesep.customer',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: AkJolTheme.primary,
                      strokeWidth: 4.5,
                    ),
                  ],
                ),
              // Markers for Point A and Point B
              MarkerLayer(
                markers: [
                  if (_coordsA != null)
                    Marker(
                      point: _coordsA!,
                      width: 32, height: 32,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'А',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_coordsB != null)
                    Marker(
                      point: _coordsB!,
                      width: 32, height: 32,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'Б',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              // Markers for Stores and Warehouses
              if (!_loadingStores)
                MarkerLayer(
                  markers: _stores.map((store) {
                    final lat = (store['warehouses']?['latitude'] as num?)?.toDouble() ?? (store['latitude'] as num?)?.toDouble();
                    final lng = (store['warehouses']?['longitude'] as num?)?.toDouble() ?? (store['longitude'] as num?)?.toDouble();
                    if (lat == null || lng == null) return null;
                    final logoUrl = store['logo_url'] as String?;

                    return Marker(
                      point: LatLng(lat, lng),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => _showStoreSelectionSheet(store),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF161B22) : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AkJolTheme.primary, width: 2.0),
                            boxShadow: [
                              BoxShadow(
                                color: AkJolTheme.primary.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            image: logoUrl != null && logoUrl.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(logoUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: logoUrl == null || logoUrl.isEmpty
                              ? const Icon(Icons.storefront_rounded, color: AkJolTheme.primary, size: 18)
                              : null,
                        ),
                      ),
                    );
                  }).whereType<Marker>().toList(),
                ),
            ],
          ),

          // ── 2. Top Hint Indicator ──
          _buildTopHint(),

          // ── 3. Back Button ──
          _buildFloatingBackButton(isDark, text, cardBg),

          // ── 4. My Location (GPS) Button ──
          _buildMyLocationButton(isDark, cardBg),

          // ── 5. Search Suggestions Overlay ──
          _buildSuggestionsOverlay(isDark, cardBg, text, muted),

          // ── 6. Fixed Bottom Sheet Panel (1/3 of the screen) ──
          _buildFixedSheet(isDark, bg, border, text, muted, fieldBg),

          // Loading route overlay
          if (_loadingRoute)
            Container(
              color: Colors.black.withValues(alpha: 0.2),
              child: const Center(
                child: CircularProgressIndicator(color: AkJolTheme.primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopHint() {
    if (_coordsA != null && _coordsB != null) return const SizedBox.shrink();

    final isAActive = _activeField == 'A';
    final textStr = isAActive ? 'Укажите на карте Точку А (Откуда)' : 'Укажите на карте Точку Б (Куда)';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: 0,
      left: 68,
      right: 68,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
              ),
            ],
            border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0), width: 0.5),
          ),
          child: Text(
            textStr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingBackButton(bool isDark, Color text, Color cardBg) {
    return Positioned(
      left: 16,
      top: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: cardBg,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: text),
            onPressed: () => context.go('/'),
          ),
        ),
      ),
    );
  }

  Widget _buildMyLocationButton(bool isDark, Color cardBg) {
    return Positioned(
      right: 16,
      bottom: _sheetHeight + 16,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          icon: const Icon(Icons.near_me_rounded, color: AkJolTheme.primary, size: 22),
          onPressed: _setCurrentLocation,
        ),
      ),
    );
  }

  Widget _buildSuggestionsOverlay(bool isDark, Color bg, Color text, Color muted) {
    if (_searchResults.isEmpty) return const SizedBox.shrink();
    return Positioned(
      left: 16,
      right: 16,
      bottom: _sheetHeight + 16,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 200),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
          border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0), width: 0.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: _searchResults.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
            ),
            itemBuilder: (context, index) {
              final suggestion = _searchResults[index];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.location_on_rounded, color: AkJolTheme.primary, size: 16),
                title: Text(
                  suggestion['full_label'] ?? '',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: text),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _selectSuggestion(suggestion),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFixedSheet(bool isDark, Color bg, Color border, Color text, Color muted, Color fieldBg) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: _sheetHeight,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.markunread_mailbox_rounded, color: Colors.red, size: 18),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Доставка',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: text,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Point A & Point B input cards
                      _buildAddressFieldsBlock(isDark, border, text, muted, fieldBg),
                      const SizedBox(height: 12),

                      // Transport Selection Horizontal Cards
                      _buildTransportSelectorHorizontal(isDark, border, text, muted),
                      const SizedBox(height: 12),

                      // Comment input field
                      _buildCommentInput(isDark, border, text, muted, fieldBg),
                    ],
                  ),
                ),
              ),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // Pinned Checkout Bar at the bottom
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: _buildCheckoutBar(isDark, border, text, muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressFieldsBlock(bool isDark, Color border, Color text, Color muted, Color fieldBg) {
    final activeBorderColor = AkJolTheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 0.5),
      ),
      padding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          // Vertical connector line
          Positioned(
            left: 17,
            top: 26,
            bottom: 26,
            child: Container(
              width: 1.5,
              color: muted.withValues(alpha: 0.3),
            ),
          ),

          Column(
            children: [
              // Point A
              GestureDetector(
                onTap: () {
                  setState(() {
                    _activeField = 'A';
                  });
                },
                child: Container(
                  color: Colors.transparent,
                  child: Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 13),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _activeField == 'A' ? activeBorderColor : border.withValues(alpha: 0.3),
                                width: _activeField == 'A' ? 1.5 : 0.5,
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: TextField(
                            controller: _addressACtrl,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: text),
                            focusNode: _focusNodeA,
                            decoration: InputDecoration(
                              hintText: 'Откуда (Точка А)',
                              hintStyle: TextStyle(color: muted, fontSize: 13),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            ),
                          ),
                        ),
                      ),
                      if (_addressACtrl.text.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.close_rounded, size: 16, color: muted),
                          onPressed: () {
                            setState(() {
                              _addressA = null;
                              _coordsA = null;
                              _addressACtrl.clear();
                              _routePoints = [];
                              _distanceKm = 0.0;
                              _durationMin = 0;
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Point B
              GestureDetector(
                onTap: () {
                  setState(() {
                    _activeField = 'B';
                  });
                },
                child: Container(
                  color: Colors.transparent,
                  child: Row(
                    children: [
                      Container(
                        width: 10, height: 10,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.all(Radius.circular(2)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _activeField == 'B' ? activeBorderColor : border.withValues(alpha: 0.3),
                                width: _activeField == 'B' ? 1.5 : 0.5,
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: TextField(
                            controller: _addressBCtrl,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: text),
                            focusNode: _focusNodeB,
                            decoration: InputDecoration(
                              hintText: 'Куда (Точка Б)',
                              hintStyle: TextStyle(color: muted, fontSize: 13),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            ),
                          ),
                        ),
                      ),
                      if (_addressBCtrl.text.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.close_rounded, size: 16, color: muted),
                          onPressed: () {
                            setState(() {
                              _addressB = null;
                              _coordsB = null;
                              _addressBCtrl.clear();
                              _routePoints = [];
                              _distanceKm = 0.0;
                              _durationMin = 0;
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransportSelectorHorizontal(bool isDark, Color border, Color text, Color muted) {
    final scooterSelected = _selectedTransport == 'scooter';
    final bikeSelected = _selectedTransport == 'bicycle';

    final bikeFee = _calculateTempFee('bicycle');
    final scooterFee = _calculateTempFee('scooter');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Тариф доставки',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: text),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Bicycle Card
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedTransport = 'bicycle');
                  _calculateRoute();
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bikeSelected
                        ? AkJolTheme.primary.withValues(alpha: 0.08)
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: bikeSelected ? AkJolTheme.primary : border.withValues(alpha: 0.3),
                      width: bikeSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: bikeSelected ? AkJolTheme.primary.withValues(alpha: 0.15) : muted.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_durationMin > 0 ? _durationMin : 15} мин',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: bikeSelected ? AkJolTheme.primary : muted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.electric_bike_rounded, color: bikeSelected ? AkJolTheme.primary : muted, size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Электровелосипед',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: text),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${bikeFee.toStringAsFixed(0)} сом',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: text),
                      ),
                      Text(
                        'Электровелик',
                        style: TextStyle(fontSize: 10, color: muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Scooter/Tricycle Card
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedTransport = 'scooter');
                  _calculateRoute();
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scooterSelected
                        ? AkJolTheme.primary.withValues(alpha: 0.08)
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scooterSelected ? AkJolTheme.primary : border.withValues(alpha: 0.3),
                      width: scooterSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: scooterSelected ? AkJolTheme.primary.withValues(alpha: 0.15) : muted.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_durationMin > 0 ? math.max(5, _durationMin - 5) : 7} мин',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: scooterSelected ? AkJolTheme.primary : muted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.two_wheeler_rounded, color: scooterSelected ? AkJolTheme.primary : muted, size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Электромуравей',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: text),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${scooterFee.toStringAsFixed(0)} сом',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: text),
                      ),
                      Text(
                        'Муравей',
                        style: TextStyle(fontSize: 10, color: muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        // Loader Option for Scooter
        if (scooterSelected) ...[
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: CheckboxListTile(
              value: _needLoader,
              onChanged: (val) {
                setState(() => _needLoader = val ?? false);
              },
              title: Text('Нужен грузчик (+100 сом)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: text)),
              subtitle: Text('Помощь в погрузке/разгрузке тяжелых вещей', style: TextStyle(fontSize: 11, color: muted)),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              activeColor: AkJolTheme.primary,
              dense: true,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCommentInput(bool isDark, Color border, Color text, Color muted, Color fieldBg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Комментарий курьеру',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: text),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _noteCtrl,
          decoration: InputDecoration(
            hintText: 'Что везем? Детали подъезда, контакты...',
            hintStyle: TextStyle(color: muted, fontSize: 12),
            filled: true, fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border, width: 0.5)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border, width: 0.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AkJolTheme.primary, width: 1.5)),
          ),
          style: TextStyle(fontSize: 13, color: text),
          maxLines: 2, minLines: 1,
        ),
      ],
    );
  }

  Widget _buildCheckoutBar(bool isDark, Color border, Color text, Color muted) {
    final fee = _calculateTempFee(_selectedTransport);
    return Row(
      children: [
        // Payment Method Chip
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border.withValues(alpha: 0.3), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.money_rounded, color: Colors.green, size: 20),
              const SizedBox(width: 6),
              Text(
                'Наличные',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: text),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // Order Button
        Expanded(
          child: SizedBox(
            height: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: _isReady && !_submitting
                    ? const LinearGradient(colors: [Color(0xFF00B15E), Color(0xFF10B981)])
                    : null,
                color: _isReady && !_submitting ? null
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(14),
                boxShadow: _isReady && !_submitting ? [BoxShadow(
                    color: const Color(0xFF00B15E).withValues(alpha: 0.3),
                    blurRadius: 10, offset: const Offset(0, 3))] : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _isReady && !_submitting ? _onSubmit : null,
                  child: Center(
                    child: _submitting
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.flash_on_rounded, size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                _isReady ? 'Заказать (${fee.toStringAsFixed(0)} сом)' : 'Выберите адреса',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
