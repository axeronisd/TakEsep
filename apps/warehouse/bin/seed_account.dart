import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

void main() async {
  const supabaseUrl = 'https://smvegrscjnoelfsipwqq.supabase.co';
  const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNtdmVncnNjam5vZWxmc2lwd3FxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMxNTU5MjcsImV4cCI6MjA4ODczMTkyN30.z6h0ubNjAC0QfdGgg3FhAfSCy9RVVCupOuQUKuD98ig';

  final headers = {
    'apikey': supabaseKey,
    'Authorization': 'Bearer $supabaseKey',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation'
  };

  String generateId() {
    final rand = Random();
    final bytes = List<int>.generate(16, (i) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String uuid() {
    final s = generateId();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20, 32)}';
  }

  Future<dynamic> post(String table, Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/$table'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (res.statusCode >= 400) {
      throw Exception('Failed to insert $table: ${res.body}');
    }
    return jsonDecode(res.body)[0];
  }

  try {
    // 1. Create Company
    final companyId = uuid();
    final licenseKey = 'DEMO-${Random().nextInt(999999).toString().padLeft(6, '0')}';
    
    await post('companies', {
      'id': companyId,
      'title': 'Demo Store Limited',
      'license_key': licenseKey,
      'is_active': true,
    });

    print('✓ Company created: Demo Store Limited');
    print('🔑 LICENSE KEY: $licenseKey');

    // 2. Create Group
    final groupId = uuid();
    await post('warehouse_groups', {
      'id': groupId,
      'company_id': companyId,
      'name': 'Main Branch Hub',
    });

    // 3. Create Warehouse
    final warehouseId = uuid();
    await post('warehouses', {
      'id': warehouseId,
      'organization_id': companyId,
      'group_id': groupId,
      'name': 'Central Warehouse (Almaty)',
      'address': 'Abay Ave, 150',
    });
    print('✓ Warehouse created');

    // 4. Create Category
    final categoryId = uuid();
    await post('categories', {
      'id': categoryId,
      'company_id': companyId,
      'name': 'Electronics',
    });

    // 5. Create Products
    final futures = <Future>[];
    
    final productsInfo = [
      {
        'name': 'iPhone 15 Pro Max',
        'cost': 1100.0,
        'sell': 1400.0,
        'image': 'https://images.unsplash.com/photo-1695048133142-1a20484d2569?q=80&w=400&auto=format&fit=crop',
      },
      {
        'name': 'MacBook Pro 14" M3',
        'cost': 1800.0,
        'sell': 2100.0,
        'image': 'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?q=80&w=400&auto=format&fit=crop',
      },
      {
        'name': 'AirPods Pro 2',
        'cost': 180.0,
        'sell': 250.0,
        'image': 'https://images.unsplash.com/photo-1606220588913-b3aec89710f4?q=80&w=400&auto=format&fit=crop',
      },
      {
        'name': 'Sony WH-1000XM5',
        'cost': 280.0,
        'sell': 400.0,
        'image': 'https://images.unsplash.com/photo-1618366712010-f4ae9c647dcb?q=80&w=400&auto=format&fit=crop',
      }
    ];

    for (var i = 0; i < productsInfo.length; i++) {
        final p = productsInfo[i];
        futures.add(post('products', {
            'id': uuid(),
            'company_id': companyId,
            'warehouse_id': warehouseId,
            'category_id': categoryId,
            'name': p['name'],
            'sku': 'SKU-${Random().nextInt(99999)}',
            'barcode': '123456789012$i',
            'cost_price': p['cost'],
            'price': p['sell'],
            'quantity': 25 + Random().nextInt(50),
            'image_url': p['image'],
        }));
    }

    await Future.wait(futures);
    print('✓ ${productsInfo.length} Products created with real images');

    // 6. Create Service
    await post('services', {
        'id': uuid(),
        'company_id': companyId,
        'name': 'Device Setup & Diagnostics',
        'category': 'Diagnostics',
        'price': 50.0,
        'image_url': 'https://images.unsplash.com/photo-1597872253359-f7051e7f60ee?q=80&w=400&auto=format&fit=crop',
    });
    print('✓ Service created');

  } catch (e) {
    print('Error: $e');
  }
}
