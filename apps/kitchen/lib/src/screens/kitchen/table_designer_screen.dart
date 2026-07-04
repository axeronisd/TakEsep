import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:uuid/uuid.dart';
import '../../providers/kitchen_direct_providers.dart';
import '../../providers/employee_providers.dart';
import '../../providers/auth_providers.dart';
import '../../utils/snackbar_helper.dart';

class TableDesignerScreen extends ConsumerStatefulWidget {
  const TableDesignerScreen({super.key});

  @override
  ConsumerState<TableDesignerScreen> createState() => _TableDesignerScreenState();
}

enum DesignerTool {
  select,
  drawWall,
}

class _TableDesignerScreenState extends ConsumerState<TableDesignerScreen> {
  String? _selectedZoneId;
  DirectKitchenTable? _selectedTable;
  DirectKitchenWall? _selectedWall;
  bool _isDragging = false;
  DesignerTool _activeTool = DesignerTool.select;
  Offset? _drawStartPoint;
  Offset? _drawCurrentPoint;
  final TransformationController _transformationController = TransformationController();
  List<DirectKitchenTable>? _localTables;
  List<DirectKitchenWall>? _localWalls;
  String? _loadedZoneId;

  void _updateLocalTable(String id, DirectKitchenTable Function(DirectKitchenTable) updater) {
    if (_localTables == null) return;
    setState(() {
      final idx = _localTables!.indexWhere((t) => t.id == id);
      if (idx != -1) {
        final updated = updater(_localTables![idx]);
        _localTables![idx] = updated;
        if (_selectedTable?.id == id) {
          _selectedTable = updated;
        }
      }
    });
  }

  void _updateLocalWall(String id, DirectKitchenWall Function(DirectKitchenWall) updater) {
    if (_localWalls == null) return;
    setState(() {
      final idx = _localWalls!.indexWhere((w) => w.id == id);
      if (idx != -1) {
        final updated = updater(_localWalls![idx]);
        _localWalls![idx] = updated;
        if (_selectedWall?.id == id) {
          _selectedWall = updated;
        }
      }
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _safeAction(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Ошибка: $e');
      }
    }
  }

  Color _parseHexColor(String hexStr, Color fallback) {
    try {
      final cleanHex = hexStr.replaceAll('#', '').trim();
      if (cleanHex.length == 6) {
        return Color(int.parse('FF$cleanHex', radix: 16));
      } else if (cleanHex.length == 8) {
        return Color(int.parse(cleanHex, radix: 16));
      }
    } catch (_) {}
    return fallback;
  }

  Offset _snapToGrid(Offset point, double step) {
    return Offset(
      (point.dx / step).round() * step,
      (point.dy / step).round() * step,
    );
  }

  static const Map<String, Color> _tableColorPalette = {
    'Красный': Color(0xFFEF5350),
    'Оранжевый': Color(0xFFFF7043),
    'Желтый': Color(0xFFFFCA28),
    'Зеленый': Color(0xFF66BB6A),
    'Голубой': Color(0xFF42A5F5),
    'Фиолетовый': Color(0xFF7E57C2),
    'Коричневый': Color(0xFF8D6E63),
    'Серый': Color(0xFF78909C),
  };

  static const Map<String, Color> _floorColorPalette = {
    'Белый': Color(0xFFFFFFFF),
    'Светлый': Color(0xFFF5F5F7),
    'Песок': Color(0xFFEDE7F6),
    'Дерево': Color(0xFFEFEBE9),
    'Серый паркет': Color(0xFFECEFF1),
    'Антрацит': Color(0xFF263238),
    'Обсидиан': Color(0xFF1E1E1E),
  };

  static const Map<String, Color> _wallColorPalette = {
    'Разделитель': Color(0xFF8D8D8D),
    'Темная стена': Color(0xFF37474F),
    'Светлая перегородка': Color(0xFFCFD8DC),
    'Дерево': Color(0xFF8D6E63),
    'Красный акцент': Color(0xFFEF5350),
  };

  @override
  Widget build(BuildContext context) {
    final zonesAsync = ref.watch(directKitchenZonesProvider);
    final tablesAsync = ref.watch(directKitchenTablesProvider);
    final wallsAsync = ref.watch(directKitchenWallsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Конструктор залов'),
        actions: [
          if (_selectedZoneId != null)
            IconButton(
              icon: const Icon(Icons.line_weight_rounded),
              tooltip: 'Добавить стену/перегородку',
              onPressed: () {
                if (_localWalls != null) {
                  final newWall = DirectKitchenWall(
                    id: const Uuid().v4(),
                    zoneId: _selectedZoneId!,
                    xPosition: 50.0,
                    yPosition: 50.0,
                    width: 100.0,
                    height: 12.0,
                    rotation: 0.0,
                    color: '#8D8D8D',
                  );
                  setState(() {
                    _localWalls!.add(newWall);
                    _selectedWall = newWall;
                    _selectedTable = null;
                  });
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.add_location_alt_rounded),
            tooltip: 'Добавить зону/этаж',
            onPressed: () => _showAddZoneDialog(),
          ),
        ],
      ),
      body: zonesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Ошибка загрузки залов: $err')),
        data: (zones) {
          // Auto-select first zone if none selected
          if (_selectedZoneId == null && zones.isNotEmpty) {
            _selectedZoneId = zones.first.id;
            _transformationController.value = Matrix4.identity()..scale(zones.first.defaultScale);
          }

          final activeZone = zones.where((z) => z.id == _selectedZoneId).firstOrNull;

          if (_selectedZoneId != null && activeZone == null && zones.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _selectedZoneId = zones.first.id;
                _selectedTable = null;
                _selectedWall = null;
                _transformationController.value = Matrix4.identity()..scale(zones.first.defaultScale);
              });
            });
          }

          if (activeZone != null) {
            if (_loadedZoneId != activeZone.id) {
              _loadedZoneId = activeZone.id;
              _localTables = null;
              _localWalls = null;
              _selectedTable = null;
              _selectedWall = null;
            }

            if (_localTables == null && tablesAsync.hasValue) {
              _localTables = tablesAsync.value!
                  .where((t) => t.zoneId == activeZone.id)
                  .toList();
            }
            if (_localWalls == null && wallsAsync.hasValue) {
              _localWalls = wallsAsync.value!
                  .where((w) => w.zoneId == activeZone.id)
                  .toList();
            }
          }

          return Column(
            children: [
              // ── Zone Tabs ──
              if (zones.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Center(
                    child: Column(
                      children: [
                        const Text('Нет созданных зон/этажей.'),
                        const SizedBox(height: AppSpacing.md),
                        ElevatedButton.icon(
                          onPressed: _showAddZoneDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Создать первый зал'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                _buildZoneTabs(zones, cs),

              // ── Designer Canvas ──
              if (activeZone != null)
                Expanded(
                  child: Row(
                    children: [
                      // Layout Canvas
                      Expanded(
                        flex: 3,
                        child: _buildCanvas(
                          _localTables ?? [],
                          _localWalls ?? [],
                          activeZone,
                          cs,
                        ),
                      ),

                      // Sidebar Properties Panel (when table selected)
                      if (_selectedTable != null)
                        Container(
                          width: 320,
                          decoration: BoxDecoration(
                            border: Border(left: BorderSide(color: cs.outline.withValues(alpha: 0.2))),
                            color: cs.surfaceContainerHighest.withValues(alpha: 0.1),
                          ),
                          child: Builder(
                            builder: (context) {
                              final latestTable = _localTables?.where((t) => t.id == _selectedTable!.id).firstOrNull;
                              if (latestTable == null) return const SizedBox.shrink();
                              return _buildSidebarProperties(latestTable, zones, cs);
                            },
                          ),
                        ),

                      // Sidebar Properties Panel (when wall selected)
                      if (_selectedWall != null)
                        Container(
                          width: 320,
                          decoration: BoxDecoration(
                            border: Border(left: BorderSide(color: cs.outline.withValues(alpha: 0.2))),
                            color: cs.surfaceContainerHighest.withValues(alpha: 0.1),
                          ),
                          child: Builder(
                            builder: (context) {
                              final latestWall = _localWalls?.where((w) => w.id == _selectedWall!.id).firstOrNull;
                              if (latestWall == null) return const SizedBox.shrink();
                              return _buildWallSidebarProperties(latestWall, cs);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildZoneTabs(List<DirectKitchenZone> zones, ColorScheme cs) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          ...zones.map((zone) {
            final isSelected = zone.id == _selectedZoneId;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(zone.name),
                selected: isSelected,
                onSelected: (val) {
                  setState(() {
                    _selectedZoneId = zone.id;
                    _selectedTable = null;
                    _selectedWall = null;
                    _transformationController.value = Matrix4.identity()..scale(zone.defaultScale);
                  });
                },
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                checkmarkColor: AppColors.primary,
              ),
            );
          }),
          const SizedBox(width: AppSpacing.sm),
          IconButton.filledTonal(
            icon: const Icon(Icons.edit_rounded, size: 18),
            tooltip: 'Редактировать текущий зал',
            onPressed: _selectedZoneId != null
                ? () {
                    final zone = zones.firstWhere((z) => z.id == _selectedZoneId);
                    _showEditZoneDialog(zone);
                  }
                : null,
          ),
          const SizedBox(width: AppSpacing.xs),
          IconButton.filledTonal(
            icon: const Icon(Icons.format_color_fill_rounded, size: 18),
            tooltip: 'Цвет пола',
            onPressed: _selectedZoneId != null
                ? () {
                    final zone = zones.firstWhere((z) => z.id == _selectedZoneId);
                    _showFloorColorDialog(zone);
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas(
    List<DirectKitchenTable> tables,
    List<DirectKitchenWall> walls,
    DirectKitchenZone zone,
    ColorScheme cs,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double canvasWidth = 1000.0;
        const double canvasHeight = 1000.0;
        final floorColor = _parseHexColor(zone.backgroundColor, cs.surfaceContainerHighest.withValues(alpha: 0.05));

        return Container(
          color: floorColor,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.2,
                  maxScale: 3.0,
                  boundaryMargin: const EdgeInsets.all(800.0),
                  panEnabled: _activeTool == DesignerTool.select,
                  scaleEnabled: _activeTool == DesignerTool.select,
                  child: Center(
                    child: Container(
                      width: canvasWidth,
                      height: canvasHeight,
                      decoration: BoxDecoration(
                        color: floorColor,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 16,
                            spreadRadius: 4,
                          )
                        ],
                      ),
                      child: GestureDetector(
                        onTap: _activeTool == DesignerTool.select
                            ? () {
                                setState(() {
                                  _selectedTable = null;
                                  _selectedWall = null;
                                });
                              }
                            : null,
                        onPanStart: _activeTool == DesignerTool.drawWall
                            ? (details) {
                                final localPos = details.localPosition;
                                setState(() {
                                  _drawStartPoint = _snapToGrid(localPos, 30.0);
                                  _drawCurrentPoint = _drawStartPoint;
                                });
                              }
                            : null,
                        onPanUpdate: _activeTool == DesignerTool.drawWall
                            ? (details) {
                                final localPos = details.localPosition;
                                setState(() {
                                  _drawCurrentPoint = _snapToGrid(localPos, 30.0);
                                });
                              }
                            : null,
                        onPanEnd: _activeTool == DesignerTool.drawWall
                            ? (details) {
                                if (_drawStartPoint != null && _drawCurrentPoint != null) {
                                  final dx = _drawCurrentPoint!.dx - _drawStartPoint!.dx;
                                  final dy = _drawCurrentPoint!.dy - _drawStartPoint!.dy;
                                  final length = math.sqrt(dx * dx + dy * dy);

                                  if (length > 15.0) {
                                    // Convert coordinates to percentages of canvas
                                    final x1Pct = (_drawStartPoint!.dx / canvasWidth) * 100;
                                    final y1Pct = (_drawStartPoint!.dy / canvasHeight) * 100;
                                    final x2Pct = (_drawCurrentPoint!.dx / canvasWidth) * 100;
                                    final y2Pct = (_drawCurrentPoint!.dy / canvasHeight) * 100;

                                    final cxPct = (x1Pct + x2Pct) / 2;
                                    final cyPct = (y1Pct + y2Pct) / 2;
                                    final rotationAngle = math.atan2(dy, dx) * 180 / math.pi;

                                    final newWall = DirectKitchenWall(
                                      id: const Uuid().v4(),
                                      zoneId: zone.id,
                                      xPosition: cxPct,
                                      yPosition: cyPct,
                                      width: length,
                                      height: 12.0, // standard wall thickness
                                      rotation: rotationAngle,
                                      color: '#8D8D8D',
                                    );
                                    setState(() {
                                      _localWalls!.add(newWall);
                                    });
                                  }
                                }
                                setState(() {
                                  _drawStartPoint = null;
                                  _drawCurrentPoint = null;
                                });
                              }
                            : null,
                        child: Container(
                          width: canvasWidth,
                          height: canvasHeight,
                          color: Colors.transparent,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Floor design grid indicators
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: GridPainter(cs.outline.withValues(alpha: 0.05)),
                                ),
                              ),

                              // Wall items
                              ...walls.map((wall) {
                                final double width = wall.width;
                                final double height = wall.height;

                                final double left = (wall.xPosition / 100) * canvasWidth - (width / 2);
                                final double top = (wall.yPosition / 100) * canvasHeight - (height / 2);

                                final isSelected = _selectedWall?.id == wall.id;

                                return Positioned(
                                  left: left,
                                  top: top,
                                  child: Transform.rotate(
                                    angle: wall.rotation * math.pi / 180,
                                    child: GestureDetector(
                                      onPanStart: _activeTool == DesignerTool.select
                                          ? (_) {
                                              setState(() {
                                                _selectedWall = wall;
                                                _selectedTable = null;
                                                _isDragging = true;
                                              });
                                            }
                                          : null,
                                      onPanUpdate: _activeTool == DesignerTool.select
                                          ? (details) {
                                              final double scale = _transformationController.value.getMaxScaleOnAxis();
                                              final double rad = wall.rotation * math.pi / 180;
                                              final double cosTheta = math.cos(rad);
                                              final double sinTheta = math.sin(rad);

                                              // Translate rotated local delta to global canvas delta
                                              final double globalDx = details.delta.dx * cosTheta - details.delta.dy * sinTheta;
                                              final double globalDy = details.delta.dx * sinTheta + details.delta.dy * cosTheta;

                                              _updateLocalWall(wall.id, (w) {
                                                final newX = (w.xPosition + ((globalDx / scale) / canvasWidth) * 100).clamp(2.0, 98.0);
                                                final newY = (w.yPosition + ((globalDy / scale) / canvasHeight) * 100).clamp(2.0, 98.0);
                                                return w.copyWith(xPosition: newX, yPosition: newY);
                                              });
                                            }
                                          : null,
                                      onPanEnd: _activeTool == DesignerTool.select
                                          ? (_) {
                                              setState(() {
                                                _isDragging = false;
                                              });
                                            }
                                          : null,
                                      onTap: _activeTool == DesignerTool.select
                                          ? () {
                                              setState(() {
                                                _selectedWall = wall;
                                                _selectedTable = null;
                                              });
                                            }
                                          : null,
                                      child: Container(
                                        width: width,
                                        height: height,
                                        decoration: BoxDecoration(
                                          color: _parseHexColor(wall.color, const Color(0xFF8D8D8D)),
                                          borderRadius: BorderRadius.circular(2),
                                          border: isSelected
                                              ? Border.all(color: AppColors.primary, width: 2.5)
                                              : null,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.2),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            )
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),

                              // Table items
                              ...tables.map((table) {
                                final double width = table.width;
                                final double height = table.height;

                                final double left = (table.xPosition / 100) * canvasWidth - (width / 2);
                                final double top = (table.yPosition / 100) * canvasHeight - (height / 2);

                                final isSelected = _selectedTable?.id == table.id;

                                return Positioned(
                                  left: left,
                                  top: top,
                                  child: GestureDetector(
                                    onPanStart: _activeTool == DesignerTool.select
                                        ? (_) {
                                            setState(() {
                                              _selectedTable = table;
                                              _selectedWall = null;
                                              _isDragging = true;
                                            });
                                          }
                                        : null,
                                    onPanUpdate: _activeTool == DesignerTool.select
                                        ? (details) {
                                            final double scale = _transformationController.value.getMaxScaleOnAxis();
                                            _updateLocalTable(table.id, (t) {
                                              final newX = (t.xPosition + ((details.delta.dx / scale) / canvasWidth) * 100).clamp(2.0, 98.0);
                                              final newY = (t.yPosition + ((details.delta.dy / scale) / canvasHeight) * 100).clamp(2.0, 98.0);
                                              return t.copyWith(xPosition: newX, yPosition: newY);
                                            });
                                          }
                                        : null,
                                    onPanEnd: _activeTool == DesignerTool.select
                                        ? (_) {
                                            setState(() {
                                              _isDragging = false;
                                            });
                                          }
                                        : null,
                                    onTap: _activeTool == DesignerTool.select
                                        ? () {
                                            setState(() {
                                              _selectedTable = table;
                                              _selectedWall = null;
                                            });
                                          }
                                        : null,
                                    child: Container(
                                      width: width,
                                      height: height,
                                      decoration: BoxDecoration(
                                        shape: table.shape == 'circle' ? BoxShape.circle : BoxShape.rectangle,
                                        borderRadius: table.shape == 'circle' ? null : BorderRadius.circular(8),
                                        color: isSelected
                                            ? AppColors.primary.withValues(alpha: 0.3)
                                            : (table.color != null
                                                ? _parseHexColor(table.color!, cs.surfaceContainerHighest.withValues(alpha: 0.5))
                                                : cs.surfaceContainerHighest.withValues(alpha: 0.5)),
                                        border: Border.all(
                                          color: isSelected ? AppColors.primary : cs.outline,
                                          width: isSelected ? 2.5 : 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.05),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          )
                                        ],
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              table.name,
                                              style: AppTypography.labelLarge.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: cs.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),

                              // Drawing Preview (Sims style)
                              if (_drawStartPoint != null && _drawCurrentPoint != null)
                                Positioned(
                                  left: ((_drawStartPoint!.dx + _drawCurrentPoint!.dx) / 2) - 
                                        (math.sqrt((_drawCurrentPoint!.dx - _drawStartPoint!.dx) * (_drawCurrentPoint!.dx - _drawStartPoint!.dx) + 
                                                   (_drawCurrentPoint!.dy - _drawStartPoint!.dy) * (_drawCurrentPoint!.dy - _drawStartPoint!.dy)) / 2),
                                  top: ((_drawStartPoint!.dy + _drawCurrentPoint!.dy) / 2) - 6.0,
                                  child: Transform.rotate(
                                    angle: math.atan2(_drawCurrentPoint!.dy - _drawStartPoint!.dy, _drawCurrentPoint!.dx - _drawStartPoint!.dx),
                                    child: Container(
                                      width: math.max(5.0, math.sqrt((_drawCurrentPoint!.dx - _drawStartPoint!.dx) * (_drawCurrentPoint!.dx - _drawStartPoint!.dx) + 
                                                       (_drawCurrentPoint!.dy - _drawStartPoint!.dy) * (_drawCurrentPoint!.dy - _drawStartPoint!.dy))),
                                      height: 12.0,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.4),
                                        borderRadius: BorderRadius.circular(2),
                                        border: Border.all(color: AppColors.primary, width: 1.5),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(alpha: 0.3),
                                            blurRadius: 8,
                                          )
                                        ],
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
                ),
              ),

              // Zoom controls floating card
              Positioned(
                bottom: AppSpacing.md,
                left: AppSpacing.md,
                child: Card(
                  elevation: 6,
                  color: cs.surface,
                  shadowColor: Colors.black.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.zoom_out_rounded),
                          tooltip: 'Отдалить',
                          onPressed: () {
                            final currentScale = _transformationController.value.getMaxScaleOnAxis();
                            final newScale = (currentScale - 0.1).clamp(0.2, 3.0);
                            setState(() {
                              _transformationController.value = Matrix4.identity()..scale(newScale);
                            });
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ListenableBuilder(
                            listenable: _transformationController,
                            builder: (context, _) {
                              final currentScale = _transformationController.value.getMaxScaleOnAxis();
                              return Text(
                                  '${(currentScale * 100).round()}%',
                                  style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.bold),
                                );
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.zoom_in_rounded),
                          tooltip: 'Приблизить',
                          onPressed: () {
                            final currentScale = _transformationController.value.getMaxScaleOnAxis();
                            final newScale = (currentScale + 0.1).clamp(0.2, 3.0);
                            setState(() {
                              _transformationController.value = Matrix4.identity()..scale(newScale);
                            });
                          },
                        ),
                        const SizedBox(width: 4),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save_rounded, size: 16),
                          label: const Text('Сохранить', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onPressed: () {
                            if (_localTables == null || _localWalls == null) return;
                            final currentScale = _transformationController.value.getMaxScaleOnAxis();
                            _safeAction(context, () async {
                              await KitchenDirectMutator.saveZoneLayout(
                                zoneId: zone.id,
                                tables: _localTables!,
                                walls: _localWalls!,
                                scale: currentScale,
                              );
                              if (context.mounted) {
                                showInfoSnackBar(context, ref, 'Изменения зала успешно сохранены!');
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Floating Tool Bar to switch tools
              Positioned(
                top: AppSpacing.md,
                left: AppSpacing.md,
                child: Card(
                  elevation: 6,
                  color: cs.surface,
                  shadowColor: Colors.black.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.touch_app_rounded),
                          tooltip: 'Инструмент: Выбор / Перемещение',
                          color: _activeTool == DesignerTool.select ? AppColors.primary : cs.onSurfaceVariant,
                          onPressed: () => setState(() {
                            _activeTool = DesignerTool.select;
                            _selectedTable = null;
                            _selectedWall = null;
                          }),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.line_weight_rounded),
                          tooltip: 'Инструмент: Рисовать стены (Полигоны)',
                          color: _activeTool == DesignerTool.drawWall ? AppColors.primary : cs.onSurfaceVariant,
                          onPressed: () => setState(() {
                            _activeTool = DesignerTool.drawWall;
                            _selectedTable = null;
                            _selectedWall = null;
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Floating Action Button to Add Table inside canvas
              if (_activeTool == DesignerTool.select)
                Positioned(
                  right: AppSpacing.lg,
                  bottom: AppSpacing.lg,
                  child: FloatingActionButton.extended(
                    onPressed: () {
                      final warehouseId = ref.read(selectedWarehouseIdProvider);
                      if (warehouseId != null && _localTables != null) {
                        final newTable = DirectKitchenTable(
                          id: const Uuid().v4(),
                          warehouseId: warehouseId,
                          name: 'Стол №${_localTables!.length + 1}',
                          status: 'available',
                          zoneId: zone.id,
                          xPosition: 50.0,
                          yPosition: 50.0,
                          width: 80.0,
                          height: 80.0,
                          shape: 'rectangle',
                        );
                        setState(() {
                          _localTables!.add(newTable);
                          _selectedTable = newTable;
                          _selectedWall = null;
                        });
                      }
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Добавить стол'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebarProperties(DirectKitchenTable table, List<DirectKitchenZone> zones, ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Свойства стола',
                style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() => _selectedTable = null),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Name field
          TextField(
            decoration: const InputDecoration(
              labelText: 'Название стола',
              border: OutlineInputBorder(),
            ),
            controller: TextEditingController(text: table.name)
              ..selection = TextSelection.fromPosition(TextPosition(offset: table.name.length)),
            onChanged: (val) {
              if (val.trim().isNotEmpty) {
                _updateLocalTable(table.id, (t) => t.copyWith(name: val.trim()));
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // Shape picker
          Text('Форма стола', style: AppTypography.labelMedium.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: AppSpacing.xs),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'rectangle', label: Text('Прямоугольный')),
              ButtonSegment(value: 'circle', label: Text('Круглый')),
            ],
            selected: {table.shape},
            onSelectionChanged: (set) {
              _updateLocalTable(table.id, (t) => t.copyWith(shape: set.first));
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // Custom color picker
          Text('Цвет стола', style: AppTypography.labelMedium.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Default color circle (clear custom color)
              GestureDetector(
                onTap: () {
                  _updateLocalTable(table.id, (t) => t.copyWith(clearColor: true));
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: table.color == null ? AppColors.primary : cs.outline.withValues(alpha: 0.3),
                      width: table.color == null ? 2.5 : 1.0,
                    ),
                  ),
                  child: table.color == null ? const Icon(Icons.check, size: 16, color: AppColors.primary) : null,
                ),
              ),
              ..._tableColorPalette.entries.map((entry) {
                final hex = '#${entry.value.value.toRadixString(16).substring(2).toUpperCase()}';
                final isSelected = table.color?.toUpperCase() == hex;

                return GestureDetector(
                  onTap: () {
                    _updateLocalTable(table.id, (t) => t.copyWith(color: hex));
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: entry.value,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        width: isSelected ? 2.5 : 0.0,
                      ),
                    ),
                    child: isSelected ? Icon(Icons.check, size: 16, color: entry.value.computeLuminance() > 0.5 ? Colors.black : Colors.white) : null,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Resize Sliders
          Text('Ширина стола (${table.width.toInt()} px)',
              style: AppTypography.labelMedium.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
          Slider(
            min: 50.0,
            max: 200.0,
            value: table.width,
            onChanged: (val) {
              _updateLocalTable(table.id, (t) => t.copyWith(width: val));
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('Высота стола (${table.height.toInt()} px)',
              style: AppTypography.labelMedium.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
          Slider(
            min: 50.0,
            max: 200.0,
            value: table.height,
            onChanged: (val) {
              _updateLocalTable(table.id, (t) => t.copyWith(height: val));
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // Move zone
          Text('Переместить в зону',
              style: AppTypography.labelMedium.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: AppSpacing.xs),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
            value: table.zoneId,
            items: zones.map((z) {
              return DropdownMenuItem<String>(
                value: z.id,
                child: Text(z.name),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                _updateLocalTable(table.id, (t) => t.copyWith(zoneId: val));
                setState(() {
                  _selectedTable = null; // Unselect as it moves zones
                });
              }
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'QR-код стола',
            style: AppTypography.labelMedium.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: Card(
              color: Colors.white,
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.network(
                  'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${Uri.encodeComponent('https://akjol.kg/order?tableId=${table.id}')}',
                  width: 150,
                  height: 150,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const SizedBox(
                      width: 150,
                      height: 150,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox(
                      width: 150,
                      height: 150,
                      child: Center(
                        child: Text(
                          'Ошибка загрузки QR',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: Text(
              'https://akjol.kg/order?tableId=${table.id}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Delete Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _confirmDeleteTable(table.id),
              icon: const Icon(Icons.delete_forever_rounded, color: Colors.white),
              label: const Text('Удалить стол', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddZoneDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Добавить зал / этаж'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Название (например: 2 этаж)'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              final warehouseId = ref.read(selectedWarehouseIdProvider);
              if (controller.text.trim().isNotEmpty && warehouseId != null) {
                _safeAction(ctx, () async {
                  await KitchenDirectMutator.createZone(controller.text.trim(), warehouseId);
                  if (ctx.mounted) Navigator.pop(ctx);
                });
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  void _showEditZoneDialog(DirectKitchenZone zone) {
    final controller = TextEditingController(text: zone.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Редактировать зал / этаж'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Название заведения'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () async {
              _safeAction(ctx, () async {
                Navigator.pop(ctx);
                await KitchenDirectMutator.deleteZone(zone.id);
                setState(() {
                  _selectedZoneId = null;
                  _selectedTable = null;
                });
              });
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Удалить зал'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                _safeAction(ctx, () async {
                  await KitchenDirectMutator.updateZone(zone.id, controller.text.trim());
                  if (ctx.mounted) Navigator.pop(ctx);
                });
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTable(String tableId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить стол?'),
        content: const Text('Это действие безвозвратно удалит стол из планировки.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _localTables?.removeWhere((t) => t.id == tableId);
                _selectedTable = null;
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteWall(String wallId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить перегородку?'),
        content: const Text('Это действие безвозвратно удалит стену из планировки.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _localWalls?.removeWhere((w) => w.id == wallId);
                _selectedWall = null;
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  void _showFloorColorDialog(DirectKitchenZone zone) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Цвет пола зала'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Выберите цвет или стиль покрытия:'),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _floorColorPalette.entries.map((entry) {
                final color = entry.value;
                final isSelected = zone.backgroundColor.toUpperCase() == '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
                
                return GestureDetector(
                  onTap: () {
                    _safeAction(ctx, () async {
                      await KitchenDirectMutator.updateZoneBackgroundColor(
                        zone.id,
                        '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    });
                  },
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.3),
                        width: isSelected ? 3.0 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Center(
                      child: Text(
                        entry.key,
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
        ],
      ),
    );
  }

  Widget _buildWallSidebarProperties(DirectKitchenWall wall, ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Перегородка',
                style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() => _selectedWall = null),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: AppSpacing.md),

          // Resize Width
          Text('Длина стены (${wall.width.toInt()} px)',
              style: AppTypography.labelMedium.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
          Slider(
            min: 20.0,
            max: 500.0,
            value: wall.width,
            onChanged: (val) {
              _updateLocalWall(wall.id, (w) => w.copyWith(width: val));
            },
          ),
          const SizedBox(height: AppSpacing.sm),

          // Resize Thickness
          Text('Толщина стены (${wall.height.toInt()} px)',
              style: AppTypography.labelMedium.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
          Slider(
            min: 5.0,
            max: 60.0,
            value: wall.height,
            onChanged: (val) {
              _updateLocalWall(wall.id, (w) => w.copyWith(height: val));
            },
          ),
          const SizedBox(height: AppSpacing.sm),

          // Rotation Slider
          Text('Поворот (${wall.rotation.toInt()}°)',
              style: AppTypography.labelMedium.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
          Slider(
            min: 0.0,
            max: 360.0,
            value: wall.rotation,
            onChanged: (val) {
              _updateLocalWall(wall.id, (w) => w.copyWith(rotation: val));
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // Color picker
          Text('Цвет перегородки', style: AppTypography.labelMedium.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _wallColorPalette.entries.map((entry) {
              final hex = '#${entry.value.value.toRadixString(16).substring(2).toUpperCase()}';
              final isSelected = wall.color.toUpperCase() == hex;

              return GestureDetector(
                onTap: () {
                  _updateLocalWall(wall.id, (w) => w.copyWith(color: hex));
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: entry.value,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : cs.outline.withValues(alpha: 0.3),
                      width: isSelected ? 2.5 : 1.0,
                    ),
                  ),
                  child: isSelected ? Icon(Icons.check, size: 16, color: entry.value.computeLuminance() > 0.5 ? Colors.black : Colors.white) : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Delete Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _confirmDeleteWall(wall.id),
              icon: const Icon(Icons.delete_forever_rounded, color: Colors.white),
              label: const Text('Удалить перегородку', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom grid background painter for visual alignment
class GridPainter extends CustomPainter {
  final Color gridColor;
  GridPainter(this.gridColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    const double step = 30.0;

    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
