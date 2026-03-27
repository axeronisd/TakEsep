import 'package:flutter/material.dart';
import 'package:takesep_core/takesep_core.dart';

// ═════════════════════════════════════════════════════════════
// MOCK DATA — TakEsep Склад
// ═════════════════════════════════════════════════════════════

final mockToday = DateTime(2026, 3, 5);

// ─── Warehouses ─────────────────────────────────────────────
final mockWarehouses = <({String id, String name, String groupId})>[
  (id: 'wh1', name: 'Центральный склад', groupId: 'g1'),
  (id: 'wh2', name: 'Магазин Дордой', groupId: 'g1'),
  (id: 'wh3', name: 'Магазин ЦУМ', groupId: 'g1'),
];

// ─── Categories ─────────────────────────────────────────────
final mockCategories = <({String id, String name, IconData icon})>[
  (id: 'cat-phones', name: 'Телефоны', icon: Icons.phone_android_rounded),
  (id: 'cat-laptops', name: 'Ноутбуки', icon: Icons.laptop_mac_rounded),
  (id: 'cat-tablets', name: 'Планшеты', icon: Icons.tablet_mac_rounded),
  (id: 'cat-audio', name: 'Аудио', icon: Icons.headphones_rounded),
  (id: 'cat-wearables', name: 'Носимые', icon: Icons.watch_rounded),
  (id: 'cat-accessories', name: 'Аксессуары', icon: Icons.cable_rounded),
  (id: 'cat-shoes', name: 'Обувь', icon: Icons.shopping_bag_rounded),
];

// ─── Products ───────────────────────────────────────────────
final mockProducts = <Product>[
  Product(
      id: 'p1',
      name: 'iPhone 15 Pro 256GB',
      sku: 'APL-IP15P-256',
      barcode: '194253397120',
      categoryId: 'cat-phones',
      price: 89990,
      costPrice: 72000,
      quantity: 12,
      minQuantity: 5,
      companyId: 'default_company',
      warehouseId: 'wh1',
      createdAt: DateTime(2026, 1, 15),
      updatedAt: mockToday,
      lastSoldAt: mockToday,
      soldLast30Days: 14),
  Product(
      id: 'p2',
      name: 'Samsung Galaxy S24 Ultra',
      sku: 'SAM-S24U-256',
      barcode: '887276721040',
      categoryId: 'cat-phones',
      price: 74990,
      costPrice: 58000,
      quantity: 3,
      minQuantity: 10,
      companyId: 'default_company',
      warehouseId: 'wh1',
      createdAt: DateTime(2026, 1, 20),
      updatedAt: mockToday,
      lastSoldAt: mockToday,
      soldLast30Days: 8),
  Product(
      id: 'p3',
      name: 'AirPods Pro 2 USB-C',
      sku: 'APL-APP2-USC',
      barcode: '194253416524',
      categoryId: 'cat-audio',
      price: 18990,
      costPrice: 14200,
      quantity: 18,
      minQuantity: 8,
      companyId: 'default_company',
      warehouseId: 'wh1',
      createdAt: DateTime(2026, 2, 1),
      updatedAt: mockToday,
      lastSoldAt: mockToday,
      soldLast30Days: 22),
  Product(
      id: 'p4',
      name: 'MacBook Air M3 15"',
      sku: 'APL-MBA-M3-15',
      barcode: '194253411123',
      categoryId: 'cat-laptops',
      price: 109990,
      costPrice: 88000,
      quantity: 2,
      minQuantity: 5,
      criticalMin: 2,
      companyId: 'default_company',
      warehouseId: 'wh1',
      createdAt: DateTime(2026, 1, 10),
      updatedAt: mockToday,
      lastSoldAt: DateTime(2026, 3, 2),
      soldLast30Days: 4),
  Product(
      id: 'p5',
      name: 'Чехол iPhone 15 Pro MagSafe',
      sku: 'ACC-CAS-IP15P',
      barcode: '194253393015',
      categoryId: 'cat-accessories',
      price: 4990,
      costPrice: 1500,
      quantity: 35,
      minQuantity: 10,
      companyId: 'default_company',
      warehouseId: 'wh1',
      createdAt: DateTime(2026, 2, 10),
      updatedAt: mockToday,
      lastSoldAt: mockToday,
      soldLast30Days: 42),
  Product(
      id: 'p6',
      name: 'Samsung Galaxy Buds3 Pro',
      sku: 'SAM-GB3P',
      barcode: '887276826820',
      categoryId: 'cat-audio',
      price: 16990,
      costPrice: 12500,
      quantity: 10,
      minQuantity: 5,
      companyId: 'default_company',
      warehouseId: 'wh1',
      createdAt: DateTime(2026, 2, 5),
      updatedAt: mockToday,
      lastSoldAt: DateTime(2026, 3, 4),
      soldLast30Days: 11),
  Product(
      id: 'p7',
      name: 'Зарядка USB-C 65W GaN',
      sku: 'ACC-CHG-65W',
      barcode: '6943279243561',
      categoryId: 'cat-accessories',
      price: 2490,
      costPrice: 900,
      quantity: 5,
      minQuantity: 10,
      companyId: 'default_company',
      warehouseId: 'wh1',
      createdAt: DateTime(2026, 2, 15),
      updatedAt: mockToday,
      lastSoldAt: mockToday,
      soldLast30Days: 18),
  Product(
      id: 'p8',
      name: 'Apple Watch Ultra 2',
      sku: 'APL-AWU2-49',
      barcode: '194253487005',
      categoryId: 'cat-wearables',
      price: 64990,
      costPrice: 52000,
      quantity: 4,
      minQuantity: 3,
      companyId: 'default_company',
      warehouseId: 'wh1',
      createdAt: DateTime(2026, 1, 25),
      updatedAt: mockToday,
      lastSoldAt: DateTime(2026, 2, 28),
      soldLast30Days: 3),
  Product(
      id: 'p9',
      name: 'Nike Air Max 90',
      sku: 'NK-AM90-42',
      barcode: '194954563210',
      categoryId: 'cat-shoes',
      price: 8490,
      costPrice: 4200,
      quantity: 8,
      minQuantity: 15,
      companyId: 'default_company',
      warehouseId: 'wh1',
      createdAt: DateTime(2026, 2, 20),
      updatedAt: mockToday,
      lastSoldAt: DateTime(2026, 2, 15),
      soldLast30Days: 5),
  Product(
      id: 'p10',
      name: 'iPad Air M2 11"',
      sku: 'APL-IPA-M2-11',
      barcode: '194253832508',
      categoryId: 'cat-tablets',
      price: 54990,
      costPrice: 43000,
      quantity: 6,
      minQuantity: 3,
      companyId: 'default_company',
      warehouseId: 'wh1',
      createdAt: DateTime(2026, 1, 30),
      updatedAt: mockToday,
      lastSoldAt: mockToday,
      soldLast30Days: 5),
  Product(
      id: 'p11',
      name: 'Кабель Lightning-USB-C 2м',
      sku: 'ACC-CBL-LC2M',
      barcode: '6943279243578',
      categoryId: 'cat-accessories',
      price: 990,
      costPrice: 250,
      quantity: 42,
      minQuantity: 20,
      companyId: 'default_company',
      warehouseId: 'wh1',
      createdAt: DateTime(2026, 2, 1),
      updatedAt: mockToday,
      lastSoldAt: mockToday,
      soldLast30Days: 58),
  Product(
      id: 'p12',
      name: 'Плёнка защитная iPhone 15',
      sku: 'ACC-SCR-IP15',
      barcode: '6943279243585',
      categoryId: 'cat-accessories',
      price: 590,
      costPrice: 80,
      quantity: 55,
      minQuantity: 15,
      companyId: 'default_company',
      warehouseId: 'wh1',
      createdAt: DateTime(2026, 2, 1),
      updatedAt: mockToday,
      lastSoldAt: mockToday,
      soldLast30Days: 65),
  Product(
      id: 'p13',
      name: 'JBL Charge 5',
      sku: 'JBL-CHG5-BLK',
      barcode: '6925281982039',
      categoryId: 'cat-audio',
      price: 12990,
      costPrice: 8500,
      quantity: 7,
      minQuantity: 3,
      companyId: 'default_company',
      warehouseId: 'wh1',
      createdAt: DateTime(2026, 2, 10),
      updatedAt: mockToday,
      lastSoldAt: DateTime(2026, 2, 25),
      soldLast30Days: 6),
  Product(
      id: 'p14',
      name: 'Xiaomi Redmi Note 13 Pro',
      sku: 'XMI-RN13P-256',
      barcode: '6941812733486',
      categoryId: 'cat-phones',
      price: 24990,
      costPrice: 17500,
      quantity: 15,
      minQuantity: 5,
      companyId: 'default_company',
      warehouseId: 'wh1',
      createdAt: DateTime(2026, 2, 15),
      updatedAt: mockToday,
      lastSoldAt: mockToday,
      soldLast30Days: 18),
  Product(
      id: 'p15',
      name: 'PowerBank Anker 20000mAh',
      sku: 'ANK-PB-20K',
      barcode: '194644143855',
      categoryId: 'cat-accessories',
      price: 3490,
      costPrice: 1800,
      quantity: 20,
      minQuantity: 10,
      companyId: 'default_company',
      warehouseId: 'wh1',
      createdAt: DateTime(2026, 2, 20),
      updatedAt: mockToday,
      lastSoldAt: DateTime(2026, 3, 4),
      soldLast30Days: 12),
  Product(
      id: 'p16',
      name: 'Стекло Samsung S24 Ultra',
      sku: 'ACC-GL-S24U',
      barcode: '6943279243592',
      categoryId: 'cat-accessories',
      price: 790,
      costPrice: 120,
      quantity: 1,
      minQuantity: 10,
      criticalMin: 3,
      companyId: 'default_company',
      warehouseId: 'wh1',
      createdAt: DateTime(2026, 2, 1),
      updatedAt: DateTime(2026, 3, 4),
      lastSoldAt: DateTime(2026, 3, 4),
      soldLast30Days: 15),
  Product(
      id: 'p17',
      name: 'Lenovo Tab M11',
      sku: 'LNV-TM11',
      barcode: '196802345612',
      categoryId: 'cat-tablets',
      price: 18990,
      costPrice: 13500,
      quantity: 0,
      minQuantity: 3,
      companyId: 'default_company',
      warehouseId: 'wh1',
      createdAt: DateTime(2026, 2, 5),
      updatedAt: DateTime(2026, 3, 1),
      lastSoldAt: DateTime(2026, 2, 28),
      soldLast30Days: 3),
  Product(
      id: 'p18',
      name: 'Наушники Sony WH-1000XM5',
      sku: 'SNY-WH1KXM5',
      barcode: '027242923669',
      categoryId: 'cat-audio',
      price: 27990,
      costPrice: 21000,
      quantity: 150,
      minQuantity: 5,
      maxQuantity: 20,
      companyId: 'default_company',
      warehouseId: 'wh1',
      createdAt: DateTime(2026, 1, 15),
      updatedAt: mockToday,
      lastSoldAt: DateTime(2025, 12, 20),
      soldLast30Days: 0),
  Product(
      id: 'p19',
      name: 'USB-хаб Type-C 7в1',
      sku: 'ACC-HUB-7IN1',
      barcode: '6943279243608',
      categoryId: 'cat-accessories',
      price: 1990,
      costPrice: 650,
      quantity: 3,
      minQuantity: 10,
      companyId: 'default_company',
      warehouseId: 'wh1',
      createdAt: DateTime(2026, 2, 10),
      updatedAt: mockToday,
      lastSoldAt: DateTime(2026, 3, 3),
      soldLast30Days: 9),
  Product(
      id: 'p20',
      name: 'Adidas Ultraboost 23',
      sku: 'ADI-UB23-43',
      barcode: '4065427567890',
      categoryId: 'cat-shoes',
      price: 12490,
      costPrice: 6800,
      quantity: 4,
      minQuantity: 8,
      companyId: 'default_company',
      warehouseId: 'wh1',
      createdAt: DateTime(2026, 2, 15),
      updatedAt: mockToday,
      lastSoldAt: DateTime(2026, 1, 5),
      soldLast30Days: 1),
];

// ═════════════════════════════════════════════════════════════
// OPERATIONS — detailed
// ═════════════════════════════════════════════════════════════

enum OperationType { sale, income, transfer, audit, writeoff, payroll }

String operationTypeLabel(OperationType t) => switch (t) {
      OperationType.sale => 'Продажа',
      OperationType.income => 'Приход',
      OperationType.transfer => 'Перемещение',
      OperationType.audit => 'Ревизия',
      OperationType.writeoff => 'Списание',
      OperationType.payroll => 'Зарплата',
    };

IconData operationTypeIcon(OperationType t) => switch (t) {
      OperationType.sale => Icons.shopping_cart_rounded,
      OperationType.income => Icons.download_rounded,
      OperationType.transfer => Icons.swap_horiz_rounded,
      OperationType.audit => Icons.fact_check_rounded,
      OperationType.writeoff => Icons.delete_rounded,
      OperationType.payroll => Icons.payments_rounded,
    };

Color operationTypeColor(OperationType t) => switch (t) {
      OperationType.sale => const Color(0xFF6C5CE7),
      OperationType.income => const Color(0xFF00B894),
      OperationType.transfer => const Color(0xFF0984E3),
      OperationType.audit => const Color(0xFFFDAA5E),
      OperationType.writeoff => const Color(0xFFE17055),
      OperationType.payroll => const Color(0xFF636E72),
    };

/// Item in a sale
class SaleItem {
  final String productName;
  final int qty;
  final double price;
  final double discount;
  final String? service;
  const SaleItem(
      {required this.productName,
      required this.qty,
      required this.price,
      this.discount = 0,
      this.service});
}

/// Item in an income operation
class IncomeItem {
  final String productName;
  final int qty;
  final double costPrice;
  final double sellPrice;
  const IncomeItem(
      {required this.productName,
      required this.qty,
      required this.costPrice,
      required this.sellPrice});
}

/// Transfer status
enum TransferStatus { pending, inTransit, accepted, rejected }

String transferStatusLabel(TransferStatus s) => switch (s) {
      TransferStatus.pending => 'Ожидает',
      TransferStatus.inTransit => 'В пути',
      TransferStatus.accepted => 'Принято',
      TransferStatus.rejected => 'Отклонено',
    };

/// Transfer item
class TransferItem {
  final String productName;
  final int qty;
  const TransferItem({required this.productName, required this.qty});
}

/// Audit result item
class AuditItem {
  final String productName;
  final int expected;
  final int actual;
  final double costPrice;
  final double sellPrice;
  const AuditItem(
      {required this.productName,
      required this.expected,
      required this.actual,
      required this.costPrice,
      required this.sellPrice});
  int get diff => actual - expected;
  bool get isShortage => diff < 0;
  bool get isSurplus => diff > 0;
}

class MockOperation {
  final String id;
  final String title;
  final OperationType type;
  final DateTime dateTime;
  final double total;
  final int itemCount;
  final String employee;
  final String? comment;

  // Sale details
  final List<SaleItem> saleItems;
  final String? paymentMethod;

  // Income details
  final List<IncomeItem> incomeItems;
  final String? supplier;

  // Transfer details
  final List<TransferItem> transferItems;
  final String? fromWarehouse;
  final String? toWarehouse;
  final TransferStatus? transferStatus;
  final DateTime? acceptedAt;

  // Audit details
  final List<AuditItem> auditItems;
  final DateTime? auditEndTime;

  // Writeoff
  final String? writeoffReason;

  // Payroll
  final String? payrollEmployee;
  final double? payrollAmount;

  const MockOperation({
    required this.id,
    required this.title,
    required this.type,
    required this.dateTime,
    required this.total,
    required this.itemCount,
    this.employee = 'Азамат К.',
    this.comment,
    this.saleItems = const [],
    this.paymentMethod,
    this.incomeItems = const [],
    this.supplier,
    this.transferItems = const [],
    this.fromWarehouse,
    this.toWarehouse,
    this.transferStatus,
    this.acceptedAt,
    this.auditItems = const [],
    this.auditEndTime,
    this.writeoffReason,
    this.payrollEmployee,
    this.payrollAmount,
  });
}

final mockOperations = <MockOperation>[
  // ── Today ──
  MockOperation(
      id: 'op1',
      title: 'Продажа №1247',
      type: OperationType.sale,
      dateTime: DateTime(2026, 3, 5, 14, 32),
      total: 45800,
      itemCount: 3,
      employee: 'Азамат К.',
      paymentMethod: 'Наличные',
      comment: 'Постоянный клиент',
      saleItems: [
        const SaleItem(
            productName: 'Чехол iPhone 15 Pro MagSafe',
            qty: 2,
            price: 4990,
            discount: 500),
        const SaleItem(
            productName: 'Плёнка защитная iPhone 15', qty: 3, price: 590),
        const SaleItem(
            productName: 'Кабель Lightning-USB-C 2м',
            qty: 5,
            price: 990,
            service: 'Установка плёнки')
      ]),
  MockOperation(
      id: 'op2',
      title: 'Приход ПР-00012',
      type: OperationType.income,
      dateTime: DateTime(2026, 3, 5, 12, 15),
      total: 782000,
      itemCount: 15,
      employee: 'Нурсултан А.',
      supplier: 'ТОО «Apple KG»',
      incomeItems: [
        const IncomeItem(
            productName: 'iPhone 15 Pro 256GB',
            qty: 5,
            costPrice: 72000,
            sellPrice: 89990),
        const IncomeItem(
            productName: 'AirPods Pro 2 USB-C',
            qty: 10,
            costPrice: 14200,
            sellPrice: 18990)
      ]),
  MockOperation(
      id: 'op3',
      title: 'Продажа №1246',
      type: OperationType.sale,
      dateTime: DateTime(2026, 3, 5, 11, 48),
      total: 23400,
      itemCount: 2,
      employee: 'Айдай М.',
      paymentMethod: 'Элсом',
      saleItems: [
        const SaleItem(
            productName: 'Xiaomi Redmi Note 13 Pro',
            qty: 1,
            price: 24990,
            discount: 1590)
      ]),
  MockOperation(
      id: 'op4',
      title: 'Перемещение ПМ-45',
      type: OperationType.transfer,
      dateTime: DateTime(2026, 3, 5, 10, 30),
      total: 0,
      itemCount: 5,
      employee: 'Азамат К.',
      fromWarehouse: 'Центральный склад',
      toWarehouse: 'Магазин Дордой',
      transferStatus: TransferStatus.inTransit,
      transferItems: [
        const TransferItem(productName: 'Чехол iPhone 15 Pro MagSafe', qty: 3),
        const TransferItem(productName: 'Плёнка защитная iPhone 15', qty: 10)
      ]),
  MockOperation(
      id: 'op5',
      title: 'Продажа №1245',
      type: OperationType.sale,
      dateTime: DateTime(2026, 3, 5, 9, 55),
      total: 199980,
      itemCount: 2,
      employee: 'Нурсултан А.',
      paymentMethod: 'Карта',
      saleItems: [
        const SaleItem(
            productName: 'MacBook Air M3 15"', qty: 1, price: 109990),
        const SaleItem(productName: 'iPhone 15 Pro 256GB', qty: 1, price: 89990)
      ]),
  MockOperation(
      id: 'op9',
      title: 'Списание СП-007',
      type: OperationType.writeoff,
      dateTime: DateTime(2026, 3, 5, 8, 45),
      total: 2490,
      itemCount: 1,
      employee: 'Азамат К.',
      writeoffReason: 'Брак — повреждена упаковка',
      saleItems: [
        const SaleItem(
            productName: 'Зарядка USB-C 65W GaN', qty: 1, price: 2490)
      ]),
  MockOperation(
      id: 'op10',
      title: 'Зарплата',
      type: OperationType.payroll,
      dateTime: DateTime(2026, 3, 5, 8, 0),
      total: 35000,
      itemCount: 1,
      employee: 'Администратор',
      payrollEmployee: 'Азамат К.',
      payrollAmount: 35000),
  // ── Yesterday ──
  MockOperation(
      id: 'op6',
      title: 'Продажа №1244',
      type: OperationType.sale,
      dateTime: DateTime(2026, 3, 4, 17, 20),
      total: 93980,
      itemCount: 4,
      employee: 'Азамат К.',
      paymentMethod: 'О!Деньги',
      saleItems: [
        const SaleItem(
            productName: 'Samsung Galaxy S24 Ultra', qty: 1, price: 74990),
        const SaleItem(productName: 'AirPods Pro 2 USB-C', qty: 1, price: 18990)
      ]),
  MockOperation(
      id: 'op7',
      title: 'Приход ПР-00011',
      type: OperationType.income,
      dateTime: DateTime(2026, 3, 4, 14, 0),
      total: 1250000,
      itemCount: 25,
      employee: 'Нурсултан А.',
      supplier: 'Samsung Electronics KG',
      incomeItems: [
        const IncomeItem(
            productName: 'Samsung Galaxy S24 Ultra',
            qty: 10,
            costPrice: 58000,
            sellPrice: 74990),
        const IncomeItem(
            productName: 'Samsung Galaxy Buds3 Pro',
            qty: 15,
            costPrice: 12500,
            sellPrice: 16990)
      ]),
  MockOperation(
      id: 'op8',
      title: 'Ревизия РВ-003',
      type: OperationType.audit,
      dateTime: DateTime(2026, 3, 4, 10, 0),
      total: 0,
      itemCount: 120,
      employee: 'Айдай М.',
      auditEndTime: DateTime(2026, 3, 4, 14, 30),
      auditItems: [
        const AuditItem(
            productName: 'Плёнка защитная iPhone 15',
            expected: 60,
            actual: 55,
            costPrice: 80,
            sellPrice: 590),
        const AuditItem(
            productName: 'Кабель Lightning-USB-C 2м',
            expected: 45,
            actual: 42,
            costPrice: 250,
            sellPrice: 990),
        const AuditItem(
            productName: 'PowerBank Anker 20000mAh',
            expected: 19,
            actual: 20,
            costPrice: 1800,
            sellPrice: 3490)
      ]),
  // ── Earlier this week ──
  MockOperation(
      id: 'op11',
      title: 'Продажа №1242',
      type: OperationType.sale,
      dateTime: DateTime(2026, 3, 3, 16, 45),
      total: 74990,
      itemCount: 1,
      employee: 'Азамат К.',
      paymentMethod: 'Карта'),
  MockOperation(
      id: 'op12',
      title: 'Перемещение ПМ-44',
      type: OperationType.transfer,
      dateTime: DateTime(2026, 3, 3, 11, 10),
      total: 0,
      itemCount: 3,
      employee: 'Нурсултан А.',
      fromWarehouse: 'Магазин ЦУМ',
      toWarehouse: 'Центральный склад',
      transferStatus: TransferStatus.accepted,
      acceptedAt: DateTime(2026, 3, 3, 14, 0),
      transferItems: [
        const TransferItem(productName: 'Nike Air Max 90', qty: 3)
      ]),
  MockOperation(
      id: 'op13',
      title: 'Продажа №1240',
      type: OperationType.sale,
      dateTime: DateTime(2026, 3, 2, 15, 30),
      total: 37480,
      itemCount: 2,
      employee: 'Айдай М.',
      paymentMethod: 'Наличные'),
  MockOperation(
      id: 'op14',
      title: 'Зарплата',
      type: OperationType.payroll,
      dateTime: DateTime(2026, 3, 1, 9, 0),
      total: 75000,
      itemCount: 2,
      employee: 'Администратор',
      payrollEmployee: 'Айдай М.',
      payrollAmount: 40000),
  MockOperation(
      id: 'op15',
      title: 'Продажа №1238',
      type: OperationType.sale,
      dateTime: DateTime(2026, 3, 1, 10, 5),
      total: 89990,
      itemCount: 1,
      employee: 'Нурсултан А.',
      paymentMethod: 'Карта'),
];

// ═════════════════════════════════════════════════════════════
// KPI MODEL
// ═════════════════════════════════════════════════════════════

class DashboardKpi {
  final String label;
  final double value;
  final double changePercent;
  final String compareLabel;
  final IconData icon;
  final Color iconColor;
  final bool isCurrency;

  const DashboardKpi(
      {required this.label,
      required this.value,
      required this.changePercent,
      required this.compareLabel,
      required this.icon,
      required this.iconColor,
      this.isCurrency = true});

  String get formattedValue =>
      isCurrency ? formatMoney(value) : value.toInt().toString();
}

// ═════════════════════════════════════════════════════════════
// CHART DATA — generated correctly
// ═════════════════════════════════════════════════════════════

class ChartPoint {
  final String label;
  final double revenue;
  final double profit;
  const ChartPoint(
      {required this.label, required this.revenue, required this.profit});
}

/// Generate hourly data for a day (0..23), in strict order
List<ChartPoint> generateHourlyData() {
  final seed = [
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    18500,
    42300,
    68700,
    55200,
    31400,
    48900,
    62100,
    71500,
    53800,
    45600,
    38200,
    22100,
    15800,
    8900,
    3200,
    0
  ];
  return [
    for (int h = 0; h < 24; h++)
      ChartPoint(
          label: '${h.toString().padLeft(2, '0')}:00',
          revenue: seed[h].toDouble(),
          profit: seed[h] * 0.29),
  ];
}

/// Generate daily data for a week (Пн..Вс), in strict order
List<ChartPoint> generateWeeklyData() {
  const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  const revenues = [
    420000.0,
    380500.0,
    512300.0,
    487100.0,
    561800.0,
    448200.0,
    389500.0
  ];
  return [
    for (int i = 0; i < 7; i++)
      ChartPoint(
          label: days[i], revenue: revenues[i], profit: revenues[i] * 0.29),
  ];
}

/// Generate daily data for a month, respecting actual days in month
List<ChartPoint> generateMonthlyData(int year, int month) {
  final daysInMonth = DateUtils.getDaysInMonth(year, month);
  final base = [
    320000,
    385000,
    412000,
    367000,
    498000,
    523000,
    445000,
    389000,
    510000,
    475000,
    362000,
    428000,
    553000,
    491000,
    380000,
    467000,
    520000,
    445000,
    398000,
    512000,
    476000,
    358000,
    422000,
    548000,
    487000,
    395000,
    462000,
    518000,
    441000,
    385000,
    502000
  ];
  return [
    for (int d = 0; d < daysInMonth; d++)
      ChartPoint(
          label: '${d + 1}',
          revenue: base[d % base.length].toDouble(),
          profit: base[d % base.length] * 0.29),
  ];
}

// ═════════════════════════════════════════════════════════════
// TOP PRODUCTS
// ═════════════════════════════════════════════════════════════

class TopProduct {
  final String name;
  final int soldCount;
  final double totalRevenue;
  final double totalProfit;
  final double margin;
  final DateTime lastSoldAt;
  const TopProduct(
      {required this.name,
      required this.soldCount,
      required this.totalRevenue,
      required this.totalProfit,
      required this.margin,
      required this.lastSoldAt});
}

class TopExecutor {
  final String executorId;
  final String executorName;
  final int servicesCount;
  final double totalRevenue;
  final DateTime lastServiceAt;
  
  const TopExecutor({
    required this.executorId,
    required this.executorName,
    required this.servicesCount,
    required this.totalRevenue,
    required this.lastServiceAt,
  });
}

class TopClient {
  final String clientId;
  final String clientName;
  final int purchasesCount;
  final double totalSpent;
  final DateTime lastPurchaseAt;

  const TopClient({
    required this.clientId,
    required this.clientName,
    required this.purchasesCount,
    required this.totalSpent,
    required this.lastPurchaseAt,
  });
}

final mockTopProducts = <TopProduct>[
  TopProduct(
      name: 'Плёнка защитная iPhone 15',
      soldCount: 65,
      totalRevenue: 38350,
      totalProfit: 33150,
      margin: 86.4,
      lastSoldAt: mockToday),
  TopProduct(
      name: 'Кабель Lightning-USB-C 2м',
      soldCount: 58,
      totalRevenue: 57420,
      totalProfit: 42920,
      margin: 74.7,
      lastSoldAt: mockToday),
  TopProduct(
      name: 'Чехол iPhone 15 Pro MagSafe',
      soldCount: 42,
      totalRevenue: 209580,
      totalProfit: 146580,
      margin: 69.9,
      lastSoldAt: mockToday),
  TopProduct(
      name: 'AirPods Pro 2 USB-C',
      soldCount: 22,
      totalRevenue: 417780,
      totalProfit: 105380,
      margin: 25.2,
      lastSoldAt: mockToday),
  TopProduct(
      name: 'Зарядка USB-C 65W GaN',
      soldCount: 18,
      totalRevenue: 44820,
      totalProfit: 28620,
      margin: 63.9,
      lastSoldAt: mockToday),
  TopProduct(
      name: 'Xiaomi Redmi Note 13 Pro',
      soldCount: 18,
      totalRevenue: 449820,
      totalProfit: 134820,
      margin: 30.0,
      lastSoldAt: mockToday),
  TopProduct(
      name: 'Стекло Samsung S24 Ultra',
      soldCount: 15,
      totalRevenue: 11850,
      totalProfit: 10050,
      margin: 84.8,
      lastSoldAt: DateTime(2026, 3, 4)),
  TopProduct(
      name: 'iPhone 15 Pro 256GB',
      soldCount: 14,
      totalRevenue: 1259860,
      totalProfit: 251860,
      margin: 20.0,
      lastSoldAt: mockToday),
  TopProduct(
      name: 'PowerBank Anker 20000mAh',
      soldCount: 12,
      totalRevenue: 41880,
      totalProfit: 20280,
      margin: 48.4,
      lastSoldAt: DateTime(2026, 3, 4)),
  TopProduct(
      name: 'Samsung Galaxy Buds3 Pro',
      soldCount: 11,
      totalRevenue: 186890,
      totalProfit: 49390,
      margin: 26.4,
      lastSoldAt: DateTime(2026, 3, 4)),
  TopProduct(
      name: 'USB-хаб Type-C 7в1',
      soldCount: 9,
      totalRevenue: 17910,
      totalProfit: 12060,
      margin: 67.3,
      lastSoldAt: DateTime(2026, 3, 3)),
  TopProduct(
      name: 'Samsung Galaxy S24 Ultra',
      soldCount: 8,
      totalRevenue: 599920,
      totalProfit: 135920,
      margin: 22.7,
      lastSoldAt: mockToday),
  TopProduct(
      name: 'JBL Charge 5',
      soldCount: 6,
      totalRevenue: 77940,
      totalProfit: 26940,
      margin: 34.6,
      lastSoldAt: DateTime(2026, 2, 25)),
  TopProduct(
      name: 'iPad Air M2 11"',
      soldCount: 5,
      totalRevenue: 274950,
      totalProfit: 59950,
      margin: 21.8,
      lastSoldAt: mockToday),
  TopProduct(
      name: 'Nike Air Max 90',
      soldCount: 5,
      totalRevenue: 42450,
      totalProfit: 21450,
      margin: 50.5,
      lastSoldAt: DateTime(2026, 2, 15)),
  TopProduct(
      name: 'MacBook Air M3 15"',
      soldCount: 4,
      totalRevenue: 439960,
      totalProfit: 87960,
      margin: 20.0,
      lastSoldAt: DateTime(2026, 3, 2)),
  TopProduct(
      name: 'Apple Watch Ultra 2',
      soldCount: 3,
      totalRevenue: 194970,
      totalProfit: 38970,
      margin: 20.0,
      lastSoldAt: DateTime(2026, 2, 28)),
  TopProduct(
      name: 'Lenovo Tab M11',
      soldCount: 3,
      totalRevenue: 56970,
      totalProfit: 16470,
      margin: 28.9,
      lastSoldAt: DateTime(2026, 2, 28)),
  TopProduct(
      name: 'Adidas Ultraboost 23',
      soldCount: 1,
      totalRevenue: 12490,
      totalProfit: 5690,
      margin: 45.6,
      lastSoldAt: DateTime(2026, 1, 5)),
  TopProduct(
      name: 'Наушники Sony WH-1000XM5',
      soldCount: 0,
      totalRevenue: 0,
      totalProfit: 0,
      margin: 25.0,
      lastSoldAt: DateTime(2025, 12, 20)),
];

// ═════════════════════════════════════════════════════════════
// STOCK ZONE HELPERS
// ═════════════════════════════════════════════════════════════

List<Product> getStockAlertProducts() =>
    mockProducts.where((p) => p.stockZone != StockZone.normal).toList();

List<Product> getProductsByZone(StockZone zone) =>
    mockProducts.where((p) => p.stockZone == zone).toList();

enum StockSortField { quantity, velocity, stale }

List<Product> sortStockAlerts(
    List<Product> items, StockSortField field, bool ascending) {
  final sorted = [...items];
  sorted.sort((a, b) {
    int result;
    switch (field) {
      case StockSortField.quantity:
        result = a.quantity.compareTo(b.quantity);
      case StockSortField.velocity:
        result = a.soldLast30Days.compareTo(b.soldLast30Days);
      case StockSortField.stale:
        final aDays = a.lastSoldAt != null
            ? mockToday.difference(a.lastSoldAt!).inDays
            : 999;
        final bDays = b.lastSoldAt != null
            ? mockToday.difference(b.lastSoldAt!).inDays
            : 999;
        result = bDays.compareTo(aDays);
    }
    return ascending ? result : -result;
  });
  return sorted;
}

// ═════════════════════════════════════════════════════════════
// FORMATTING — exact
// ═════════════════════════════════════════════════════════════

String formatMoney(double amount, [String currencySymbol = 'сом']) {
  final n = amount.toInt();
  final formatted = n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
  return '$formatted $currencySymbol';
}

String formatDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';

String formatDateTime(DateTime dt) =>
    '${formatDate(dt)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

String formatTime(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
