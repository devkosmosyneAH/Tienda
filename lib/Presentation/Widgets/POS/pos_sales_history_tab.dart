import 'package:tienda/Presentation/Controller/pos_controller.dart';
import 'package:tienda/Presentation/Widgets/Products/shared_inputs.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';

// ─────────────────────────────────────────────────────────────────
//  Tab: Historial de Ventas
// ─────────────────────────────────────────────────────────────────

class PosSalesHistoryTab extends StatefulWidget {
  const PosSalesHistoryTab({super.key});

  @override
  State<PosSalesHistoryTab> createState() => _PosSalesHistoryTabState();
}

class _PosSalesHistoryTabState extends State<PosSalesHistoryTab> {
  String _query = '';

  static const _months = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<PosController>(
      builder: (context, controller, _) {
        final currentYear = DateTime.now().year;
        final years = List.generate(currentYear - 2019, (i) => currentYear - i);

        final filteredSales = controller.salesHistory.where((sale) {
          final query = _query.trim().toLowerCase();
          if (query.isEmpty) return true;
          final client = sale['client_name']?.toString().toLowerCase() ?? '';
          final id = sale['id']?.toString() ?? '';
          return client.contains(query) || id.contains(query);
        }).toList();
        final filteredTotal = filteredSales.fold<double>(
          0,
          (sum, sale) => sum + ((sale['total'] as num?)?.toDouble() ?? 0),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Cabecera
            Container(
              color: Colors.transparent,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Row(
                children: [
                  const Text(
                    'Historial de Ventas',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${controller.totalSalesCount} ventas',
                    style: const TextStyle(color: AppColors.plumGray54),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Total: \$${filteredTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: AppColors.plumGray,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.plumGray87,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 110,
                    child: _FilterDropdown<int?>(
                      label: 'Año',
                      value: controller.historyYear,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Todos'),
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
                  SizedBox(
                    width: 110,
                    child: _FilterDropdown<int?>(
                      label: 'Mes',
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
                  SizedBox(
                    width: 100,
                    child: _FilterDropdown<int?>(
                      label: 'Día',
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
                  SizedBox(
                    width: 240,
                    child: SharedTextField(
                      onChanged: (value) => setState(() => _query = value),
                      label: 'Buscar factura/cliente',
                      prefixIcon: const Icon(Icons.search, size: 20),
                    ),
                  ),
                  if (controller.historyYear != null ||
                      controller.historyMonth != null ||
                      controller.historyDay != null ||
                      controller.historyCustomerId != null)
                    TextButton.icon(
                      onPressed: controller.clearHistoryFilters,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.dustyRose,
                      ),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Limpiar'),
                    ),
                ],
              ),
            ),
            /*
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
                            foregroundColor: AppColors.dustyRose,
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
                          color: AppColors.plumGray54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),*/
            const Divider(height: 1),
            // ── Lista de ventas
            Expanded(
              child: filteredSales.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: AppColors.plumGray26,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No hay ventas registradas',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.plumGray45,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: filteredSales.length,
                      itemBuilder: (context, index) {
                        final sale = filteredSales[index];
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
                        final paymentName = sale['payment_method_name']
                            ?.toString();
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
            color: AppColors.plumGray54,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: onChanged == null ? AppColors.mediumGray : AppColors.cream,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.mediumGray),
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
                color: onChanged == null
                    ? AppColors.mediumGray
                    : AppColors.plumGray87,
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
        side: BorderSide(color: AppColors.mediumGray),
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
                  color: AppColors.plumGray87,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    'NV\n#${saleId.toString()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.cream,
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
                        const Icon(
                          Icons.person_outline,
                          size: 14,
                          color: AppColors.plumGray45,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Cliente: ${clientName.toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.plumGray54,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: AppColors.plumGray45,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Fecha: $dateStr',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.plumGray54,
                          ),
                        ),
                      ],
                    ),
                    if (paymentName != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.payment_outlined,
                            size: 14,
                            color: AppColors.plumGray45,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            paymentName!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.plumGray45,
                            ),
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
                        color: AppColors.plumGray,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.plumGray),
                      ),
                      child: Text(
                        'Total: \$${total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.plumGray,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, color: AppColors.plumGray45),
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
                color: AppColors.plumGray87,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    color: AppColors.cream,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Nota de Venta #001-001-${saleId.toString().padLeft(9, '0')}',
                    style: const TextStyle(
                      color: AppColors.cream,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.paleMauve70),
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
                    style: TextStyle(color: AppColors.plumGray45),
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
                              color: AppColors.mediumGray,
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
                                    color: AppColors.plumGray45,
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
                color: AppColors.plumGray87,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL',
                    style: TextStyle(
                      color: AppColors.cream,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '\$${grandTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppColors.cream,
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
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.plumGray54,
                  ),
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
