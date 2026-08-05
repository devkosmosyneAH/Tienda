import 'package:tienda/Presentation/Context/pos_sale_provider.dart';
import 'package:tienda/Presentation/Controller/pos_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────
//  Widget: Pagos Recibidos (multi-pago)
// ─────────────────────────────────────────────────────────────────

class PosPagosRecibidosSection extends StatelessWidget {
  final double total;

  const PosPagosRecibidosSection({
    super.key,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final sale = context.watch<PosSaleProvider>();
    final payments = sale.payments;
    final received = sale.paymentsTotal;
    final change = received - total;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pagos recibidos',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                TextButton.icon(
                  onPressed: () => context
                      .read<PosSaleProvider>()
                      .addPayment(
                        context.read<PosController>().paymentMethods,
                        total,
                      ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Agregar pago'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blueAccent,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            if (payments.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Sin pagos registrados',
                  style: TextStyle(color: Colors.black38, fontSize: 13),
                ),
              )
            else ...[
              for (int i = 0; i < payments.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.payments_outlined,
                        size: 18,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(payments[i].methodName)),
                      Text(
                        '\$${payments[i].amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () =>
                            context.read<PosSaleProvider>().removePayment(i),
                        child: const Icon(Icons.close, size: 16),
                      ),
                    ],
                  ),
                ),
              if (change > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text(
                        'Cambio: ',
                        style: TextStyle(color: Colors.green),
                      ),
                      Text(
                        '\$${change.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
