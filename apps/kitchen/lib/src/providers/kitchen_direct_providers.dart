import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'auth_providers.dart';

final _supabase = Supabase.instance.client;

/// Zone/Floor model
class DirectKitchenZone {
  final String id;
  final String warehouseId;
  final String name;
  final int sortOrder;
  final String backgroundColor;
  final double defaultScale;

  DirectKitchenZone({
    required this.id,
    required this.warehouseId,
    required this.name,
    required this.sortOrder,
    required this.backgroundColor,
    required this.defaultScale,
  });

  factory DirectKitchenZone.fromJson(Map<String, dynamic> json) {
    return DirectKitchenZone(
      id: json['id'] as String,
      warehouseId: json['warehouse_id'] as String,
      name: json['name'] as String,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      backgroundColor: json['background_color'] as String? ?? '#FFFFFF',
      defaultScale: (json['default_scale'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

/// Table position and attributes model
class DirectKitchenTable {
  final String id;
  final String warehouseId;
  final String name;
  final String status; // 'available', 'occupied', 'bill_requested'
  final String? zoneId;
  final double xPosition;
  final double yPosition;
  final double width;
  final double height;
  final String shape; // 'circle', 'rectangle'
  final String? assignedEmployeeId;
  final String? color; // Custom background hex color (e.g. #FFC107)

  DirectKitchenTable({
    required this.id,
    required this.warehouseId,
    required this.name,
    required this.status,
    this.zoneId,
    required this.xPosition,
    required this.yPosition,
    required this.width,
    required this.height,
    required this.shape,
    this.assignedEmployeeId,
    this.color,
  });

  factory DirectKitchenTable.fromJson(Map<String, dynamic> json) {
    return DirectKitchenTable(
      id: json['id'] as String,
      warehouseId: json['warehouse_id'] as String,
      name: json['name'] as String,
      status: json['status'] as String? ?? 'available',
      zoneId: json['zone_id'] as String?,
      xPosition: (json['x_position'] as num?)?.toDouble() ?? 50.0,
      yPosition: (json['y_position'] as num?)?.toDouble() ?? 50.0,
      width: (json['width'] as num?)?.toDouble() ?? 80.0,
      height: (json['height'] as num?)?.toDouble() ?? 80.0,
      shape: json['shape'] as String? ?? 'rectangle',
      assignedEmployeeId: json['assigned_employee_id'] as String?,
      color: json['color'] as String?,
    );
  }

  DirectKitchenTable copyWith({
    String? id,
    String? warehouseId,
    String? name,
    String? status,
    String? zoneId,
    double? xPosition,
    double? yPosition,
    double? width,
    double? height,
    String? shape,
    String? assignedEmployeeId,
    String? color,
    bool clearColor = false,
  }) {
    return DirectKitchenTable(
      id: id ?? this.id,
      warehouseId: warehouseId ?? this.warehouseId,
      name: name ?? this.name,
      status: status ?? this.status,
      zoneId: zoneId ?? this.zoneId,
      xPosition: xPosition ?? this.xPosition,
      yPosition: yPosition ?? this.yPosition,
      width: width ?? this.width,
      height: height ?? this.height,
      shape: shape ?? this.shape,
      assignedEmployeeId: assignedEmployeeId ?? this.assignedEmployeeId,
      color: clearColor ? null : (color ?? this.color),
    );
  }
}

/// Wall element model representing custom dividers in restaurant floor plan
class DirectKitchenWall {
  final String id;
  final String zoneId;
  final double xPosition;
  final double yPosition;
  final double width;
  final double height;
  final double rotation;
  final String color;

  DirectKitchenWall({
    required this.id,
    required this.zoneId,
    required this.xPosition,
    required this.yPosition,
    required this.width,
    required this.height,
    required this.rotation,
    required this.color,
  });

  factory DirectKitchenWall.fromJson(Map<String, dynamic> json) {
    return DirectKitchenWall(
      id: json['id'] as String,
      zoneId: json['zone_id'] as String,
      xPosition: (json['x_position'] as num?)?.toDouble() ?? 50.0,
      yPosition: (json['y_position'] as num?)?.toDouble() ?? 50.0,
      width: (json['width'] as num?)?.toDouble() ?? 100.0,
      height: (json['height'] as num?)?.toDouble() ?? 15.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      color: json['color'] as String? ?? '#8D8D8D',
    );
  }

  DirectKitchenWall copyWith({
    String? id,
    String? zoneId,
    double? xPosition,
    double? yPosition,
    double? width,
    double? height,
    double? rotation,
    String? color,
  }) {
    return DirectKitchenWall(
      id: id ?? this.id,
      zoneId: zoneId ?? this.zoneId,
      xPosition: xPosition ?? this.xPosition,
      yPosition: yPosition ?? this.yPosition,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      color: color ?? this.color,
    );
  }
}

/// Waiter commission settings model
class DirectWaiterSettings {
  final String id;
  final String employeeId;
  final double commissionPercent;

  DirectWaiterSettings({
    required this.id,
    required this.employeeId,
    required this.commissionPercent,
  });

  factory DirectWaiterSettings.fromJson(Map<String, dynamic> json) {
    return DirectWaiterSettings(
      id: json['id'] as String,
      employeeId: json['employee_id'] as String,
      commissionPercent: (json['commission_percent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Real-time stream of zones directly from Supabase
final directKitchenZonesProvider = StreamProvider<List<DirectKitchenZone>>((ref) {
  final warehouseId = ref.watch(selectedWarehouseIdProvider);
  if (warehouseId == null) return const Stream.empty();

  return _supabase
      .from('kitchen_zones')
      .stream(primaryKey: ['id'])
      .order('sort_order', ascending: true)
      .map((list) => list
          .map((json) => DirectKitchenZone.fromJson(json))
          .where((z) => z.warehouseId == warehouseId)
          .toList());
});

/// Real-time stream of tables directly from Supabase
final directKitchenTablesProvider = StreamProvider<List<DirectKitchenTable>>((ref) {
  final warehouseId = ref.watch(selectedWarehouseIdProvider);
  if (warehouseId == null) return const Stream.empty();

  return _supabase
      .from('kitchen_tables')
      .stream(primaryKey: ['id'])
      .map((list) => list
          .map((json) => DirectKitchenTable.fromJson(json))
          .where((t) => t.warehouseId == warehouseId)
          .toList());
});

/// Real-time stream of waiter commissions directly from Supabase
final directWaiterSettingsProvider = StreamProvider<List<DirectWaiterSettings>>((ref) {
  return _supabase
      .from('kitchen_waiter_settings')
      .stream(primaryKey: ['id'])
      .map((list) => list.map((json) => DirectWaiterSettings.fromJson(json)).toList());
});

/// Real-time stream of walls/dividers directly from Supabase
final directKitchenWallsProvider = StreamProvider<List<DirectKitchenWall>>((ref) {
  final warehouseId = ref.watch(selectedWarehouseIdProvider);
  if (warehouseId == null) return const Stream.empty();

  return _supabase
      .from('kitchen_walls')
      .stream(primaryKey: ['id'])
      .map((list) => list.map((json) => DirectKitchenWall.fromJson(json)).toList());
});

/// Mutator class for all direct Supabase actions
class KitchenDirectMutator {
  /// Create a new zone/floor layout
  static Future<void> createZone(String name, String warehouseId) async {
    final now = DateTime.now().toIso8601String();
    await _supabase.from('kitchen_zones').insert({
      'id': const Uuid().v4(),
      'warehouse_id': warehouseId,
      'name': name,
      'sort_order': 0,
      'background_color': '#FFFFFF',
      'created_at': now,
      'updated_at': now,
    });
  }

  /// Update zone name
  static Future<void> updateZone(String zoneId, String name) async {
    await _supabase.from('kitchen_zones').update({
      'name': name,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', zoneId);
  }

  /// Update zone background floor color
  static Future<void> updateZoneBackgroundColor(String zoneId, String color) async {
    await _supabase.from('kitchen_zones').update({
      'background_color': color,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', zoneId);
  }

  /// Update zone default scale
  static Future<void> updateZoneScale(String zoneId, double scale) async {
    await _supabase.from('kitchen_zones').update({
      'default_scale': scale,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', zoneId);
  }

  /// Delete a zone
  static Future<void> deleteZone(String zoneId) async {
    await _supabase.from('kitchen_zones').delete().eq('id', zoneId);
  }

  /// Save the entire zone floor layout (tables, walls, scale) in a batch transaction
  static Future<void> saveZoneLayout({
    required String zoneId,
    required List<DirectKitchenTable> tables,
    required List<DirectKitchenWall> walls,
    required double scale,
  }) async {
    // 1. Update scale
    await _supabase.from('kitchen_zones').update({
      'default_scale': scale,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', zoneId);

    // 2. Sync tables: Get all table IDs currently in local list
    final localTableIds = tables.map((t) => t.id).toList();
    if (localTableIds.isEmpty) {
      await _supabase.from('kitchen_tables').delete().eq('zone_id', zoneId);
    } else {
      await _supabase
          .from('kitchen_tables')
          .delete()
          .eq('zone_id', zoneId)
          .not('id', 'in', localTableIds);
    }

    // Upsert all local tables
    if (tables.isNotEmpty) {
      final tablesJson = tables.map((t) => {
        'id': t.id,
        'warehouse_id': t.warehouseId,
        'zone_id': t.zoneId,
        'name': t.name,
        'status': t.status,
        'x_position': t.xPosition,
        'y_position': t.yPosition,
        'width': t.width,
        'height': t.height,
        'shape': t.shape,
        'assigned_employee_id': t.assignedEmployeeId,
        'color': t.color,
        'updated_at': DateTime.now().toIso8601String(),
      }).toList();
      await _supabase.from('kitchen_tables').upsert(tablesJson);
    }

    // 3. Sync walls: Get all wall IDs currently in local list
    final localWallIds = walls.map((w) => w.id).toList();
    if (localWallIds.isEmpty) {
      await _supabase.from('kitchen_walls').delete().eq('zone_id', zoneId);
    } else {
      await _supabase
          .from('kitchen_walls')
          .delete()
          .eq('zone_id', zoneId)
          .not('id', 'in', localWallIds);
    }

    // Upsert all local walls
    if (walls.isNotEmpty) {
      final wallsJson = walls.map((w) => {
        'id': w.id,
        'zone_id': w.zoneId,
        'x_position': w.xPosition,
        'y_position': w.yPosition,
        'width': w.width,
        'height': w.height,
        'rotation': w.rotation,
        'color': w.color,
        'updated_at': DateTime.now().toIso8601String(),
      }).toList();
      await _supabase.from('kitchen_walls').upsert(wallsJson);
    }
  }

  /// Create a new table directly in Supabase
  static Future<void> createTable({
    required String name,
    required String warehouseId,
    String? zoneId,
    double x = 50.0,
    double y = 50.0,
    double w = 80.0,
    double h = 80.0,
    String shape = 'rectangle',
    String? assignedEmployeeId,
    String? color,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _supabase.from('kitchen_tables').insert({
      'id': const Uuid().v4(),
      'warehouse_id': warehouseId,
      'name': name,
      'status': 'available',
      'zone_id': zoneId,
      'x_position': x,
      'y_position': y,
      'width': w,
      'height': h,
      'shape': shape,
      'assigned_employee_id': assignedEmployeeId,
      'color': color,
      'created_at': now,
      'updated_at': now,
    });
  }

  /// Update table layout geometry (drag/resize) and details
  static Future<void> updateTableGeometry(
    String tableId, {
    double? x,
    double? y,
    double? w,
    double? h,
    String? shape,
    String? name,
    String? assignedEmployeeId,
    String? zoneId,
    String? color,
    bool clearColor = false,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (x != null) updates['x_position'] = x;
    if (y != null) updates['y_position'] = y;
    if (w != null) updates['width'] = w;
    if (h != null) updates['height'] = h;
    if (shape != null) updates['shape'] = shape;
    if (name != null) updates['name'] = name;
    if (zoneId != null) updates['zone_id'] = zoneId;
    if (clearColor) {
      updates['color'] = null;
    } else if (color != null) {
      updates['color'] = color;
    }
    
    // Explicitly handle assignedEmployeeId updates (which can be set to null)
    if (assignedEmployeeId != null) {
      updates['assigned_employee_id'] = assignedEmployeeId.isEmpty ? null : assignedEmployeeId;
    }

    await _supabase.from('kitchen_tables').update(updates).eq('id', tableId);
  }

  /// Delete a table
  static Future<void> deleteTable(String tableId) async {
    await _supabase.from('kitchen_tables').delete().eq('id', tableId);
  }

  /// Create a new wall directly in Supabase
  static Future<void> createWall({
    required String zoneId,
    double x = 50.0,
    double y = 50.0,
    double w = 120.0,
    double h = 15.0,
    double rotation = 0.0,
    String color = '#8D8D8D',
  }) async {
    final now = DateTime.now().toIso8601String();
    await _supabase.from('kitchen_walls').insert({
      'id': const Uuid().v4(),
      'zone_id': zoneId,
      'x_position': x,
      'y_position': y,
      'width': w,
      'height': h,
      'rotation': rotation,
      'color': color,
      'created_at': now,
      'updated_at': now,
    });
  }

  /// Update wall layout geometry (drag/resize/rotate)
  static Future<void> updateWallGeometry(
    String wallId, {
    double? x,
    double? y,
    double? w,
    double? h,
    double? rotation,
    String? color,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (x != null) updates['x_position'] = x;
    if (y != null) updates['y_position'] = y;
    if (w != null) updates['width'] = w;
    if (h != null) updates['height'] = h;
    if (rotation != null) updates['rotation'] = rotation;
    if (color != null) updates['color'] = color;

    await _supabase.from('kitchen_walls').update(updates).eq('id', wallId);
  }

  /// Delete a wall
  static Future<void> deleteWall(String wallId) async {
    await _supabase.from('kitchen_walls').delete().eq('id', wallId);
  }

  /// Save waiter commission rate
  static Future<void> saveWaiterCommission(String employeeId, double percent) async {
    final now = DateTime.now().toIso8601String();
    
    // Upsert commission rate
    await _supabase.from('kitchen_waiter_settings').upsert({
      'employee_id': employeeId,
      'commission_percent': percent,
      'updated_at': now,
    }, onConflict: 'employee_id');
  }
}
