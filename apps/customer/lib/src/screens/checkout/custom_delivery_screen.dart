import 'dart:math' as math;
import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart' as native_cp;
import 'package:flutter_native_contact_picker/model/contact.dart' as native_cp;
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
  final native_cp.FlutterNativeContactPicker _contactPicker = native_cp.FlutterNativeContactPicker();
  final _addressACtrl = TextEditingController();
  final _addressBCtrl = TextEditingController();
  final _senderPhoneCtrl = TextEditingController();
  final _recipientPhoneCtrl = TextEditingController();

  final _focusNodeA = FocusNode();
  final _focusNodeB = FocusNode();

  bool _acceptTerms = false;
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

    // Auto toggle active field on focus and trigger UI updates
    _focusNodeA.addListener(() {
      setState(() {
        if (_focusNodeA.hasFocus) {
          _activeField = 'A';
        }
      });
    });

    _focusNodeB.addListener(() {
      setState(() {
        if (_focusNodeB.hasFocus) {
          _activeField = 'B';
        }
      });
    });

    final user = _supabase.auth.currentUser;
    if (user != null) {
      if (user.phone != null && user.phone!.isNotEmpty) {
        _senderPhoneCtrl.text = user.phone!;
      }
      _loadCustomerPhone(user.id);
    }
  }

  Future<void> _loadCustomerPhone(String userId) async {
    try {
      final data = await _supabase
          .from('customers')
          .select('phone')
          .eq('user_id', userId)
          .maybeSingle();
      if (data != null && data['phone'] != null) {
        final phone = data['phone'] as String;
        if (phone.isNotEmpty && mounted) {
          setState(() {
            _senderPhoneCtrl.text = phone;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _addressACtrl.dispose();
    _addressBCtrl.dispose();
    _senderPhoneCtrl.dispose();
    _recipientPhoneCtrl.dispose();
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
      if (mounted) {
        setState(() {
          _transportRates = rates;
        });
      }
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
      if (!mounted) return;
      setState(() {
        _routePoints = routeInfo.points;
        _distanceKm = routeInfo.distanceKm;
        _durationMin = routeInfo.durationMin;
        _loadingRoute = false;
        _error = null;
      });
      _fitRouteBounds();
    } catch (e) {
      if (!mounted) return;
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

  void _swapAddresses() {
    setState(() {
      final tempCoords = _coordsA;
      final tempAddress = _addressA;
      final tempText = _addressACtrl.text;

      _coordsA = _coordsB;
      _addressA = _addressB;
      _addressACtrl.text = _addressBCtrl.text;

      _coordsB = tempCoords;
      _addressB = tempAddress;
      _addressBCtrl.text = tempText;
    });

    if (_coordsA != null && _coordsB != null) {
      _calculateRoute();
    } else {
      setState(() {
        _routePoints = [];
        _distanceKm = 0.0;
        _durationMin = 0;
      });
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

  Future<void> _pickContactForController(TextEditingController controller) async {
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    if (!isMobile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выбор контактов поддерживается только на мобильных устройствах'),
        ),
      );
      return;
    }
    
    try {
      final native_cp.Contact? contact = await _contactPicker.selectPhoneNumber();
      if (contact != null) {
        final phone = contact.selectedPhoneNumber ?? (contact.phoneNumbers != null && contact.phoneNumbers!.isNotEmpty ? contact.phoneNumbers!.first : null);
        if (phone != null) {
          final cleanedPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
          setState(() {
            controller.text = cleanedPhone;
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking contact: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось выбрать контакт: $e'),
        ),
      );
    }
  }

  double get _deliveryFee {
    final rate = _transportRates[_selectedTransport] ?? (_selectedTransport == 'scooter' ? 75.0 : 50.0);
    final calculated = _distanceKm * rate;
    final minFee = _selectedTransport == 'scooter' ? 75.0 : 50.0;
    final baseFee = calculated < minFee ? minFee : calculated.roundToDouble();
    if (_selectedTransport == 'scooter' && _needLoader) {
      return (baseFee * 1.2).roundToDouble();
    }
    return baseFee;
  }

  double _calculateTempFee(String transport) {
    final rate = _transportRates[transport] ?? (transport == 'scooter' ? 75.0 : 50.0);
    final calculated = _distanceKm * rate;
    final minFee = transport == 'scooter' ? 75.0 : 50.0;
    final baseFee = calculated < minFee ? minFee : calculated.roundToDouble();
    if (transport == 'scooter' && _needLoader) {
      return (baseFee * 1.2).roundToDouble();
    }
    return baseFee;
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

    final senderPhone = _senderPhoneCtrl.text.trim();
    final recipientPhone = _recipientPhoneCtrl.text.trim();

    if (senderPhone.isEmpty) {
      setState(() => _error = 'Введите телефон отправителя');
      return;
    }
    if (recipientPhone.isEmpty) {
      setState(() => _error = 'Введите телефон получателя');
      return;
    }
    if (!_acceptTerms) {
      setState(() => _error = 'Необходимо принять условия публичной оферты');
      return;
    }

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
            ? '[Нужна помощь в выгрузке]'
            : '$finalNote\n[Нужна помощь в выгрузке]';
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
        'sender_phone': senderPhone,
        'recipient_phone': recipientPhone,
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
          content: Text(
            'Заказ $orderNumber на доставку оформлен!',
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.fixed,
        ));
        context.go('/order/$orderId');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Ошибка создания заказа: $e';
        });
      }
    }
  }

  // ═══════════════════════════════════════
  // Address Geocoding & Autocomplete
  // ═══════════════════════════════════════

  Future<void> _handleMapTap(TapPosition tapPosition, LatLng point) async {
    if (MediaQuery.of(context).viewInsets.bottom > 0) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
        final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
        final greenColor = isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
        final blueColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    address,
                    style: TextStyle(
                      fontSize: 14,
                      color: textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: greenColor.withValues(alpha: 0.12),
                          foregroundColor: greenColor,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: greenColor.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
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
                        icon: Icon(Icons.radio_button_checked_rounded, color: greenColor, size: 20),
                        label: const Text(
                          'Отсюда (Точка А)',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blueColor.withValues(alpha: 0.12),
                          foregroundColor: blueColor,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: blueColor.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
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
                        icon: Icon(Icons.location_on_rounded, color: blueColor, size: 20),
                        label: const Text(
                          'Сюда (Точка Б)',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
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
    final bg = isDark ? const Color(0xFF080809) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF121214) : Colors.white;
    final border = isDark ? const Color(0xFF1E1E22) : const Color(0xFFE2E8F0);
    final text = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final fieldBg = isDark ? const Color(0xFF1C1C1F) : const Color(0xFFF1F5F9);

    // Initial center on current position or Bishkek
    final initialCenter = _coordsA ?? ((location.lat != null && location.lng != null)
        ? LatLng(location.lat!, location.lng!)
        : const LatLng(42.8746, 74.5698));

    // Dynamic available height calculation to avoid overflow on small screens
    final isSearching = _searchResults.isNotEmpty && (_focusNodeA.hasFocus || _focusNodeB.hasFocus);
    final screenHeight = MediaQuery.of(context).size.height;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final padding = MediaQuery.of(context).padding;
    final availableHeight = screenHeight - viewInsets.bottom - padding.top - padding.bottom;
    
    final targetHeight = isSearching ? 360.0 : _sheetHeight;
    final sheetHeight = math.min(targetHeight, availableHeight - 16.0);

    return Scaffold(
      resizeToAvoidBottomInset: true,
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
          _buildMyLocationButton(isDark, cardBg, sheetHeight),

          // ── 5. Fixed Bottom Sheet Panel (1/3 of the screen) ──
          _buildFixedSheet(isDark, bg, border, text, muted, fieldBg, sheetHeight, isSearching),

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
    final cardBg = isDark ? const Color(0xFF121214) : Colors.white;
    final border = isDark ? const Color(0xFF1E1E22) : const Color(0xFFE2E8F0);
    final text = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    return Positioned(
      top: 0,
      left: 64,
      right: 64,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isAActive ? Colors.green : Colors.blue,
                  shape: isAActive ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: isAActive ? null : const BorderRadius.all(Radius.circular(2)),
                  boxShadow: [
                    BoxShadow(
                      color: (isAActive ? Colors.green : Colors.blue).withValues(alpha: 0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  textStr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: text,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingBackButton(bool isDark, Color text, Color cardBg) {
    final border = isDark ? const Color(0xFF1E1E22) : const Color(0xFFE2E8F0);
    return Positioned(
      left: 16,
      top: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: cardBg,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: text),
              onPressed: () => context.go('/'),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyLocationButton(bool isDark, Color cardBg, double sheetHeight) {
    final border = isDark ? const Color(0xFF1E1E22) : const Color(0xFFE2E8F0);
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Positioned(
      right: 16,
      bottom: sheetHeight + 16,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: cardBg,
          shape: BoxShape.circle,
          border: Border.all(color: border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: IconButton(
            icon: Icon(Icons.near_me_rounded, color: primaryColor, size: 20),
            onPressed: _setCurrentLocation,
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsList(bool isDark, Color text, Color muted) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          leading: const Icon(Icons.location_on_rounded, color: AkJolTheme.primary, size: 18),
          title: Text(
            suggestion['full_label'] ?? '',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: text),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _selectSuggestion(suggestion),
        );
      },
    );
  }

  Widget _buildFixedSheet(
    bool isDark,
    Color bg,
    Color border,
    Color text,
    Color muted,
    Color fieldBg,
    double sheetHeight,
    bool isSearching,
  ) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: sheetHeight,
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
              // Drag Handle Indicator
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: muted.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Text(
                        'Доставка',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: text,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Point A & Point B input cards
                      _buildAddressFieldsBlock(isDark, border, text, muted, fieldBg),
                      const SizedBox(height: 12),

                      if (isSearching) ...[
                        _buildSuggestionsList(isDark, text, muted),
                      ] else ...[
                        // Transport Selection Horizontal Cards
                        _buildTransportSelectorHorizontal(isDark, border, text, muted),
                        const SizedBox(height: 12),

                        // Comment input field
                        _buildCommentInput(isDark, border, text, muted, fieldBg),
                        const SizedBox(height: 12),
                        _buildSenderRecipientPhonesBlock(isDark, border, text, muted, fieldBg),
                        const SizedBox(height: 12),
                        _buildOfferAgreementCheckbox(isDark, border, text, muted),
                      ],
                    ],
                  ),
                ),
              ),

              if (!isSearching && _error != null)
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
              if (!isSearching)
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
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121214) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          // Inputs column
          Column(
            children: [
              // Point A
              Row(
                children: [
                  // Dot A
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isDark ? AkJolTheme.primary : AkJolTheme.primaryLight,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isDark ? AkJolTheme.primary : AkJolTheme.primaryLight).withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _activeField == 'A'
                            ? (isDark ? const Color(0xFF1C1C1F) : const Color(0xFFF1F5F9))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _activeField == 'A' ? primaryColor : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: TextField(
                        controller: _addressACtrl,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: text),
                        focusNode: _focusNodeA,
                        decoration: InputDecoration(
                          hintText: 'Откуда (Точка А)',
                          hintStyle: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w400),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onTap: () {
                          setState(() {
                            _activeField = 'A';
                          });
                        },
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
                  const SizedBox(width: 40), // Spacing for swap button
                ],
              ),
              
              // Divider & Vertical line
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      alignment: Alignment.center,
                      child: Container(
                        width: 1.5,
                        height: 24,
                        color: muted.withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Divider(
                        height: 1,
                        color: border,
                      ),
                    ),
                    const SizedBox(width: 40), // Spacing for swap button
                  ],
                ),
              ),

              // Point B
              Row(
                children: [
                  // Square B
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _activeField == 'B'
                            ? (isDark ? const Color(0xFF1C1C1F) : const Color(0xFFF1F5F9))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _activeField == 'B' ? Colors.blue : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: TextField(
                        controller: _addressBCtrl,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: text),
                        focusNode: _focusNodeB,
                        decoration: InputDecoration(
                          hintText: 'Куда (Точка Б)',
                          hintStyle: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w400),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onTap: () {
                          setState(() {
                            _activeField = 'B';
                          });
                        },
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
                  const SizedBox(width: 40), // Spacing for swap button
                ],
              ),
            ],
          ),

          // Vertically centered Swap button
          Positioned(
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1F) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: border, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  Icons.swap_vert_rounded,
                  color: isDark ? AkJolTheme.primary : AkJolTheme.primaryLight,
                  size: 20,
                ),
                onPressed: _swapAddresses,
                tooltip: 'Поменять местами',
              ),
            ),
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
    const brandPrimary = AkJolTheme.primary; // Neon green in both themes
    
    // Light grey for transport cards in light theme for better contrast against white bottom sheet
    final transportCardBg = isDark ? const Color(0xFF121214) : const Color(0xFFF1F5F9);
    
    final bikeSelectedBg = bikeSelected
        ? brandPrimary.withValues(alpha: isDark ? 0.15 : 0.22)
        : transportCardBg;
        
    final scooterSelectedBg = scooterSelected
        ? brandPrimary.withValues(alpha: isDark ? 0.15 : 0.22)
        : transportCardBg;

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
                  height: 120,
                  decoration: BoxDecoration(
                    color: bikeSelectedBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: bikeSelected ? brandPrimary : border,
                      width: bikeSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      if (bikeSelected)
                        BoxShadow(
                          color: brandPrimary.withValues(alpha: isDark ? 0.2 : 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      children: [
                        // Image background on the right side of the card
                        Positioned(
                          top: 8,
                          bottom: 8,
                          right: -12,
                          width: 124,
                          child: ShaderMask(
                            shaderCallback: (rect) {
                              return const LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.white,
                                  Colors.white,
                                  Colors.transparent,
                                ],
                                stops: [0.0, 0.25, 0.95, 1.0],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ).createShader(rect);
                            },
                            blendMode: BlendMode.dstIn,
                            child: ShaderMask(
                              shaderCallback: (rect) {
                                return const LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.white,
                                    Colors.white,
                                    Colors.transparent,
                                  ],
                                  stops: [0.0, 0.08, 0.92, 1.0],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ).createShader(rect);
                              },
                              blendMode: BlendMode.dstIn,
                              child: Opacity(
                                opacity: bikeSelected ? 1.0 : 0.65,
                                child: Image.asset(
                                  'assets/images/delivery_bike.png',
                                  fit: BoxFit.contain,
                                  alignment: Alignment.center,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Icon(
                                        Icons.electric_bike_rounded,
                                        color: bikeSelected ? primaryColor : muted,
                                        size: 32,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Readability Gradient overlay
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  bikeSelectedBg.withValues(alpha: 0.95),
                                  bikeSelectedBg.withValues(alpha: 0.35),
                                  bikeSelectedBg.withValues(alpha: 0.0),
                                ],
                                stops: const [0.0, 0.35, 0.75],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                          ),
                        ),
                        // Content overlay
                        Padding(
                          padding: const EdgeInsets.only(left: 14, right: 54, top: 12, bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (_distanceKm > 0.0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: bikeSelected
                                        ? brandPrimary
                                        : (isDark ? const Color(0xFF1C1C1F) : const Color(0xFFF1F5F9)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${math.max(1, (_distanceKm * 5).round())} мин',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: bikeSelected
                                          ? (isDark ? const Color(0xFF0F0F10) : AkJolTheme.primaryLight)
                                          : muted,
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Электровелосипед',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: bikeSelected
                                          ? (isDark ? const Color(0xFF0F0F10) : AkJolTheme.primaryLight)
                                          : text,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${bikeFee.toStringAsFixed(0)} сом',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: bikeSelected
                                          ? (isDark ? const Color(0xFF0F0F10) : AkJolTheme.primaryLight)
                                          : text,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
                  height: 120,
                  decoration: BoxDecoration(
                    color: scooterSelectedBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: scooterSelected ? brandPrimary : border,
                      width: scooterSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      if (scooterSelected)
                        BoxShadow(
                          color: brandPrimary.withValues(alpha: isDark ? 0.2 : 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      children: [
                        // Image background on the right side of the card
                        Positioned(
                          top: 8,
                          bottom: 8,
                          right: -12,
                          width: 124,
                          child: ShaderMask(
                            shaderCallback: (rect) {
                              return const LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.white,
                                  Colors.white,
                                  Colors.transparent,
                                ],
                                stops: [0.0, 0.25, 0.95, 1.0],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ).createShader(rect);
                            },
                            blendMode: BlendMode.dstIn,
                            child: ShaderMask(
                              shaderCallback: (rect) {
                                return const LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.white,
                                    Colors.white,
                                    Colors.transparent,
                                  ],
                                  stops: [0.0, 0.08, 0.92, 1.0],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ).createShader(rect);
                              },
                              blendMode: BlendMode.dstIn,
                              child: Opacity(
                                opacity: scooterSelected ? 1.0 : 0.65,
                                child: Image.asset(
                                  'assets/images/delivery_trike.png',
                                  fit: BoxFit.contain,
                                  alignment: Alignment.center,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Icon(
                                        Icons.electric_moped_rounded,
                                        color: scooterSelected ? primaryColor : muted,
                                        size: 32,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Readability Gradient overlay
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  scooterSelectedBg.withValues(alpha: 0.95),
                                  scooterSelectedBg.withValues(alpha: 0.35),
                                  scooterSelectedBg.withValues(alpha: 0.0),
                                ],
                                stops: const [0.0, 0.35, 0.75],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                          ),
                        ),
                        // Content overlay
                        Padding(
                          padding: const EdgeInsets.only(left: 14, right: 54, top: 12, bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (_distanceKm > 0.0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: scooterSelected
                                        ? brandPrimary
                                        : (isDark ? const Color(0xFF1C1C1F) : const Color(0xFFF1F5F9)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${math.max(1, (_distanceKm * 7).round())} мин',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: scooterSelected
                                          ? (isDark ? const Color(0xFF0F0F10) : AkJolTheme.primaryLight)
                                          : muted,
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Электромуравей',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: scooterSelected
                                          ? (isDark ? const Color(0xFF0F0F10) : AkJolTheme.primaryLight)
                                          : text,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${scooterFee.toStringAsFixed(0)} сом',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: scooterSelected
                                          ? (isDark ? const Color(0xFF0F0F10) : AkJolTheme.primaryLight)
                                          : text,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
              color: transportCardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border, width: 1),
            ),
            child: CheckboxListTile(
              value: _needLoader,
              onChanged: (val) {
                setState(() => _needLoader = val ?? false);
              },
              title: Text(
                'Нужна помощь курьера в выгрузке (+20%)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: text),
              ),
              subtitle: Text(
                'Помощь в погрузке/разгрузке тяжелых вещей',
                style: TextStyle(fontSize: 11, color: muted),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              activeColor: primaryColor,
              dense: true,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCommentInput(bool isDark, Color border, Color text, Color muted, Color fieldBg) {
    final primaryColor = Theme.of(context).colorScheme.primary;

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
            hintStyle: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w400),
            filled: true,
            fillColor: isDark ? const Color(0xFF1C1C1F) : const Color(0xFFF1F5F9),
            prefixIcon: Icon(Icons.chat_bubble_outline_rounded, color: primaryColor, size: 18),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: primaryColor, width: 1.5),
            ),
          ),
          style: TextStyle(fontSize: 13, color: text, fontWeight: FontWeight.w600),
          maxLines: 2,
          minLines: 1,
        ),
      ],
    );
  }

  Widget _buildSenderRecipientPhonesBlock(bool isDark, Color border, Color text, Color muted, Color fieldBg) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final cardBg = isDark ? const Color(0xFF121214) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.phone_in_talk_rounded, color: primaryColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'Контактные данные',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: text),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sender phone
          Text(
            'Телефон отправителя *',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: muted),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _senderPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: '+996 700 000 000',
              hintStyle: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w400),
              filled: true,
              fillColor: isDark ? const Color(0xFF1C1C1F) : const Color(0xFFF1F5F9),
              prefixIcon: Icon(Icons.outbox_rounded, color: primaryColor, size: 18),
              suffixIcon: IconButton(
                icon: const Icon(Icons.contact_phone_rounded, size: 20),
                color: primaryColor,
                onPressed: () => _pickContactForController(_senderPhoneCtrl),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: border, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: primaryColor, width: 1.5),
              ),
            ),
            style: TextStyle(fontSize: 13, color: text, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),

          // Recipient phone
          Text(
            'Телефон получателя *',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: muted),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _recipientPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: '+996 700 000 000',
              hintStyle: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w400),
              filled: true,
              fillColor: isDark ? const Color(0xFF1C1C1F) : const Color(0xFFF1F5F9),
              prefixIcon: Icon(Icons.move_to_inbox_rounded, color: Colors.blue, size: 18),
              suffixIcon: IconButton(
                icon: const Icon(Icons.contact_phone_rounded, size: 20),
                color: Colors.blue,
                onPressed: () => _pickContactForController(_recipientPhoneCtrl),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: border, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.blue, width: 1.5),
              ),
            ),
            style: TextStyle(fontSize: 13, color: text, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferAgreementCheckbox(bool isDark, Color border, Color text, Color muted) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: _acceptTerms,
          activeColor: primaryColor,
          onChanged: (val) {
            setState(() {
              _acceptTerms = val ?? false;
            });
          },
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _acceptTerms = !_acceptTerms;
                });
              },
              child: Text.rich(
                TextSpan(
                  text: 'Я подтверждаю, что посылка не содержит запрещенных веществ, и принимаю условия ',
                  style: TextStyle(fontSize: 12, color: text),
                  children: [
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: _showPublicOfferDialog,
                        child: Text(
                          'публичной оферты',
                          style: TextStyle(
                            fontSize: 12,
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showPublicOfferDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : Colors.black87;
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Публичная оферта AkJol Go',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: text),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        _offerParagraph(
                          '1. Статус платформы (Информационное посредничество)',
                          'Сервис AkJol Go является исключительно ИТ-платформой (информационным посредником). Мы предоставляем программное обеспечение для координации заказов между независимыми отправителями и курьерами. Сервис не является транспортной или почтовой компанией, не осуществляет самостоятельную перевозку грузов и не нанимает курьеров в штат.',
                        ),
                        _offerParagraph(
                          '2. Запрещенные к перевозке вещества и предметы',
                          'Категорически запрещается передавать для доставки следующие предметы:\n'
                          '• Наркотические, психотропные вещества и их прекурсоры;\n'
                          '• Оружие (огнестрельное, пневматическое, холодное) и боеприпасы;\n'
                          '• Взрывчатые, легковоспламеняющиеся, горючие и ядовитые вещества;\n'
                          '• Крупные суммы наличных денежных средств и драгоценные металлы;\n'
                          '• Иные предметы, оборот которых запрещен или ограничен законодательством Кыргызской Республики.',
                        ),
                        _offerParagraph(
                          '3. Полная ответственность Отправителя',
                          'Отправитель несет полную единоличную гражданскую, административную и уголовную ответственность за содержимое посылки. Отправитель обязуется передавать посылку курьеру в открытом виде для визуального осмотра. Курьер имеет право отказаться от выполнения заказа при подозрении на наличие запрещенных предметов.',
                        ),
                        _offerParagraph(
                          '4. Помощь следственным органам',
                          'В случае выявления фактов перевозки запрещенных веществ, платформа оставляет за собой право передать все логические данные (ФИО, номера телефонов отправителя и получателя, координаты точек А и Б, IP-адреса и треки перемещения) правоохранительным органам.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Я согласен', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _offerParagraph(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutBar(bool isDark, Color border, Color text, Color muted) {
    final fee = _calculateTempFee(_selectedTransport);

    final Color buttonTextColor = _isReady
        ? (isDark ? const Color(0xFF0F0F10) : Colors.white)
        : (isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8));

    final gradientColors = isDark
        ? const [AkJolTheme.primary, AkJolTheme.primaryDark]
        : const [AkJolTheme.primaryLight, Color(0xFF10B981)];

    return Row(
      children: [
        // Order Button
        Expanded(
          child: SizedBox(
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: _isReady && !_submitting
                    ? LinearGradient(colors: gradientColors)
                    : null,
                color: _isReady && !_submitting ? null
                    : (isDark ? const Color(0xFF1C1C1F) : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(16),
                boxShadow: _isReady && !_submitting
                    ? [
                        BoxShadow(
                          color: (isDark ? AkJolTheme.primary : AkJolTheme.primaryLight).withValues(alpha: isDark ? 0.35 : 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _isReady && !_submitting ? _onSubmit : null,
                  child: Center(
                    child: _submitting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: isDark ? const Color(0xFF0F0F10) : Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.flash_on_rounded,
                                size: 16,
                                color: buttonTextColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isReady ? 'Заказать (${fee.toStringAsFixed(0)} сом)' : 'Выберите адреса',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: buttonTextColor,
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
