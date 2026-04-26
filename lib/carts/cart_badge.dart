import 'package:flutter/material.dart';
import 'cart_counter.dart';

class CartBadge extends StatelessWidget {
  final VoidCallback? onTap;
  const CartBadge({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: CartCounter.count,
      builder: (_, value, __) {
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              tooltip: 'السلة',
              icon: const Icon(Icons.shopping_cart_outlined),
              onPressed: onTap,
            ),
            if (value > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(minWidth: 18),
                  child: Text(
                    value > 99 ? "99+" : "$value",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
