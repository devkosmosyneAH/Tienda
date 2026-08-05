import 'package:tienda/Presentation/Context/pos_sale_provider.dart';
import 'package:tienda/Presentation/Controller/pos_controller.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────
//  Widget: Forma de Pago
// ─────────────────────────────────────────────────────────────────

class PosFormaPagoSection extends StatelessWidget {
  const PosFormaPagoSection({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PosController>();
    final sale = context.watch<PosSaleProvider>();

    final defaultId = controller.paymentMethods.isNotEmpty
        ? (controller.paymentMethods.first['id'] as num).toInt()
        : null;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Forma de Pago',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: controller.paymentMethods.map((m) {
                final id = (m['id'] as num).toInt();
                final isSelected = (sale.selectedPaymentMethodId ?? defaultId) == id;
                return GestureDetector(
                  onTap: () => context.read<PosSaleProvider>().selectPaymentMethod(id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.blackOverlay
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.blackOverlay
                            : Colors.black26,
                      ),
                    ),
                    child: Text(
                      m['name'].toString().toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : Colors.black87,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
