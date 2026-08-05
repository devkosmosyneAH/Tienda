import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────
//  Widget: Fila de un ítem en el carrito
// ─────────────────────────────────────────────────────────────────

class PosCartItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const PosCartItemRow({
    super.key,
    required this.item,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final price = item['price'] as double;
    final qty = item['quantity'] as int;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'].toString(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '\$${price.toStringAsFixed(2)} c/u',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDecrement,
            icon: const Icon(Icons.remove_circle_outline, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Text(
                '$qty',
                key: ValueKey(qty),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onIncrement,
            icon: const Icon(Icons.add_circle_outline, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              '\$${(price * qty).toStringAsFixed(2)}',
              key: ValueKey(price * qty),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
