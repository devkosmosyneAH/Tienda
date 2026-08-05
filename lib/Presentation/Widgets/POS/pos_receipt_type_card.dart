import 'package:tienda/Presentation/Context/pos_sale_provider.dart';
import 'package:tienda/Presentation/Model/pos_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────
//  Widget: Tipo de comprobante
// ─────────────────────────────────────────────────────────────────

class PosReceiptTypeCard extends StatelessWidget {
  const PosReceiptTypeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final sale = context.watch<PosSaleProvider>();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Card(
          elevation: 2,
          color: const Color(0xFFF0EDEA),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tipo de comprobante',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButton<String>(
                      value: sale.receiptType,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      items: PosReceiptType.all
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          context.read<PosSaleProvider>().setReceiptType(v);
                        }
                      },
                    ),
                    const Text(
                      'Cada tipo tiene numeración independiente',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Fecha: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
