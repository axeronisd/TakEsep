import 'package:flutter/material.dart';
import '../../theme/akjol_theme.dart';

class OrderTrackingScreen extends StatelessWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Статус заказа')),
      body: const Center(child: Text('Отслеживание заказа')),
    );
  }
}
