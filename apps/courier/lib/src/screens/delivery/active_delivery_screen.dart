import 'package:flutter/material.dart';
import '../../theme/akjol_theme.dart';

class ActiveDeliveryScreen extends StatelessWidget {
  final String orderId;
  const ActiveDeliveryScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Доставка')),
      body: const Center(child: Text('Активная доставка — навигация')),
    );
  }
}
