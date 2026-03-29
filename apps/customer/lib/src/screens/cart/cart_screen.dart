import 'package:flutter/material.dart';
import '../../theme/akjol_theme.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Корзина')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined,
                size: 64, color: AkJolTheme.textTertiary),
            const SizedBox(height: 16),
            Text('Корзина пуста',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AkJolTheme.textSecondary)),
            const SizedBox(height: 8),
            Text('Добавьте товары из магазинов',
                style: TextStyle(color: AkJolTheme.textTertiary)),
          ],
        ),
      ),
    );
  }
}
