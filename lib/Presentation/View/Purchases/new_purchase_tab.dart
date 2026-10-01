import 'package:tienda/Presentation/Controller/purchases_controller.dart';
import 'package:tienda/Presentation/Model/purchase_calculation.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:tienda/Presentation/Utils/supplier_ruc_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../Widgets/Products/filter_dropdown.dart';
import '../../Widgets/Products/shared_inputs.dart';

class NewPurchaseTab extends StatelessWidget {
  const NewPurchaseTab({
    required this.searchController,
    required this.onSave,
    super.key,
  });

  final TextEditingController searchController;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Consumer<PurchasesController>(
      builder: (context, controller, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final detailsPanel = _PurchaseDetailsPanel(controller: controller);
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
          Icon(icon, size: 22, color: AppColors.plumGray87),
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
  const _PurchaseDetailsPanel({required this.controller});

  final PurchasesController controller;

  @override
  State<_PurchaseDetailsPanel> createState() => _PurchaseDetailsPanelState();
}

class _PurchaseDetailsPanelState extends State<_PurchaseDetailsPanel> {
  late final TextEditingController _governmentVatController;
  late final TextEditingController _profitVatController;
  late final TextEditingController _invoiceNumberController;
  late final TextEditingController _accessKeyController;
  late final TextEditingController _auxiliaryInvoiceController;
  late final TextEditingController _taxSupportController;
  late final TextEditingController _withholdingAuthorizationController;
  bool _considerVatProfit = false;

  @override
  void initState() {
    super.initState();
    _governmentVatController = TextEditingController(text: '15.0');
    _profitVatController = TextEditingController(text: '15.0');
    _invoiceNumberController = TextEditingController(
      text: widget.controller.invoiceNumber,
    );
    _accessKeyController = TextEditingController(
      text: widget.controller.accessKey,
    );
    _auxiliaryInvoiceController = TextEditingController(
      text: widget.controller.auxiliaryInvoiceNumber,
    );
    _taxSupportController = TextEditingController(
      text: widget.controller.taxSupportCode,
    );
    _withholdingAuthorizationController = TextEditingController(
      text: widget.controller.withholdingAuthorization,
    );
  }

  @override
  void didUpdateWidget(covariant _PurchaseDetailsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController(_invoiceNumberController, widget.controller.invoiceNumber);
    _syncController(_accessKeyController, widget.controller.accessKey);
    _syncController(
      _auxiliaryInvoiceController,
      widget.controller.auxiliaryInvoiceNumber,
    );
    _syncController(_taxSupportController, widget.controller.taxSupportCode);
    _syncController(
      _withholdingAuthorizationController,
      widget.controller.withholdingAuthorization,
    );
  }

  void _syncController(TextEditingController field, String value) {
    if (field.text == value) return;
    field.value = field.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }

  @override
  void dispose() {
    _governmentVatController.dispose();
    _profitVatController.dispose();
    _invoiceNumberController.dispose();
    _accessKeyController.dispose();
    _auxiliaryInvoiceController.dispose();
    _taxSupportController.dispose();
    _withholdingAuthorizationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedSupplier = widget.controller.suppliers.where(
      (supplier) =>
          (supplier['id'] as num).toInt() ==
          widget.controller.selectedSupplierId,
    );
    final supplier = selectedSupplier.isEmpty ? null : selectedSupplier.first;

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
              Row(
                children: [
                  Expanded(
                    child: FilterDropdown<int?>(
                      label: 'Seleccionar proveedor',
                      value: widget.controller.selectedSupplierId,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Sin proveedor'),
                        ),
                        ...widget.controller.suppliers.map(
                          (supplier) => DropdownMenuItem<int?>(
                            value: (supplier['id'] as num).toInt(),
                            child: Text(
                              supplier['name'].toString(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: widget.controller.selectSupplier,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Nuevo proveedor',
                    onPressed: () => _showNewSupplierDialog(context),
                    icon: const Icon(Icons.add_business_outlined),
                  ),
                ],
              ),
              if (supplier != null) ...[
                const SizedBox(height: 7),
                Text(
                  supplier['legal_name']?.toString().isNotEmpty == true
                      ? supplier['legal_name'].toString()
                      : supplier['name'].toString(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${supplier['identification_type']?.toString().toUpperCase() ?? 'RUC'} ${supplier['identification_number'] ?? supplier['ruc'] ?? ''}',
                  style: TextStyle(color: AppColors.plumGray54, fontSize: 12),
                ),
                if (supplier['address']?.toString().isNotEmpty == true)
                  Text(
                    supplier['address'].toString(),
                    style: TextStyle(color: AppColors.plumGray54, fontSize: 12),
                  ),
                Text(
                  [
                    if (supplier['phone']?.toString().isNotEmpty == true)
                      'Tel. ${supplier['phone']}',
                    if (supplier['email']?.toString().isNotEmpty == true)
                      supplier['email'].toString(),
                    'Pago ${supplier['payment_condition'] ?? 'contado'}',
                  ].join(' · '),
                  style: TextStyle(color: AppColors.plumGray54, fontSize: 12),
                ),
              ],
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
              SharedTextField(
                controller: _invoiceNumberController,
                onChanged: widget.controller.setInvoiceNumber,
                label: 'Número de factura *',
                hint: '001-001-000000000',
                prefixIcon: const Icon(Icons.receipt_long_outlined),
                useFilterStyle: true,
              ),
              const SizedBox(height: 10),
              SharedTextField(
                controller: _accessKeyController,
                onChanged: widget.controller.setAccessKey,
                label: 'Clave de acceso / autorización *',
                hint: '49 dígitos',
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.key_outlined),
                useFilterStyle: true,
              ),
              const SizedBox(height: 10),
              SharedTextField(
                controller: _auxiliaryInvoiceController,
                onChanged: widget.controller.updateAuxiliaryInvoiceNumber,
                label: 'Número de Factura Auxiliar (Manual)',
                hint: 'Número auxiliar',
                prefixIcon: Icon(Icons.tag),
                useFilterStyle: true,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          initialDate: widget.controller.issueDate,
                        );
                        if (picked != null) {
                          widget.controller.setIssueDate(picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        DateFormat(
                          'dd/MM/yyyy',
                        ).format(widget.controller.issueDate),
                      ),
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
                              child: Text(method['name'].toString()),
                            ),
                          )
                          .toList(),
                      onChanged: widget.controller.selectPaymentMethod,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FilterDropdown<String>(
                label: 'Condición de pago *',
                value: widget.controller.paymentCondition,
                items: const [
                  DropdownMenuItem(value: 'contado', child: Text('Contado')),
                  DropdownMenuItem(value: 'credito', child: Text('Crédito')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    widget.controller.setPaymentCondition(value);
                  }
                },
              ),
              if (widget.controller.paymentCondition == 'credito') ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: widget.controller.issueDate,
                      lastDate: DateTime(2100),
                      initialDate:
                          widget.controller.dueDate ??
                          widget.controller.issueDate,
                    );
                    if (picked != null) widget.controller.setDueDate(picked);
                  },
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    widget.controller.dueDate == null
                        ? 'Fecha de vencimiento *'
                        : 'Vence ${DateFormat('dd/MM/yyyy').format(widget.controller.dueDate!)}',
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SharedTextField(
                controller: _taxSupportController,
                onChanged: widget.controller.setTaxSupportCode,
                label: 'Código de sustento tributario *',
                hint: 'Código ATS',
                prefixIcon: const Icon(Icons.assignment_outlined),
                useFilterStyle: true,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _withholdingAuthorizationController,
                decoration: const InputDecoration(
                  labelText: 'Autorización de retención (si aplica)',
                  prefixIcon: Icon(Icons.verified_outlined),
                ),
                onChanged: widget.controller.setWithholdingAuthorization,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _addWithholding(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar retención'),
                ),
              ),
              for (
                var index = 0;
                index < widget.controller.withholdings.length;
                index++
              )
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${widget.controller.withholdings[index]['tax_type'] == 'income' ? 'Fuente' : 'IVA'} · Código ${widget.controller.withholdings[index]['code']}',
                  ),
                  subtitle: Text(
                    'Base \$${(widget.controller.withholdings[index]['base'] as num).toStringAsFixed(2)} · ${(widget.controller.withholdings[index]['rate'] as num).toStringAsFixed(2)}%',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '\$${(widget.controller.withholdings[index]['amount'] as num).toStringAsFixed(2)}',
                      ),
                      IconButton(
                        tooltip: 'Quitar retención',
                        onPressed: () =>
                            widget.controller.removeWithholding(index),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
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
                        activeThumbColor: AppColors.cream,
                        activeTrackColor: AppColors.plumGray,
                        inactiveThumbColor: AppColors.cream,
                        inactiveTrackColor: AppColors.plumGray26,
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
                        border: Border.all(color: AppColors.mutedMauve),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: AppColors.mutedMauve),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'El IVA gubernamental se aplica a esta compra. La ganancia IVA se utiliza únicamente cuando el producto sea revendido.',
                              style: TextStyle(
                                color: AppColors.mutedMauve,
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

  Future<void> _showNewSupplierDialog(BuildContext context) async {
    await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _NewPurchaseSupplierDialog(controller: widget.controller),
    );
  }

  Future<void> _addWithholding(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final codeController = TextEditingController();
    final baseController = TextEditingController();
    final rateController = TextEditingController();
    var taxType = 'income';
    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Retención'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilterDropdown<String>(
                    label: 'Tipo de impuesto',
                    value: taxType,
                    items: const [
                      DropdownMenuItem(value: 'income', child: Text('Fuente')),
                      DropdownMenuItem(value: 'vat', child: Text('IVA')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => taxType = value ?? 'income'),
                  ),
                  TextFormField(
                    controller: codeController,
                    decoration: const InputDecoration(
                      labelText: 'Código SRI *',
                    ),
                    validator: (value) => value?.trim().isNotEmpty == true
                        ? null
                        : 'Ingrese el código.',
                  ),
                  TextFormField(
                    controller: baseController,
                    decoration: const InputDecoration(
                      labelText: 'Base imponible *',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      final base = double.tryParse(
                        (value ?? '').replaceAll(',', '.'),
                      );
                      return base == null || base < 0 ? 'Base inválida.' : null;
                    },
                  ),
                  TextFormField(
                    controller: rateController,
                    decoration: const InputDecoration(
                      labelText: 'Porcentaje *',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      final rate = double.tryParse(
                        (value ?? '').replaceAll(',', '.'),
                      );
                      return rate == null || rate < 0 || rate > 100
                          ? 'Porcentaje inválido.'
                          : null;
                    },
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
                  final base = double.parse(
                    baseController.text.replaceAll(',', '.'),
                  );
                  final rate = double.parse(
                    rateController.text.replaceAll(',', '.'),
                  );
                  Navigator.pop(dialogContext, {
                    'tax_type': taxType,
                    'code': codeController.text.trim(),
                    'base': base,
                    'rate': rate,
                    'amount': PurchaseTotals.money(base * rate / 100),
                  });
                },
                child: const Text('Agregar'),
              ),
            ],
          ),
        ),
      );
      if (result != null) widget.controller.addWithholding(result);
    } finally {
      codeController.dispose();
      baseController.dispose();
      rateController.dispose();
    }
  }
}

class _NewPurchaseSupplierDialog extends StatefulWidget {
  const _NewPurchaseSupplierDialog({required this.controller});

  final PurchasesController controller;

  @override
  State<_NewPurchaseSupplierDialog> createState() =>
      _NewPurchaseSupplierDialogState();
}

class _NewPurchaseSupplierDialogState
    extends State<_NewPurchaseSupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _legalNameController = TextEditingController();
  final _identificationController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _termDaysController = TextEditingController(text: '0');
  String _identificationType = 'ruc';
  String _paymentCondition = 'contado';
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _legalNameController.dispose();
    _identificationController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _termDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo proveedor'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SharedTextFormField(
                controller: _nameController,
                label: 'Nombre *',
                prefixIcon: const Icon(Icons.business_outlined),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Campo requerido'
                    : null,
              ),
              const SizedBox(height: 10),
              SharedTextFormField(
                controller: _legalNameController,
                label: 'Razón social',
                prefixIcon: const Icon(Icons.business_outlined),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilterDropdown<String>(
                      label: 'Identificación',
                      value: _identificationType,
                      items: const [
                        DropdownMenuItem(value: 'ruc', child: Text('RUC')),
                        DropdownMenuItem(
                          value: 'cedula',
                          child: Text('Cédula'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _identificationType = value ?? 'ruc'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: SharedTextFormField(
                      controller: _identificationController,
                      label: 'Número *',
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.badge_outlined),
                      validator: (value) =>
                          SupplierRucValidator.validateIdentification(
                            value: value,
                            type: _identificationType,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SharedTextFormField(
                controller: _addressController,
                label: 'Dirección',
                prefixIcon: const Icon(Icons.location_on_outlined),
              ),
              const SizedBox(height: 10),
              FilterDropdown<String>(
                label: 'Condición de pago',
                value: _paymentCondition,
                items: const [
                  DropdownMenuItem(value: 'contado', child: Text('Contado')),
                  DropdownMenuItem(value: 'credito', child: Text('Crédito')),
                ],
                onChanged: (value) =>
                    setState(() => _paymentCondition = value ?? 'contado'),
              ),
              if (_paymentCondition == 'credito') ...[
                const SizedBox(height: 10),
                SharedTextFormField(
                  controller: _termDaysController,
                  label: 'Plazo de pago (días)',
                  keyboardType: TextInputType.number,
                  prefixIcon: const Icon(Icons.schedule_outlined),
                ),
              ],
              const SizedBox(height: 10),
              SharedTextFormField(
                controller: _phoneController,
                label: 'Teléfono',
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
              const SizedBox(height: 10),
              SharedTextFormField(
                controller: _emailController,
                label: 'Correo',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.email_outlined),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Crear y seleccionar'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.controller.createSupplier(
        name: _nameController.text,
        legalName: _legalNameController.text,
        identificationType: _identificationType,
        identificationNumber: _identificationController.text,
        ruc: _identificationType == 'ruc'
            ? _identificationController.text
            : null,
        address: _addressController.text,
        paymentCondition: _paymentCondition,
        paymentTermDays: int.tryParse(_termDaysController.text.trim()) ?? 0,
        phone: _phoneController.text,
        email: _emailController.text,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showNewProductDialog(context),
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('Nuevo producto'),
              ),
            ),
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
                    style: TextStyle(fontSize: 15, color: AppColors.plumGray87),
                    hint: 'Código o descripción del producto',
                    prefixIcon: const Icon(Icons.search),
                    useFilterStyle: true,
                    onChanged: controller.updateSearch,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'PRODUCTO Y SKU',
                      style: TextStyle(
                        color: AppColors.plumGray54,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    'P. COMPRA',
                    style: TextStyle(
                      color: AppColors.plumGray54,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 52),
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
                                              style: TextStyle(
                                                color: AppColors.plumGray54,
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

  Future<void> _showNewProductDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _NewPurchaseProductDialog(controller: controller),
    );
  }
}

class _NewPurchaseProductDialog extends StatefulWidget {
  const _NewPurchaseProductDialog({required this.controller});

  final PurchasesController controller;

  @override
  State<_NewPurchaseProductDialog> createState() =>
      _NewPurchaseProductDialogState();
}

class _NewPurchaseProductDialogState extends State<_NewPurchaseProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _priceController = TextEditingController();
  final _vatRateController = TextEditingController(text: '15');
  String? _category;
  String _vatType = 'standard';
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _vatRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.controller.categories;
    _category ??= categories.isEmpty
        ? null
        : categories.first['name']?.toString();
    return AlertDialog(
      title: const Text('Nuevo producto'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SharedTextFormField(
                controller: _nameController,
                label: 'Nombre *',
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Campo requerido'
                    : null,
              ),
              const SizedBox(height: 10),
              SharedTextFormField(
                controller: _skuController,
                label: 'Código / SKU',
              ),
              const SizedBox(height: 10),
              FilterDropdown<String?>(
                label: 'Categoría',
                value: _category,
                items: categories
                    .map(
                      (category) => DropdownMenuItem<String?>(
                        value: category['name']?.toString(),
                        child: Text(category['name'].toString()),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _category = value),
              ),
              const SizedBox(height: 10),
              FilterDropdown<String>(
                label: 'IVA del producto',
                value: _vatType,
                items: const [
                  DropdownMenuItem(
                    value: 'standard',
                    child: Text('Tarifa vigente'),
                  ),
                  DropdownMenuItem(value: 'zero', child: Text('0 %')),
                  DropdownMenuItem(
                    value: 'notObject',
                    child: Text('No objeto'),
                  ),
                  DropdownMenuItem(value: 'exempt', child: Text('Exento')),
                ],
                onChanged: (value) =>
                    setState(() => _vatType = value ?? 'standard'),
              ),
              if (_vatType == 'standard') ...[
                const SizedBox(height: 10),
                SharedTextFormField(
                  controller: _vatRateController,
                  label: 'Tarifa vigente (%)',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SharedTextFormField(
                controller: _priceController,
                label: 'PVP *',
                prefixIcon: const Icon(Icons.sell_outlined),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  final price = double.tryParse(
                    (value ?? '').replaceAll(',', '.'),
                  );
                  return price == null || price < 0
                      ? 'Ingrese un PVP válido'
                      : null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Crear y agregar'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.controller.createProductFromPurchase(
        name: _nameController.text,
        sku: _skuController.text,
        category: _category ?? 'Sin categoría',
        vatType: _vatType,
        vatRate:
            double.tryParse(_vatRateController.text.replaceAll(',', '.')) ?? 15,
        salePrice: double.parse(_priceController.text.replaceAll(',', '.')),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
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
              color: AppColors.plumGray,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Productos Agregados',
                    style: TextStyle(
                      color: AppColors.cream,
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
                  color: AppColors.cream,
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
                      color: AppColors.mediumGray,
                      border: Border.all(color: AppColors.mediumGray),
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
                            color: AppColors.mediumGray,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No se han agregado productos',
                            style: TextStyle(
                              color: AppColors.mediumGray,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Agrega productos usando el buscador superior',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.mediumGray),
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
  late final TextEditingController _physicalTotalController;

  @override
  void initState() {
    super.initState();
    _physicalTotalController = TextEditingController(
      text: widget.controller.physicalTotal?.toStringAsFixed(2) ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _PurchaseTotals oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.controller.physicalTotal?.toStringAsFixed(2) ?? '';
    if (_physicalTotalController.text != value) {
      _physicalTotalController.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  @override
  void dispose() {
    _physicalTotalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final totals = controller.calculatedTotals;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        const Text(
          'Totales',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        for (final entry in totals.subtotalByTax.entries)
          _TotalLine(
            label: 'Subtotal ${_taxLabel(entry.key)}:',
            value: '\$${entry.value.toStringAsFixed(2)}',
          ),
        _TotalLine(
          label: 'Descuentos:',
          value: '-\$${totals.discount.toStringAsFixed(2)}',
        ),
        _TotalLine(
          label: 'IVA total:',
          value: '\$${totals.vatTotal.toStringAsFixed(2)}',
        ),
        const SizedBox(height: 8),
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
                color: AppColors.plumGray,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SharedTextField(
          controller: _physicalTotalController,
          onChanged: (value) => controller.setPhysicalTotal(
            value.trim().isEmpty
                ? null
                : double.tryParse(value.replaceAll(',', '.')),
          ),
          label: 'Total de factura física *',
          prefix: '\$',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          useFilterStyle: true,
        ),
        if (controller.physicalTotal != null &&
            totals.differsFromInvoice(controller.physicalTotal!)) ...[
          const SizedBox(height: 6),
          Text(
            'Diferencia: \$${(controller.physicalTotal! - totals.total).toStringAsFixed(2)}. Revise cantidades, descuentos e IVA.',
            style: const TextStyle(color: AppColors.dustyRose, fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: controller.cart.isEmpty ? null : widget.onSave,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.plumGray,
              foregroundColor: AppColors.cream,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Registrar factura'),
          ),
        ),
      ],
    );
  }

  String _taxLabel(String key) {
    if (key.startsWith('iva_')) return 'IVA ${key.substring(4)}%';
    return key == 'no_objeto' ? 'No objeto de IVA' : 'Exento';
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: AppColors.plumGray87,
      fontSize: 16,
      fontWeight: FontWeight.w700,
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
  late final TextEditingController _bonusController;
  late final TextEditingController _bonusVatController;
  late final TextEditingController _discountController;
  late final TextEditingController _vatRateController;

  @override
  void initState() {
    super.initState();
    _costController = TextEditingController(
      text: ((widget.item['cost'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
    );
    _bonusController = TextEditingController(
      text: ((widget.item['bonus_quantity'] as num?)?.toInt() ?? 0).toString(),
    );
    _bonusVatController = TextEditingController(
      text: ((widget.item['bonus_vat_amount'] as num?)?.toDouble() ?? 0)
          .toStringAsFixed(2),
    );
    _discountController = TextEditingController(
      text: ((widget.item['discount'] as num?)?.toDouble() ?? 0)
          .toStringAsFixed(2),
    );
    _vatRateController = TextEditingController(
      text: ((widget.item['vat_rate'] as num?)?.toDouble() ?? 15)
          .toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _costController.dispose();
    _bonusController.dispose();
    _bonusVatController.dispose();
    _discountController.dispose();
    _vatRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productId = widget.item['product_id'] as int;
    final quantity = (widget.item['quantity'] as num).toInt();
    final bonusQuantity = (widget.item['bonus_quantity'] as num?)?.toInt() ?? 0;
    final vatType = widget.item['vat_type']?.toString() ?? 'standard';
    final line = widget.controller.calculatedTotals.lines.firstWhere(
      (entry) => entry.productId == productId,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.item['name']?.toString() ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Quitar producto',
                onPressed: () => widget.controller.removeFromCart(productId),
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.dustyRose,
                ),
              ),
            ],
          ),
          Text(
            'Código: ${widget.item['product_id']}',
            style: const TextStyle(fontSize: 11, color: AppColors.plumGray54),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _QuantityControl(
                quantity: quantity,
                onDecrease: () =>
                    widget.controller.decrementQuantity(productId),
                onIncrease: () =>
                    widget.controller.incrementQuantity(productId),
              ),
              SizedBox(
                width: 94,
                child: SharedTextField(
                  controller: _bonusController,
                  label: 'Bonificación',
                  keyboardType: TextInputType.number,
                  useFilterStyle: true,
                  onChanged: (value) => widget.controller.updateBonusQuantity(
                    productId,
                    int.tryParse(value) ?? 0,
                  ),
                ),
              ),
              if (bonusQuantity > 0)
                SizedBox(
                  width: 118,
                  child: SharedTextField(
                    controller: _bonusVatController,
                    label: 'IVA bonificación',
                    prefix: '\$',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    useFilterStyle: true,
                    onChanged: (value) {
                      final parsed = double.tryParse(
                        value.replaceAll(',', '.'),
                      );
                      if (parsed != null) {
                        widget.controller.updateBonusVatAmount(
                          productId,
                          parsed,
                        );
                      }
                    },
                  ),
                ),
              SizedBox(
                width: 112,
                child: SharedTextField(
                  controller: _costController,
                  label: 'Costo unitario',
                  prefix: '\$',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  useFilterStyle: true,
                  onChanged: (value) {
                    final parsed = double.tryParse(value.replaceAll(',', '.'));
                    if (parsed != null) {
                      widget.controller.updateCost(productId, parsed);
                    }
                  },
                ),
              ),
              SizedBox(
                width: 102,
                child: SharedTextField(
                  controller: _discountController,
                  label: 'Descuento',
                  prefix: '\$',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  useFilterStyle: true,
                  onChanged: (value) {
                    final parsed = double.tryParse(value.replaceAll(',', '.'));
                    if (parsed != null) {
                      widget.controller.updateLineDiscount(productId, parsed);
                    }
                  },
                ),
              ),
              SizedBox(
                width: 176,
                child: FilterDropdown<String>(
                  label: 'IVA de línea',
                  value: vatType,
                  items: const [
                    DropdownMenuItem(
                      value: 'standard',
                      child: Text('Tarifa vigente'),
                    ),
                    DropdownMenuItem(value: 'zero', child: Text('0 %')),
                    DropdownMenuItem(
                      value: 'notObject',
                      child: Text('No objeto'),
                    ),
                    DropdownMenuItem(value: 'exempt', child: Text('Exento')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      widget.controller.updateLineVat(productId, value);
                    }
                  },
                ),
              ),
              if (vatType == 'standard')
                SizedBox(
                  width: 88,
                  child: SharedTextField(
                    controller: _vatRateController,
                    label: 'IVA %',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    useFilterStyle: true,
                    onChanged: (value) {
                      final parsed = double.tryParse(
                        value.replaceAll(',', '.'),
                      );
                      if (parsed != null) {
                        widget.controller.updateLineVat(
                          productId,
                          vatType,
                          rate: parsed,
                        );
                      }
                    },
                  ),
                ),
              _ValueBadge(
                label: 'IVA',
                value: '\$${line.vatAmount.toStringAsFixed(2)}',
              ),
              _ValueBadge(
                label: bonusQuantity > 0
                    ? 'Total · +$bonusQuantity gratis'
                    : 'Total',
                value: '\$${line.total.toStringAsFixed(2)}',
                color: AppColors.mutedCream,
                textColor: AppColors.plumGray,
              ),
            ],
          ),
        ],
      ),
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
    this.color = AppColors.paleCream,
    this.textColor = AppColors.dustyRose,
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
