import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:warehouse/src/providers/client_providers.dart';
import 'package:warehouse/src/data/client_repository.dart';

class MockClientRepository implements ClientRepository {
  final List<Map<String, dynamic>> mockSales;

  MockClientRepository(this.mockSales);

  @override
  Future<List<Map<String, dynamic>>> getClientSales(String clientId) async {
    return mockSales;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Client Profile Details Tests', () {
    test('clientSalesProvider fetches sales history from repository', () async {
      final mockSalesData = [
        {
          'id': 'sale1',
          'total_amount': 1500.0,
          'received_amount': 1000.0, // 500 debt
          'payment_method': 'cash',
          'notes': 'Test sale',
          'employee_name': 'Aleksey',
          'items': '[{"id": "item1", "product_name": "Product A", "quantity": 2, "selling_price": 750.0}]',
          'created_at': '2026-06-23T12:00:00Z',
        }
      ];

      final container = ProviderContainer(
        overrides: [
          clientRepositoryProvider.overrideWithValue(MockClientRepository(mockSalesData)),
        ],
      );
      addTearDown(container.dispose);

      final sales = await container.read(clientSalesProvider('client1').future);
      expect(sales, equals(mockSalesData));
      expect(sales.first['employee_name'], equals('Aleksey'));
      expect(sales.first['total_amount'], equals(1500.0));
    });

    test('average check calculation logic', () {
      final now = DateTime.now();
      final client = Client(
        id: 'c1',
        companyId: 'comp1',
        name: 'John Doe',
        totalSpent: 4500.0,
        purchasesCount: 3,
        createdAt: now,
        updatedAt: now,
      );

      final avgCheck = client.purchasesCount > 0 ? (client.totalSpent / client.purchasesCount) : 0.0;
      expect(avgCheck, equals(1500.0));

      final clientNoPurchases = Client(
        id: 'c2',
        companyId: 'comp1',
        name: 'Jane Doe',
        totalSpent: 0.0,
        purchasesCount: 0,
        createdAt: now,
        updatedAt: now,
      );
      final avgCheckZero = clientNoPurchases.purchasesCount > 0 
          ? (clientNoPurchases.totalSpent / clientNoPurchases.purchasesCount) 
          : 0.0;
      expect(avgCheckZero, equals(0.0));
    });
  });
}
