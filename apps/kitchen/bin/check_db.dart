import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const supabaseUrl = 'https://smvegrscjnoelfsipwqq.supabase.co';
  const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNtdmVncnNjam5vZWxmc2lwd3FxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMxNTU5MjcsImV4cCI6MjA4ODczMTkyN30.z6h0ubNjAC0QfdGgg3FhAfSCy9RVVCupOuQUKuD98ig';
  
  final headers = {
    'apikey': supabaseKey,
    'Authorization': 'Bearer $supabaseKey',
  };

  print('🔎 Checking Supabase...');
  try {
    // 1. Get the company we just created
    final cRes = await http.get(
      Uri.parse('$supabaseUrl/rest/v1/companies?license_key=eq.DEMO-515709'),
      headers: headers,
    );
    final companies = jsonDecode(cRes.body) as List;
    if (companies.isEmpty) {
      print('❌ Company DEMO-515709 not found!');
      return;
    }
    final company = companies[0];
    final companyId = company['id'];
    print('✅ Found Company: ${company['title']} (ID: $companyId)');

    // 2. Query warehouses by organization_id
    final wRes = await http.get(
      Uri.parse('$supabaseUrl/rest/v1/warehouses?organization_id=eq.$companyId'),
      headers: headers,
    );
    if (wRes.statusCode != 200) {
      print('❌ Error fetching warehouses: ${wRes.statusCode} - ${wRes.body}');
      return;
    }
    final warehouses = jsonDecode(wRes.body) as List;
    print('✅ Found ${warehouses.length} warehouses associated with this company!');
    for (var w in warehouses) {
      print('  - 📦 ${w['name']} (ID: ${w['id']}, Org: ${w['organization_id']})');
      print('    -> ALL FIELDS: $w');
    }
    
    // 3. Let's do a raw fetch of ALL warehouses just to see if ANY exist at all!
    if (warehouses.isEmpty) {
       print('\n⚠️ No warehouses found for this organization_id. Getting ALL warehouses...');
       final allWRes = await http.get(
         Uri.parse('$supabaseUrl/rest/v1/warehouses?limit=5'),
         headers: headers,
       );
       final allW = jsonDecode(allWRes.body) as List;
       print('✅ Retrieved ${allW.length} RANDOM warehouses from database:');
       for (var w in allW) {
         print('  - $w');
       }
    }
  } catch (e) {
    print('Error: $e');
  }
}
