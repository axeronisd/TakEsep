# Realtime Sync Implementation Guide

This guide explains how to implement real-time synchronization for the TakEsep POS system using Supabase Realtime.

## Overview

The real-time sync system enables devices (mobile POS terminals and desktop admin) to stay synchronized in real-time. When one device creates a sale, updates product quantity, or makes any change, all other devices in the same branch (company/warehouse) receive the update immediately via WebSocket.

## Architecture

```
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
│  Device A       │         │  Supabase       │         │  Device B       │
│  (Mobile POS)   │◄────────│  Realtime       │────────►│  (Desktop)      │
│                 │  WS     │  (PostgreSQL)   │  WS     │                 │
└─────────────────┘         └─────────────────┘         └─────────────────┘
       │                            │                            │
       │                            │                            │
       ▼                            ▼                            ▼
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
│  Riverpod       │         │  RLS Filters    │         │  Riverpod       │
│  Providers      │         │  company_id     │         │  Providers      │
│  + Optimistic   │         │  warehouse_id   │         │  + Optimistic   │
│  Updates        │         │                 │         │  Updates        │
└─────────────────┘         └─────────────────┘         └─────────────────┘
```

## Components

### 1. Database Layer (SQL)

**File**: `infrastructure/migrations/029_pos_realtime_sync.sql`

Run this migration in Supabase SQL Editor to enable Realtime:

```sql
-- This enables Realtime replication for all POS tables
-- and sets up RLS policies with company_id/warehouse_id filtering
```

**Key Features**:
- Enables Realtime for: products, sales, arrivals, transfers, categories, warehouses, clients, employees, audits
- RLS policies allow anon access (for PowerSync) but filter by company_id/warehouse_id
- Automatic `updated_at` triggers for proper sync tracking
- Performance indexes for realtime queries

### 2. Realtime Service (Dart)

**File**: `apps/warehouse/lib/src/data/supabase_realtime_service.dart`

Base service that manages WebSocket connections:

```dart
final realtimeService = SupabaseRealtimeService();

// Subscribe to table changes
final stream = realtimeService.subscribeToTable(
  table: 'products',
  companyId: companyId,
  warehouseId: warehouseId,
);
```

**Key Features**:
- Automatic reconnection on network loss
- Connection lifecycle management
- Stream-based API for easy integration
- Filters by company_id and warehouse_id to prevent data overload

### 3. Realtime Repository (Dart)

**File**: `apps/warehouse/lib/src/data/realtime_products_repository.dart`

Repository with Stream methods instead of Future methods:

```dart
final repository = RealtimeProductsRepository();

// Watch products with real-time updates
Stream<List<Product>> products = repository.watchProducts(
  companyId: companyId,
  warehouseId: warehouseId,
);
```

**Key Features**:
- `watchProducts()` - Stream of all products
- `watchProduct()` - Stream of single product
- `watchProductsByCategory()` - Filtered stream
- `watchLowStockProducts()` - Alert stream
- `searchProducts()` - Real-time search

### 4. Riverpod Providers (Dart)

**File**: `apps/warehouse/lib/src/providers/realtime_products_providers.dart`

Riverpod providers for easy UI integration:

```dart
// In your app
ProviderScope(
  overrides: [
    currentCompanyIdProvider.overrideWithValue(companyId),
    currentWarehouseIdProvider.overrideWithValue(warehouseId),
  ],
  child: MyApp(),
)

// In your widget
final productsAsync = ref.watch(productsStreamProvider);
```

**Key Features**:
- `productsStreamProvider` - All products stream
- `productsByCategoryProvider` - Category-filtered stream
- `lowStockProductsProvider` - Low stock alerts
- `productSearchProvider` - Real-time search
- `productProvider` - Single product stream

### 5. Optimistic Updates (Dart)

**File**: `apps/warehouse/lib/src/providers/optimistic_update_providers.dart`

Optimistic UI updates for instant feedback:

```dart
final productNotifier = ref.watch(optimisticProductProvider(productId));

// Update quantity - UI updates immediately
productNotifier.updateQuantity(10);
// Backend sync happens in background
```

**Key Features**:
- UI updates immediately on user action
- Backend sync happens in background
- Automatic rollback on failure
- Batch update support
- Error handling with state management

### 6. Conflict Resolution (Dart)

**File**: `apps/warehouse/lib/src/data/conflict_resolution.dart`

Handles concurrent updates from multiple devices:

```dart
final service = ConflictResolutionService();

// Resolve quantity conflict
final result = await service.resolveProductQuantity(
  localProduct,
  remoteProduct,
  strategy: ConflictResolutionStrategy.lastWriteWins,
);
```

**Key Features**:
- Multiple resolution strategies (LWW, server-wins, client-wins, merge, manual)
- Automatic conflict detection
- Timestamp-based resolution
- Manual resolution option for critical conflicts

## Implementation Steps

### Step 1: Run SQL Migration

1. Go to Supabase Dashboard → SQL Editor
2. Run `infrastructure/migrations/029_pos_realtime_sync.sql`
3. Verify Realtime is enabled for all tables

### Step 2: Add Dependencies

Ensure `pubspec.yaml` has:
```yaml
dependencies:
  supabase_flutter: ^2.12.0
  flutter_riverpod: ^2.5.1
  connectivity_plus: ^5.0.0  # For network detection
```

### Step 3: Setup Riverpod Providers

In your app initialization:

```dart
void main() {
  runApp(
    ProviderScope(
      overrides: [
        currentCompanyIdProvider.overrideWithValue(userCompanyId),
        currentWarehouseIdProvider.overrideWithValue(userWarehouseId),
      ],
      child: MyApp(),
    ),
  );
}
```

### Step 4: Use Realtime Data in UI

```dart
class ProductsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsStreamProvider);

    return productsAsync.when(
      data: (products) => ListView.builder(
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return ProductTile(product: product);
        },
      ),
      loading: () => CircularProgressIndicator(),
      error: (error, stack) => ErrorWidget(error),
    );
  }
}
```

### Step 5: Implement Optimistic Updates

```dart
class ProductQuantityEditor extends ConsumerWidget {
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(optimisticProductProvider(productId));

    return TextField(
      initialValue: state.data?.quantity.toString() ?? '0',
      onChanged: (value) {
        final quantity = int.tryParse(value) ?? 0;
        ref.read(optimisticProductProvider(productId).notifier)
            .updateQuantity(quantity);
      },
    );
  }
}
```

### Step 6: Handle Conflicts (Optional)

For critical operations, implement conflict resolution:

```dart
Future<void> updateWithConflictResolution(Product localProduct) async {
  final remoteProduct = await conflictResolutionService.fetchServerProduct(localProduct.id);
  
  if (remoteProduct != null) {
    final result = await conflictResolutionService.resolveProductConflict(
      localProduct,
      remoteProduct,
      strategy: ConflictResolutionStrategy.lastWriteWins,
    );
    
    if (result.wasConflict) {
      // Log or notify user
      print(result.conflictMessage);
    }
    
    await conflictResolutionService.applyResolvedProduct(result.resolvedData);
  }
}
```

## Best Practices

### 1. Filter by Branch

Always filter by `company_id` and `warehouse_id` to prevent receiving updates from other branches:

```dart
repository.watchProducts(
  companyId: companyId,  // Required
  warehouseId: warehouseId,  // Optional - null = all warehouses in company
)
```

### 2. Use Auto-Dispose

Use `autoDispose` providers to clean up subscriptions when widgets are unmounted:

```dart
final productsStreamProvider = StreamProvider.autoDispose<List<Product>>(...);
```

### 3. Handle Network Issues

The `SupabaseRealtimeService` automatically handles reconnection, but you should show network status to users:

```dart
final connectivityProvider = StreamProvider<ConnectivityResult>((ref) {
  return Connectivity().onConnectivityChanged;
});
```

### 4. Combine with PowerSync

Use Realtime for live UI updates, but keep PowerSync for offline functionality:

```dart
// Online: Use Realtime for instant updates
final realtimeProducts = ref.watch(productsStreamProvider);

// Offline: Use PowerSync for local data
final localProducts = await inventoryRepository.getProducts(companyId);
```

### 5. Optimize Subscriptions

Only subscribe to data you need. For large datasets, use pagination or specific filters:

```dart
// Bad: Subscribe to all products
repository.watchProducts(companyId: companyId);

// Good: Subscribe only to low stock products
repository.watchLowStockProducts(companyId: companyId);
```

## Troubleshooting

### Realtime Not Working

1. Check SQL migration was applied successfully
2. Verify RLS policies allow anon access
3. Check network connectivity
4. Verify company_id and warehouse_id are correct

### Too Many Updates

1. Ensure you're filtering by company_id/warehouse_id
2. Use specific subscriptions instead of full table
3. Consider debouncing rapid updates

### Conflicts Frequent

1. Use `lastWriteWins` strategy for most cases
2. Implement optimistic updates to reduce concurrent edits
3. Consider locking critical records during editing

## Migration from Existing Code

### Replace Future Methods with Stream Methods

**Before**:
```dart
final products = await inventoryRepository.getProducts(companyId);
```

**After**:
```dart
final productsStream = realtimeProductsRepository.watchProducts(companyId: companyId);
```

### Update UI to Use Streams

**Before**:
```dart
FutureBuilder(
  future: inventoryRepository.getProducts(companyId),
  builder: (context, snapshot) { ... },
)
```

**After**:
```dart
Consumer(
  builder: (context, ref, child) {
    final productsAsync = ref.watch(productsStreamProvider);
    return productsAsync.when(...);
  },
)
```

## Performance Considerations

1. **Initial Load**: First subscription fetches all data - consider loading states
2. **Network Usage**: Realtime uses WebSocket - minimal bandwidth after initial load
3. **Battery**: WebSocket connections use minimal battery
4. **Memory**: Auto-dispose providers clean up subscriptions automatically

## Security

- RLS policies ensure devices only see their own company/branch data
- Anon access is required for PowerSync sync
- Consider implementing additional auth for sensitive operations
- Use HTTPS for all connections (Supabase default)

## Next Steps

1. Implement similar realtime repositories for:
   - SalesRepository
   - ArrivalsRepository
   - TransfersRepository
   - AuditsRepository

2. Add real-time notifications for:
   - New sales
   - Low stock alerts
   - Transfer requests

3. Implement real-time analytics dashboard

4. Add real-time collaboration features (e.g., multiple cashiers on same shift)
