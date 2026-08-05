import 'package:tienda/Presentation/Controller/pos_controller.dart';
import 'package:tienda/Presentation/Widgets/POS/pos_cart_item_row.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────
//  Widget: Sección de Productos / Carrito
// ─────────────────────────────────────────────────────────────────

class PosProductosSection extends StatelessWidget {
  final void Function(BuildContext, PosController) onShowProductSearch;

  const PosProductosSection({
    super.key,
    required this.onShowProductSearch,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PosController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Productos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (controller.cart.isNotEmpty)
              Text(
                '${controller.totalItems} unidades',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.blackOverlay,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => onShowProductSearch(context, controller),
          icon: const Icon(Icons.search, size: 18),
          label: const Text('Buscar Producto'),
        ),
        if (controller.errorMessage != null) ...[
          const SizedBox(height: 6),
          Text(
            controller.errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
        ],
        if (controller.cart.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            elevation: 4,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                for (int i = 0; i < controller.cart.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  PosCartItemRow(
                    item: controller.cart[i],
                    onDecrement: () => controller.decrementQuantity(
                      controller.cart[i]['product_id'] as int,
                    ),
                    onIncrement: () => controller.incrementQuantity(
                      controller.cart[i]['product_id'] as int,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
