import 'package:tienda/Presentation/Controller/purchases_controller.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:tienda/Presentation/Utils/supplier_ruc_validator.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../Widgets/Products/filter_dropdown.dart';

class PurchaseHistoryTab extends StatefulWidget {
  const PurchaseHistoryTab({super.key});

  @override
  State<PurchaseHistoryTab> createState() => _PurchaseHistoryTabState();
}

class _PurchaseHistoryTabState extends State<PurchaseHistoryTab> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
              TextField(
                controller: _searchController,
                onChanged: controller.updateHistorySearch,
                decoration: InputDecoration(
                  hintText: 'Factura, proveedor, RUC, producto o código',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppColors.cream,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final lastDate =
                            controller.historyToDate ?? DateTime(2100);
                        final suggestedDate =
                            controller.historyFromDate ?? DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: lastDate,
                          initialDate: suggestedDate.isAfter(lastDate)
                              ? lastDate
                              : suggestedDate,
                        );
                        if (picked != null) {
                          await controller.setHistoryDateRange(
                            from: picked,
                            to: controller.historyToDate,
                          );
                        }
                      },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        controller.historyFromDate == null
                            ? 'Desde'
                            : DateFormat(
                                'dd/MM/yyyy',
                              ).format(controller.historyFromDate!),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final firstDate =
                            controller.historyFromDate ?? DateTime(2000);
                        final suggestedDate =
                            controller.historyToDate ?? DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: firstDate,
                          lastDate: DateTime(2100),
                          initialDate: suggestedDate.isBefore(firstDate)
                              ? firstDate
                              : suggestedDate,
                        );
                        if (picked != null) {
                          await controller.setHistoryDateRange(
                            from: controller.historyFromDate,
                            to: picked,
                          );
                        }
                      },
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        controller.historyToDate == null
                            ? 'Hasta'
                            : DateFormat(
                                'dd/MM/yyyy',
                              ).format(controller.historyToDate!),
                      ),
                    ),
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
                    TextButton.icon(
                      onPressed: () {
                        _searchController.clear();
                        controller.clearHistoryFilters();
                      },
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
                    final paidQuantity =
                        (item['paid_quantity'] as num?)?.toInt() ??
                        (item['quantity'] as num?)?.toInt() ??
                        0;
                    final bonusQuantity =
                        (item['bonus_quantity'] as num?)?.toInt() ?? 0;
                    final unitCost =
                        (item['invoice_unit_cost'] as num?)?.toDouble() ?? 0;
                    final lineTotal =
                        (item['line_total'] as num?)?.toDouble() ??
                        paidQuantity * unitCost;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item['product_name']?.toString() ?? ''),
                      subtitle: Text(
                        'Pagadas: $paidQuantity × \$${unitCost.toStringAsFixed(2)}${bonusQuantity > 0 ? ' · Bonificación: $bonusQuantity' : ''} · IVA: \$${((item['vat_amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                      ),
                      trailing: Text('\$${lineTotal.toStringAsFixed(2)}'),
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
    final isCancelled = purchase['status'] == 'cancelled';
    final isCredit =
        purchase['payment_condition'] == 'credito' ||
        purchase['payment_condition'] == 'crédito';
    final payableBalance =
        (purchase['payable_balance'] as num?)?.toDouble() ?? 0;

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
            if (!isCancelled)
              if (isCredit && payableBalance > 0.01)
                _PurchaseActionTile(
                  icon: Icons.payments_outlined,
                  color: AppColors.plumGray,
                  title: 'Registrar pago',
                  subtitle:
                      'Saldo pendiente: \$${payableBalance.toStringAsFixed(2)}',
                  onTap: () => Navigator.pop(context, 'pay'),
                ),
            if (!isCancelled)
              _PurchaseActionTile(
                icon: Icons.receipt_long_outlined,
                color: AppColors.dustyRose,
                title: 'Anular con nota de crédito',
                subtitle: 'Revertir inventario, CxP y asiento',
                onTap: () => Navigator.pop(context, 'cancel'),
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
    if (action == 'cancel') {
      final creditNote = await _showCreditNoteDialog(context);
      if (creditNote == null || !context.mounted) return;
      try {
        await controller.cancelPurchase(
          purchaseId: purchaseId,
          creditNoteNumber: creditNote['number']!,
          accessKey: creditNote['key']!,
          issueDate: DateTime.now(),
          reason: creditNote['reason']!,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Factura anulada con nota de crédito.'),
            ),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.toString().replaceFirst('Exception: ', '')),
            ),
          );
        }
      }
      return;
    }
    if (action == 'pay') {
      final payment = await _showPayablePaymentDialog(context, controller);
      if (payment == null || !context.mounted) return;
      try {
        await controller.payPurchaseBalance(
          purchaseId: purchaseId,
          amount: payment['amount'] as double,
          paymentMethod: payment['method'] as String,
          reference: payment['reference'] as String?,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pago registrado correctamente.')),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.toString().replaceFirst('Exception: ', '')),
            ),
          );
        }
      }
      return;
    }

    final message = switch (action) {
      'continue' => 'La compra se puede continuar desde Nueva compra.',
      'edit' =>
        'Las facturas registradas no se editan; use una nota de crédito.',
      'paid' => 'Registre el pago desde Cuentas por pagar.',
      _ => null,
    };
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<Map<String, String>?> _showCreditNoteDialog(
    BuildContext context,
  ) async {
    final formKey = GlobalKey<FormState>();
    final numberController = TextEditingController();
    final keyController = TextEditingController();
    final reasonController = TextEditingController();
    try {
      return await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Anular factura'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: numberController,
                  decoration: const InputDecoration(
                    labelText: 'Número de nota de crédito *',
                    hintText: '001-001-000000000',
                  ),
                  validator: (value) =>
                      RegExp(
                        r'^\d{3}-\d{3}-\d{9}$',
                      ).hasMatch(value?.trim() ?? '')
                      ? null
                      : 'Formato 001-001-000000000 requerido.',
                ),
                TextFormField(
                  controller: keyController,
                  decoration: const InputDecoration(
                    labelText: 'Clave de acceso (49 dígitos) *',
                  ),
                  keyboardType: TextInputType.number,
                  validator: SupplierRucValidator.validateAccessKey,
                ),
                TextFormField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: 'Motivo *'),
                  validator: (value) => value?.trim().isNotEmpty == true
                      ? null
                      : 'Ingrese el motivo.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(dialogContext, {
                  'number': numberController.text.trim(),
                  'key': keyController.text.trim(),
                  'reason': reasonController.text.trim(),
                });
              },
              child: const Text('Anular'),
            ),
          ],
        ),
      );
    } finally {
      numberController.dispose();
      keyController.dispose();
      reasonController.dispose();
    }
  }

  Future<Map<String, Object>?> _showPayablePaymentDialog(
    BuildContext context,
    PurchasesController controller,
  ) async {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final referenceController = TextEditingController();
    var method = controller.paymentMethods.isEmpty
        ? 'Transferencia'
        : controller.paymentMethods.first['name'].toString();
    try {
      return await showDialog<Map<String, Object>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Registrar pago a proveedor'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: amountController,
                    decoration: const InputDecoration(labelText: 'Monto *'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      final amount = double.tryParse(
                        (value ?? '').replaceAll(',', '.'),
                      );
                      return amount == null || amount <= 0
                          ? 'Ingrese un monto mayor que cero.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: method,
                    decoration: const InputDecoration(
                      labelText: 'Medio de pago',
                    ),
                    items: controller.paymentMethods
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item['name'].toString(),
                            child: Text(item['name'].toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => method = value);
                    },
                  ),
                  TextFormField(
                    controller: referenceController,
                    decoration: const InputDecoration(labelText: 'Referencia'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.pop(dialogContext, {
                    'amount': double.parse(
                      amountController.text.replaceAll(',', '.'),
                    ),
                    'method': method,
                    'reference': referenceController.text.trim(),
                  });
                },
                child: const Text('Registrar pago'),
              ),
            ],
          ),
        ),
      );
    } finally {
      amountController.dispose();
      referenceController.dispose();
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
    final auxiliaryInvoice = purchase['auxiliary_invoice_number']
        ?.toString()
        .trim();
    final payment = purchase['payment_method']?.toString().trim();

    return Card(
      color: AppColors.whiteOverlay,
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shadowColor: AppColors.plumGray26,
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
                      color: AppColors.dustyRose,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      color: AppColors.cream,
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
                              'Factura: ${auxiliaryInvoice?.isNotEmpty == true ? '$auxiliaryInvoice · ' : ''}${invoice?.isNotEmpty == true ? invoice : purchaseId}',
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
                              'Condición: ${purchase['payment_condition'] ?? 'contado'} · Medio: ${payment?.isNotEmpty == true ? payment : 'Efectivo'}',
                        ),
                        if (purchase['due_date']?.toString().isNotEmpty == true)
                          _PurchaseMetaRow(
                            icon: Icons.event_outlined,
                            label:
                                'Vence: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(purchase['due_date'].toString()))}',
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
                          color: AppColors.mutedMauve,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _PurchaseStatusBadge(
                        status: purchase['status']?.toString(),
                        balance:
                            (purchase['payable_balance'] as num?)?.toDouble() ??
                            0,
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: onActions,
                    icon: const Icon(Icons.visibility_outlined, size: 17),
                    label: const Text('Ver'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.paleMauve,
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
      leading: Icon(icon, color: color ?? AppColors.plumGray87, size: 24),
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
          selectedColor: AppColors.plumGray,
          backgroundColor: Colors.transparent,
          side: BorderSide(
            color: isSelected ? AppColors.plumGray : AppColors.plumGray26,
          ),
          labelStyle: TextStyle(
            color: isSelected ? AppColors.cream : AppColors.plumGray87,
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
        color: AppColors.cream.withValues(alpha: .55),
        border: Border.all(color: AppColors.plumGray12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _PurchaseStat(
            icon: Icons.shopping_cart_outlined,
            color: AppColors.mutedMauve,
            label: 'Total',
            value: '${controller.historyTotalCount}',
          ),
          _PurchaseStat(
            icon: Icons.check_circle,
            color: AppColors.plumGray,
            label: 'Pagadas',
            value: '${controller.historyPaidCount}',
          ),
          _PurchaseStat(
            icon: Icons.more_horiz,
            color: AppColors.paleMauve,
            label: 'Pendientes',
            value: '${controller.historyPendingCount}',
          ),
          _PurchaseStat(
            icon: Icons.attach_money,
            color: AppColors.plumGray,
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
              color: AppColors.plumGray54,
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
  final String? status;
  final double balance;

  const _PurchaseStatusBadge({required this.status, required this.balance});

  @override
  Widget build(BuildContext context) {
    final isCancelled = status == 'cancelled';
    final isPending = !isCancelled && balance > 0.01;
    final label = isCancelled
        ? 'Anulada'
        : (isPending ? 'Pendiente' : 'Pagada');
    final color = isCancelled
        ? AppColors.dustyRose
        : (isPending ? AppColors.paleMauve : AppColors.plumGray);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
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
        Icon(icon, size: 15, color: AppColors.plumGray54),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColors.plumGray54),
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
                foregroundColor: AppColors.cream,
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
