import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:warehouse/src/providers/auth_providers.dart';
import 'package:warehouse/src/providers/owner_settings_provider.dart';
import 'package:warehouse/src/providers/sales_providers.dart';
import 'package:warehouse/src/providers/client_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('Client Discount Settings & Cart Discounts', () {
    test('default settings are 10% wholesale and 5% VIP', () {
      final container = createContainer();
      final settings = container.read(clientDiscountSettingsProvider);

      expect(settings.wholesale, equals(10.0));
      expect(settings.vip, equals(5.0));
    });

    test('updating settings saves to shared preferences', () {
      final container = createContainer();
      final notifier = container.read(clientDiscountSettingsProvider.notifier);

      notifier.updateWholesale(12.5);
      notifier.updateVip(8.0);

      final settings = container.read(clientDiscountSettingsProvider);
      expect(settings.wholesale, equals(12.5));
      expect(settings.vip, equals(8.0));

      expect(prefs.getDouble('takesep_discount_wholesale'), equals(12.5));
      expect(prefs.getDouble('takesep_discount_vip'), equals(8.0));
    });

    test('selecting client automatically applies discount based on settings', () {
      final container = createContainer();

      // Initial state is null
      expect(container.read<Discount?>(globalDiscountProvider), isNull);

      // Cart provider must be read/listened to initialize its listeners
      container.read(cartProvider);

      // Select wholesale client
      final wholesaleClient = Client(
        id: 'c1',
        companyId: 'comp1',
        name: 'Optovik',
        phone: '123',
        type: 'wholesale',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      container.read(selectedClientProvider.notifier).state = wholesaleClient;

      // Verify wholesale discount is applied
      var discount = container.read<Discount?>(globalDiscountProvider);
      expect(discount, isNotNull);
      expect(discount!.value, equals(10.0));

      // Select VIP client
      final vipClient = Client(
        id: 'c2',
        companyId: 'comp1',
        name: 'VipClient',
        phone: '456',
        type: 'vip',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      container.read(selectedClientProvider.notifier).state = vipClient;

      discount = container.read<Discount?>(globalDiscountProvider);
      expect(discount, isNotNull);
      expect(discount!.value, equals(5.0));
    });

    test('updating settings dynamically updates active client discount', () {
      final container = createContainer();

      // Cart provider must be read/listened to initialize its listeners
      container.read(cartProvider);

      // Select wholesale client
      final wholesaleClient = Client(
        id: 'c1',
        companyId: 'comp1',
        name: 'Optovik',
        phone: '123',
        type: 'wholesale',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      container.read(selectedClientProvider.notifier).state = wholesaleClient;

      var discount = container.read<Discount?>(globalDiscountProvider);
      expect(discount, isNotNull);
      expect(discount!.value, equals(10.0));

      // Update wholesale discount in settings
      container.read(clientDiscountSettingsProvider.notifier).updateWholesale(15.0);

      // Verify the active discount updated to 15.0
      discount = container.read<Discount?>(globalDiscountProvider);
      expect(discount, isNotNull);
      expect(discount!.value, equals(15.0));
    });
  });
}
