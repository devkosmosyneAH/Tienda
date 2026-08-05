import 'package:tienda/Presentation/Controller/pos_controller.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────
//  Tab: Historial de Ventas
// ─────────────────────────────────────────────────────────────────

class PosSalesHistoryTab extends StatelessWidget {
  const PosSalesHistoryTab({super.key});

  static const _months = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<PosController>(
      builder: (context, controller, _) {
        final currentYear = DateTime.now().year;
        final years = List.generate(currentYear - 2019, (i) => currentYear - i);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Cabecera
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  const Text(
                    'Historial de Ventas',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: controller.loadSalesHistory,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Actualizar'),
                  ),
                ],
              ),
            ),
            // ── Panel de filtros
            Container(
              color: Colors.grey.shade50,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filtros de Búsqueda',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _FilterDropdown<int?>(
                          label: 'Año:',
                          value: controller.historyYear,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Todos los años'),
                            ),
                            ...years.map(
                              (y) => DropdownMenuItem(
                                value: y,
                                child: Text(y.toString()),
                              ),
                            ),
                          ],
                          onChanged: controller.setHistoryYear,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FilterDropdown<int?>(
                          label: 'Mes:',
                          value: controller.historyMonth,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Todos'),
                            ),
                            ...List.generate(
                              12,
                              (i) => DropdownMenuItem(
                                value: i + 1,
                                child: Text(_months[i]),
                              ),
                            ),
                          ],
                          onChanged: controller.historyYear == null
                              ? null
                              : controller.setHistoryMonth,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FilterDropdown<int?>(
                          label: 'Día:',
                          value: controller.historyDay,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Todos'),
                            ),
                            ...List.generate(
                              31,
                              (i) => DropdownMenuItem(
                                value: i + 1,
                                child: Text((i + 1).toString()),
                              ),
                            ),
                          ],
                          onChanged: controller.historyMonth == null
                              ? null
                              : controller.setHistoryDay,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Spacer(),
                      if (controller.historyYear != null ||
                          controller.historyMonth != null ||
                          controller.historyDay != null ||
                          controller.historyCustomerId != null)
                        TextButton.icon(
                          onPressed: controller.clearHistoryFilters,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text(
                            'Limpiar Filtros',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      const SizedBox(width: 12),
                      Text(
                        'Mostrando: ${controller.salesHistory.length} de ${controller.totalSalesCount} ventas',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // ── Lista de ventas
            Expanded(
              child: controller.salesHistory.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: Colors.black26,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No hay ventas registradas',
                            style: TextStyle(fontSize: 16, color: Colors.black45),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: controller.salesHistory.length,
                      itemBuilder: (context, index) {
                        final sale = controller.salesHistory[index];
                        final saleId = (sale['id'] as num).toInt();
                        final date = DateTime.tryParse(
                          sale['date']?.toString() ?? '',
                        );
                        final total =
                            (sale['total'] as num?)?.toDouble() ?? 0.0;
                        final clientName =
                            sale['client_name']?.toString() ??
                            'Consumidor final';
                        final storeName = sale['store_name']?.toString() ?? '';
                        final paymentName =
                            sale['payment_method_name']?.toString();
                        final nvLabel =
                            'NV\n#${saleId.toString().padLeft(3, '0')}';

                        return PosSaleHistoryCard(
                          saleId: saleId,
                          nvLabel: nvLabel,
                          clientName: clientName,
                          storeName: storeName,
                          date: date,
                          total: total,
                          paymentName: paymentName,
                          onTap: () =>
                              _showSaleDetail(context, controller, saleId),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSaleDetail(
    BuildContext context,
    PosController controller,
    int saleId,
  ) async {
    final items = await controller.getSaleItems(saleId);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => PosSaleDetailDialog(saleId: saleId, items: items),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Widget: Dropdown de filtro con label superior
// ─────────────────────────────────────────────────────────────────

class _FilterDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: onChanged == null ? Colors.grey.shade100 : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, size: 20),
              items: items,
              onChanged: onChanged,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: onChanged == null ? Colors.grey : Colors.black87,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Widget: Card de cada venta en el historial
// ─────────────────────────────────────────────────────────────────

class PosSaleHistoryCard extends StatelessWidget {
  final int saleId;
  final String nvLabel;
  final String clientName;
  final String storeName;
  final DateTime? date;
  final double total;
  final String? paymentName;
  final VoidCallback onTap;

  const PosSaleHistoryCard({
    super.key,
    required this.saleId,
    required this.nvLabel,
    required this.clientName,
    required this.storeName,
    required this.date,
    required this.total,
    required this.paymentName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = date != null
        ? DateFormat('yyyy-MM-dd HH:mm:ss').format(date!)
        : '';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar NV
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    'NV\n#${saleId.toString()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // ── Datos principales
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nota de Venta #001-001-${saleId.toString().padLeft(9, '0')}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 14, color: Colors.black45),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Cliente: ${clientName.toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.black45),
                        const SizedBox(width: 4),
                        Text(
                          'Fecha: $dateStr',
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                    if (paymentName != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.payment_outlined, size: 14, color: Colors.black45),
                          const SizedBox(width: 4),
                          Text(
                            paymentName!,
                            style: const TextStyle(fontSize: 12, color: Colors.black45),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        'Total: \$${total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.black45),
                onPressed: onTap,
                tooltip: 'Ver detalle',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Widget: Dialog de detalle de venta
// ─────────────────────────────────────────────────────────────────

class PosSaleDetailDialog extends StatelessWidget {
  final int saleId;
  final List<Map<String, dynamic>> items;

  const PosSaleDetailDialog({
    super.key,
    required this.saleId,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    double grandTotal = 0;
    for (final item in items) {
      grandTotal +=
          ((item['quantity'] as num?)?.toInt() ?? 0) *
          ((item['price'] as num?)?.toDouble() ?? 0);
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Cabecera
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
              decoration: const BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Nota de Venta #001-001-${saleId.toString().padLeft(9, '0')}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),
            // ── Lista de productos
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No hay productos en esta venta.',
                    style: TextStyle(color: Colors.black45),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final item = items[index];
                    final qty = (item['quantity'] as num?)?.toInt() ?? 0;
                    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                    final subtotal = qty * price;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '$qty',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['product_name']?.toString() ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Precio unitario: \$${price.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '\$${subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            // ── Total
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '\$${grandTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            // ── Botón cerrar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: Colors.black54),
                  child: const Text('Cerrar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
