import 'package:tienda/Presentation/Controller/purchases_controller.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../Widgets/Products/filter_dropdown.dart';

class PurchaseHistoryTab extends StatelessWidget {
  const PurchaseHistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PurchasesController>(
      builder: (context, controller, _) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _HistoryPeriodSelector(
                selected: controller.historyPeriod,
                onSelected: controller.selectHistoryPeriod,
              ),
              const SizedBox(height: 14),
              _PurchaseHistoryStats(controller: controller),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 220,
                      child: FilterDropdown<int?>(
                        label: 'Local',
                        value: controller.selectedStoreId,
                        items: controller.stores
                            .map(
                              (store) => DropdownMenuItem<int?>(
                                value: (store['id'] as num).toInt(),
                                child: Text(store['name'].toString()),
                              ),
                            )
                            .toList(),
                        onChanged: controller.selectStore,
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: FilterDropdown<String?>(
                        label: 'Categoría',
                        value: controller.historyCategory,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Categoría'),
                          ),
                          ...controller.categories.map(
                            (category) => DropdownMenuItem<String?>(
                              value: category['name'].toString(),
                              child: Text(category['name'].toString()),
                            ),
                          ),
                        ],
                        onChanged: controller.selectHistoryCategory,
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: FilterDropdown<int?>(
                        label: 'Proveedor',
                        value: controller.historySupplierId,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Todos'),
                          ),
                          ...controller.suppliers.map(
                            (supplier) => DropdownMenuItem<int?>(
                              value: (supplier['id'] as num).toInt(),
                              child: Text(supplier['name'].toString()),
                            ),
                          ),
                        ],
                        onChanged: controller.selectHistorySupplier,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2100),
                          initialDate: controller.historyDate ?? DateTime.now(),
                        );
                        if (picked != null) {
                          await controller.setHistoryDate(picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(
                        controller.historyDate == null
                            ? 'Filtrar por fecha'
                            : DateFormat(
                                'dd/MM/yyyy',
                              ).format(controller.historyDate!),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: controller.clearHistoryFilters,
                      icon: const Icon(Icons.filter_alt_off_outlined),
                      label: const Text('Limpiar filtros'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: controller.isHistoryLoading
                    ? const Center(child: CircularProgressIndicator())
                    : controller.purchaseHistory.isEmpty
                    ? const _PurchaseHistoryEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                        itemCount: controller.purchaseHistory.length,
                        itemBuilder: (context, index) {
                          final purchase = controller.purchaseHistory[index];
                          return _PurchaseHistoryCard(
                            purchase: purchase,
                            onActions: () => _showPurchaseActions(
                              context,
                              controller,
                              (purchase['id'] as num).toInt(),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showPurchaseDetail(
    BuildContext context,
    PurchasesController controller,
    int purchaseId,
  ) async {
    final items = await controller.getPurchaseItems(purchaseId);
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detalle de compra #$purchaseId'),
        content: SizedBox(
          width: 420,
          child: items.isEmpty
              ? const Text('No hay productos en esta compra.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final subtotal =
                        ((item['quantity'] as num?)?.toInt() ?? 0) *
                        ((item['cost'] as num?)?.toDouble() ?? 0);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item['product_name']?.toString() ?? ''),
                      subtitle: Text(
                        'Cant: ${item['quantity']} · Costo: \$${((item['cost'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                      ),
                      trailing: Text('\$${subtotal.toStringAsFixed(2)}'),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPurchaseActions(
    BuildContext context,
    PurchasesController controller,
    int purchaseId,
  ) async {
    final purchase = controller.purchaseHistory.firstWhere(
      (item) => (item['id'] as num).toInt() == purchaseId,
    );
    final invoice = purchase['invoice_number']?.toString().trim();
    final supplier = purchase['supplier_name']?.toString() ?? 'Sin proveedor';

    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Compra ${invoice?.isNotEmpty == true ? invoice : '#$purchaseId'}',
                  ),
                  Text(
                    supplier.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PurchaseActionTile(
              icon: Icons.visibility_outlined,
              title: 'Ver detalles',
              subtitle: 'Consultar información completa',
              onTap: () => Navigator.pop(context, 'details'),
            ),
            _PurchaseActionTile(
              icon: Icons.add_shopping_cart_outlined,
              color: Colors.green,
              title: 'Continuar compra',
              subtitle: 'Crear nueva compra basada en esta',
              onTap: () => Navigator.pop(context, 'continue'),
            ),
            _PurchaseActionTile(
              icon: Icons.edit_outlined,
              color: Colors.orange,
              title: 'Editar compra',
              subtitle: 'Modificar compra pendiente',
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            _PurchaseActionTile(
              icon: Icons.credit_card_outlined,
              color: Colors.blue,
              title: 'Marcar como pagado',
              subtitle: 'Actualizar estado de pago',
              onTap: () => Navigator.pop(context, 'paid'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted || action == null) return;
    if (action == 'details') {
      await _showPurchaseDetail(context, controller, purchaseId);
      return;
    }

    final message = switch (action) {
      'continue' => 'La compra se puede continuar desde Nueva compra.',
      'edit' => 'La edición de compras estará disponible próximamente.',
      'paid' => 'El estado de pago se actualizará próximamente.',
      _ => null,
    };
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _PurchaseHistoryCard extends StatelessWidget {
  final Map<String, dynamic> purchase;
  final VoidCallback onActions;

  const _PurchaseHistoryCard({required this.purchase, required this.onActions});

  @override
  Widget build(BuildContext context) {
    final purchaseId = (purchase['id'] as num).toInt();
    final date = DateTime.tryParse(purchase['date']?.toString() ?? '');
    final total = (purchase['total'] as num?)?.toDouble() ?? 0;
    final invoice = purchase['invoice_number']?.toString().trim();
    final payment = purchase['payment_method']?.toString().trim();

    return Card(
      color: AppColors.whiteOverlay,
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onActions,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 10, 8),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xffffa000),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          purchase['supplier_name']?.toString().toUpperCase() ??
                              'SIN PROVEEDOR',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _PurchaseMetaRow(
                          icon: Icons.receipt_outlined,
                          label:
                              'Factura: ${invoice?.isNotEmpty == true ? invoice : purchaseId}',
                        ),
                        const SizedBox(height: 3),
                        _PurchaseMetaRow(
                          icon: Icons.calendar_today_outlined,
                          label:
                              'Fecha: ${date == null ? '' : DateFormat('dd/MM/yyyy').format(date)}',
                        ),
                        const SizedBox(height: 3),
                        _PurchaseMetaRow(
                          icon: Icons.payment_outlined,
                          label:
                              'Pago: ${payment?.isNotEmpty == true ? payment : 'Contado'}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xff2e7d32),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _PurchaseStatusBadge(payment: payment),
                    ],
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: onActions,
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: const Text('Editar'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange.shade800,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onActions,
                    tooltip: 'Más acciones',
                    icon: const Icon(Icons.keyboard_arrow_down),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurchaseActionTile extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PurchaseActionTile({
    required this.icon,
    this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color ?? Colors.black87, size: 24),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}

class _HistoryPeriodSelector extends StatelessWidget {
  final PurchaseHistoryPeriod selected;
  final ValueChanged<PurchaseHistoryPeriod> onSelected;

  const _HistoryPeriodSelector({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final periods = [
      (PurchaseHistoryPeriod.all, 'Todo'),
      (PurchaseHistoryPeriod.today, 'Hoy'),
      (PurchaseHistoryPeriod.week, 'Esta semana'),
      (PurchaseHistoryPeriod.month, 'Este mes'),
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: periods.map((period) {
        final isSelected = period.$1 == selected;
        return ChoiceChip(
          label: Text(period.$2),
          selected: isSelected,
          onSelected: (_) => onSelected(period.$1),
          selectedColor: Colors.black,
          backgroundColor: Colors.transparent,
          side: BorderSide(color: isSelected ? Colors.black : Colors.black26),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          showCheckmark: false,
        );
      }).toList(),
    );
  }
}

class _PurchaseHistoryStats extends StatelessWidget {
  final PurchasesController controller;

  const _PurchaseHistoryStats({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .55),
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _PurchaseStat(
            icon: Icons.shopping_cart_outlined,
            color: Colors.blue,
            label: 'Total',
            value: '${controller.historyTotalCount}',
          ),
          _PurchaseStat(
            icon: Icons.check_circle,
            color: Colors.green,
            label: 'Pagadas',
            value: '${controller.historyPaidCount}',
          ),
          _PurchaseStat(
            icon: Icons.more_horiz,
            color: Colors.orange,
            label: 'Pendientes',
            value: '${controller.historyPendingCount}',
          ),
          _PurchaseStat(
            icon: Icons.attach_money,
            color: Colors.purple,
            label: 'Monto Total',
            value: '\$${controller.historyTotalAmount.toStringAsFixed(2)}',
          ),
        ],
      ),
    );
  }
}

class _PurchaseStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _PurchaseStat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 23),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _PurchaseStatusBadge extends StatelessWidget {
  final String? payment;

  const _PurchaseStatusBadge({required this.payment});

  @override
  Widget build(BuildContext context) {
    final isPending =
        payment?.toLowerCase().contains('crédito') == true ||
        payment?.toLowerCase().contains('credito') == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPending ? Colors.orange.shade50 : Colors.green.shade50,
        border: Border.all(
          color: isPending ? Colors.orange.shade700 : Colors.green.shade700,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isPending ? 'Pendiente' : 'Pagada',
        style: TextStyle(
          color: isPending ? Colors.orange.shade800 : Colors.green.shade800,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PurchaseMetaRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PurchaseMetaRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.black54),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ),
      ],
    );
  }
}

class _PurchaseHistoryEmptyState extends StatelessWidget {
  const _PurchaseHistoryEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: AppColors.blackOverlay.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: AppColors.blackOverlay,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Tu historial está vacío',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: AppColors.blackOverlay,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Registra una compra para ver aquí todos tus movimientos de abastecimiento.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.mediumGray,
              ),
            ),
            const SizedBox(height: 26),
            FilledButton.icon(
              onPressed: () => DefaultTabController.of(context).animateTo(0),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.blackOverlay,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_shopping_cart_outlined, size: 19),
              label: const Text(
                'Nueva compra',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
