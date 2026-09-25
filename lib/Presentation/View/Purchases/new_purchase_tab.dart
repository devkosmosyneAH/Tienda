import 'package:tienda/Presentation/Controller/purchases_controller.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../Widgets/Products/filter_dropdown.dart';
import '../../Widgets/Products/shared_inputs.dart';

class NewPurchaseTab extends StatelessWidget {
  const NewPurchaseTab({
    required this.searchController,
    required this.supplierController,
    required this.supplierPhoneController,
    required this.onSave,
    super.key,
  });

  final TextEditingController searchController;
  final TextEditingController supplierController;
  final TextEditingController supplierPhoneController;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Consumer<PurchasesController>(
      builder: (context, controller, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final detailsPanel = _PurchaseDetailsPanel(
              controller: controller,
              supplierController: supplierController,
              supplierPhoneController: supplierPhoneController,
            );
            final summaryPanel = _SummaryPanel(
              controller: controller,
              onSave: onSave,
              onAddProduct: () => _showProductSearchDialog(
                context,
                controller,
                searchController,
              ),
            );

            if (isWide) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: Column(children: [detailsPanel])),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: SizedBox(height: 720, child: summaryPanel),
                    ),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                detailsPanel,
                const SizedBox(height: 14),
                SizedBox(height: 560, child: summaryPanel),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showProductSearchDialog(
    BuildContext context,
    PurchasesController controller,
    TextEditingController searchController,
  ) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.lightGray,
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 680),
          child: Stack(
            children: [
              _CatalogPanel(
                controller: controller,
                searchController: searchController,
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurchaseCard extends StatelessWidget {
  const _PurchaseCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.icon});

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 22, color: Colors.black87),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _PurchaseDetailsPanel extends StatefulWidget {
  const _PurchaseDetailsPanel({
    required this.controller,
    required this.supplierController,
    required this.supplierPhoneController,
  });

  final PurchasesController controller;
  final TextEditingController supplierController;
  final TextEditingController supplierPhoneController;

  @override
  State<_PurchaseDetailsPanel> createState() => _PurchaseDetailsPanelState();
}

class _PurchaseDetailsPanelState extends State<_PurchaseDetailsPanel> {
  late final TextEditingController _governmentVatController;
  late final TextEditingController _profitVatController;
  bool _considerVatProfit = false;

  @override
  void initState() {
    super.initState();
    _governmentVatController = TextEditingController(text: '15.0');
    _profitVatController = TextEditingController(text: '15.0');
  }

  @override
  void dispose() {
    _governmentVatController.dispose();
    _profitVatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PurchaseCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Proveedor',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              SharedTextField(
                controller: widget.supplierController,
                hint: 'Seleccionar proveedor',
                prefixIcon: const Icon(Icons.business),
                style: const TextStyle(fontSize: 15, color: Colors.black87),
                useFilterStyle: true,
              ),
              const SizedBox(height: 8),
              SharedTextField(
                controller: widget.supplierPhoneController,
                hint: 'Teléfono del proveedor',
                prefixIcon: const Icon(Icons.phone_outlined),
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 15, color: Colors.black87),
                useFilterStyle: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _PurchaseCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                title: 'Información de Factura',
                icon: Icons.receipt_long_outlined,
              ),
              const SizedBox(height: 12),
              _ReadOnlyField(
                label: 'Número de Factura (Generado automáticamente)',
                value: widget.controller.invoiceNumber.isEmpty
                    ? 'Generando...'
                    : widget.controller.invoiceNumber,
                icon: Icons.receipt_long_outlined,
              ),
              const SizedBox(height: 10),
              SharedTextField(
                onChanged: widget.controller.updateAuxiliaryInvoiceNumber,
                label: 'Número de Factura Auxiliar (Manual)',
                hint: 'Número auxiliar',
                prefixIcon: Icon(Icons.tag),
                useFilterStyle: true,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(
                    child: _ReadOnlyField(
                      label: 'Fecha',
                      value: 'Hoy',
                      icon: Icons.calendar_today_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilterDropdown<int>(
                      label: 'Forma de Pago',
                      value: widget.controller.selectedPaymentMethodId,
                      items: widget.controller.paymentMethods
                          .map(
                            (method) => DropdownMenuItem<int>(
                              value: (method['id'] as num).toInt(),
                              child: Text(
                                method['name'].toString().toLowerCase() ==
                                        'efectivo'
                                    ? 'Contado'
                                    : method['name'].toString(),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: widget.controller.selectPaymentMethod,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              _PurchaseCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(title: 'Configuración'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(child: Text('IVA Gubernamental:')),
                        SizedBox(
                          width: 92,
                          child: SharedTextField(
                            controller: _governmentVatController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            suffix: '%',
                            hint: '15.0',
                            useFilterStyle: true,
                            onChanged: (value) {
                              final rate = double.tryParse(
                                value.replaceAll(',', '.'),
                              );
                              if (rate != null) {
                                widget.controller.updateGovernmentVatRate(rate);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Considerar ganancia IVA'),
                      subtitle: const Text(
                        'Aplicar la ganancia de IVA a cada producto',
                      ),
                      trailing: Switch(
                        value: _considerVatProfit,
                        onChanged: (value) {
                          setState(() => _considerVatProfit = value);
                          widget.controller.setConsiderVatProfit(value);
                        },
                        activeColor: Colors.white,
                        activeTrackColor: Color(0xFF6B4EAA),
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: Colors.black26,
                      ),
                    ),
                    if (_considerVatProfit) ...[
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 138,
                        child: SharedTextField(
                          controller: _profitVatController,
                          label: 'Porcentaje de IVA',
                          hint: '15.0',
                          suffix: '%',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          useFilterStyle: true,
                          onChanged: (value) {
                            final rate = double.tryParse(
                              value.replaceAll(',', '.'),
                            );
                            if (rate != null) {
                              widget.controller.updateProfitVatRate(rate);
                            }
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.lightBlue.withValues(alpha: 0.45),
                        border: Border.all(color: Colors.lightBlue),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'El IVA gubernamental se aplica a esta compra. La ganancia IVA se utiliza únicamente cuando el producto sea revendido.',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReadOnlyField extends StatefulWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  State<_ReadOnlyField> createState() => _ReadOnlyFieldState();
}

class _ReadOnlyFieldState extends State<_ReadOnlyField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _ReadOnlyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SharedTextField(
      controller: _controller,
      enabled: false,
      label: widget.label,
      prefixIcon: Icon(widget.icon, size: 20),
      useFilterStyle: false,
    );
  }
}

class _CatalogPanel extends StatelessWidget {
  const _CatalogPanel({
    required this.controller,
    required this.searchController,
  });

  final PurchasesController controller;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    return Consumer<PurchasesController>(
      builder: (context, controller, _) => _PurchaseCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(title: 'Buscar Producto', icon: Icons.search),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilterDropdown<int?>(
                    label: 'Local destino',
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
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SharedTextField(
                    controller: searchController,
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                    hint: 'Código o descripción del producto',
                    prefixIcon: const Icon(Icons.search),
                    useFilterStyle: true,
                    onChanged: controller.updateSearch,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'PRODUCTO Y SKU',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    'P. COMPRA',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 52),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: controller.isLoading && controller.products.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : controller.products.isEmpty
                  ? const Center(child: Text('No hay productos para comprar.'))
                  : ListView.separated(
                      itemCount: controller.products.length,
                      separatorBuilder: (_, __) => Padding(
                        padding: const EdgeInsets.all(2),
                        child: Divider(height: 0.1, color: AppColors.lightGray),
                      ),
                      itemBuilder: (context, index) {
                        final product = controller.products[index];
                        final purchasePrice =
                            (product['cost_price'] as num?)?.toDouble() ?? 0;
                        return Material(
                              color: AppColors.whiteOverlay,
                              borderRadius: BorderRadius.circular(10),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => controller.addToCart(product),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: AppColors.threeColor,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.inventory_2_outlined,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product['name']?.toString() ?? '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              'SKU: ${product['sku'] ?? 'Sin código'}',
                                              style: const TextStyle(
                                                color: Colors.black54,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '\$${purchasePrice.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      IconButton(
                                        tooltip: 'Agregar producto',
                                        onPressed: () =>
                                            controller.addToCart(product),
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .animate()
                            .fadeIn(
                              delay: Duration(milliseconds: 30 * (index % 20)),
                              duration: 280.ms,
                            )
                            .slideX(
                              begin: 0.04,
                              end: 0,
                              delay: Duration(milliseconds: 30 * (index % 20)),
                              duration: 280.ms,
                              curve: Curves.easeOut,
                            );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.controller,
    required this.onSave,
    required this.onAddProduct,
  });

  final PurchasesController controller;
  final VoidCallback onSave;
  final VoidCallback onAddProduct;

  @override
  Widget build(BuildContext context) {
    return _PurchaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Productos Agregados',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Agregar producto',
                  onPressed: onAddProduct,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: Colors.white,
                  icon: const Icon(Icons.add_circle_outline, size: 25),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: controller.cart.isEmpty
                ? Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 52,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No se han agregado productos',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Agrega productos usando el buscador superior',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: controller.cart.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = controller.cart[index];
                      return _PurchaseCartRow(
                        key: ValueKey(item['product_id']),
                        item: item,
                        controller: controller,
                      );
                    },
                  ),
          ),
          _PurchaseTotals(controller: controller, onSave: onSave),
        ],
      ),
    );
  }
}

class _PurchaseTotals extends StatefulWidget {
  const _PurchaseTotals({required this.controller, required this.onSave});

  final PurchasesController controller;
  final VoidCallback onSave;

  @override
  State<_PurchaseTotals> createState() => _PurchaseTotalsState();
}

class _PurchaseTotalsState extends State<_PurchaseTotals> {
  late final TextEditingController _discountController;

  @override
  void initState() {
    super.initState();
    _discountController = TextEditingController(
      text: widget.controller.discount == 0
          ? ''
          : widget.controller.discount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final hasVat = controller.governmentVatRate > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        const Text(
          'Totales',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        _TotalLine(
          label: 'Subtotal:',
          value: '\$${controller.subtotal.toStringAsFixed(2)}',
        ),
        const SizedBox(height: 8),
        _TotalLine(
          label: hasVat
              ? 'IVA gubernamental (${controller.governmentVatRate.toStringAsFixed(1)}%):'
              : 'IVA gubernamental:',
          value: hasVat
              ? '\$${controller.vatTotal.toStringAsFixed(2)}'
              : 'No aplicado',
          color: hasVat ? Colors.orange : Colors.black45,
          italic: !hasVat,
        ),
        if (hasVat) ...[
          const SizedBox(height: 4),
          Text(
            'Productos con IVA: ${controller.productsWithVat}/${controller.cart.length}',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Descuento:', style: TextStyle(fontSize: 16)),
            SizedBox(
              width: 100,
              child: SharedTextField(
                controller: _discountController,
                prefix: '\$',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                useFilterStyle: true,
                onChanged: (value) {
                  final discount = double.tryParse(value.replaceAll(',', '.'));
                  if (discount != null) controller.updateDiscount(discount);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(thickness: 1.2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'TOTAL:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            Text(
              '\$${controller.total.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: controller.cart.isEmpty ? null : widget.onSave,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar compra'),
          ),
        ),
      ],
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({
    required this.label,
    required this.value,
    this.color = Colors.black87,
    this.italic = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool italic;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: color,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}

class _PurchaseCartRow extends StatefulWidget {
  const _PurchaseCartRow({
    super.key,
    required this.item,
    required this.controller,
  });

  final Map<String, dynamic> item;
  final PurchasesController controller;

  @override
  State<_PurchaseCartRow> createState() => _PurchaseCartRowState();
}

class _PurchaseCartRowState extends State<_PurchaseCartRow> {
  late final TextEditingController _costController;

  @override
  void initState() {
    super.initState();
    _costController = TextEditingController(
      text: (widget.item['cost'] as double).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productId = widget.item['product_id'] as int;
    final quantity = widget.item['quantity'] as int;
    final cost = (widget.item['cost'] as double);
    final subtotal = cost * quantity;
    final vat = subtotal * widget.controller.appliedVatRate / 100;
    final total = subtotal + vat;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final product = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item['name']?.toString() ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Código: ${widget.item['product_id']}',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        );

        final quantityControl = _QuantityControl(
          quantity: quantity,
          onDecrease: () => widget.controller.decrementQuantity(productId),
          onIncrease: () => widget.controller.incrementQuantity(productId),
        );

        final costField = SizedBox(
          width: compact ? 104 : 128,
          child: SharedTextField(
            controller: _costController,
            prefix: '\$',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            useFilterStyle: true,
            onChanged: (value) {
              final parsed = double.tryParse(value.replaceAll(',', '.'));
              if (parsed != null) {
                widget.controller.updateCost(productId, parsed);
              }
            },
          ),
        );

        final values = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ValueBadge(label: 'IVA', value: '\$${vat.toStringAsFixed(2)}'),
            const SizedBox(width: 8),
            _ValueBadge(
              label: 'Total',
              value: '\$${total.toStringAsFixed(2)}',
              color: const Color(0xFFE7FFD8),
              textColor: const Color(0xFF267A16),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Quitar producto',
              onPressed: () => widget.controller.removeFromCart(productId),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
          ],
        );

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    product,
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [quantityControl, costField, values],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(flex: 5, child: product),
                    const SizedBox(width: 12),
                    quantityControl,
                    const SizedBox(width: 18),
                    costField,
                    const SizedBox(width: 18),
                    values,
                  ],
                ),
        );
      },
    );
  }
}

class _QuantityControl extends StatelessWidget {
  const _QuantityControl({
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onDecrease,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('$quantity', style: const TextStyle(fontWeight: FontWeight.w700)),
        IconButton(
          onPressed: onIncrease,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

class _ValueBadge extends StatelessWidget {
  const _ValueBadge({
    required this.label,
    required this.value,
    this.color = const Color(0xFFFFF2BF),
    this.textColor = const Color(0xFFB88600),
  });

  final String label;
  final String value;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        value,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
      ),
    );
  }
}
