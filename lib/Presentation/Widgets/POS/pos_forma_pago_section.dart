import 'package:tienda/Presentation/Context/pos_sale_provider.dart';
import 'package:tienda/Presentation/Controller/pos_controller.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:tienda/Presentation/Widgets/Products/shared_inputs.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────
//  Widget: Forma de Pago
// ─────────────────────────────────────────────────────────────────

class PosFormaPagoSection extends StatefulWidget {
  const PosFormaPagoSection({super.key});

  @override
  State<PosFormaPagoSection> createState() => _PosFormaPagoSectionState();
}

class _PosFormaPagoSectionState extends State<PosFormaPagoSection> {
  late final TextEditingController _amountController;
  late final TextEditingController _referenceController;
  String _electronicType = 'Transferencia Bancaria';
  String _depositType = 'Depósito Bancario';
  String _cardType = 'Crédito';
  String _otherType = 'Cheque';
  int _installmentDays = 7;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: '0.00');
    _referenceController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  bool _isElectronicMethod(String name) {
    final normalized = name.toLowerCase();
    return normalized.contains('electr') ||
        normalized.contains('transfer') ||
        normalized.contains('paypal');
  }

  bool _isDepositMethod(String name) {
    final normalized = name.toLowerCase();
    return normalized.contains('deposit') || normalized.contains('depósito');
  }

  List<_PaymentOption> _paymentOptions(List<Map<String, dynamic>> methods) {
    Map<String, dynamic>? findMethod(bool Function(String) matches) {
      for (final method in methods) {
        if (matches(method['name'].toString().toLowerCase())) return method;
      }
      return null;
    }

    final cash = findMethod((name) => name.contains('efectivo'));
    final electronic = findMethod(
      (name) =>
          name.contains('transfer') ||
          name.contains('electr') ||
          name.contains('paypal'),
    );
    final card = findMethod(
      (name) => name.contains('tarjeta') || name.contains('card'),
    );
    final other = findMethod(
      (name) =>
          name.contains('deposit') ||
          name.contains('depósito') ||
          name.contains('otro'),
    );
    final installments = findMethod(
      (name) =>
          name.contains('credito') ||
          name.contains('crédito') ||
          name.contains('plazo'),
    );

    return [
      _PaymentOption('EFECTIVO', cash),
      _PaymentOption('DINERO ELECTRÓNICO', electronic),
      _PaymentOption('TARJETA DE CRÉDITO', card),
      _PaymentOption('OTROS', other),
      _PaymentOption('PAGO A PLAZOS', installments),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PosController>();
    final sale = context.watch<PosSaleProvider>();

    final defaultId = controller.paymentMethods.isNotEmpty
        ? (controller.paymentMethods.first['id'] as num).toInt()
        : null;

    final payments = sale.payments;
    final options = _paymentOptions(controller.paymentMethods);
    final selectedId =
        sale.selectedPaymentMethodId ??
        options
            .firstWhere(
              (option) => option.method != null,
              orElse: () => _PaymentOption('', null),
            )
            .id ??
        defaultId;
    final selectedOption = options.cast<_PaymentOption?>().firstWhere(
      (option) => option?.id == selectedId,
      orElse: () => null,
    );
    final selectedMethod = controller.paymentMethods.firstWhere(
      (method) => (method['id'] as num).toInt() == selectedId,
      orElse: () => <String, dynamic>{},
    );
    final isElectronic =
        selectedOption?.label == 'DINERO ELECTRÓNICO' ||
        _isElectronicMethod(selectedMethod['name']?.toString() ?? '');
    final isDeposit =
        _isDepositMethod(selectedMethod['name']?.toString() ?? '') &&
        selectedOption?.label != 'OTROS';
    final isCard = selectedOption?.label == 'TARJETA DE CRÉDITO';
    final isOther = selectedOption?.label == 'OTROS';
    final isInstallment = selectedOption?.label == 'PAGO A PLAZOS';
    final dueDate = DateTime.now().add(Duration(days: _installmentDays));
    final dueDateText =
        '${dueDate.day.toString().padLeft(2, '0')}/'
        '${dueDate.month.toString().padLeft(2, '0')}/'
        '${dueDate.year}';

    return Card(
      elevation: 0,
      color: AppColors.whiteOverlay,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text(
                  'Agregar Forma de Pago',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.currency_exchange, size: 18),
                  label: const Text('Editar Tasas'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green.shade800,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 12),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.blackOverlay.withValues(alpha: 0.05),
                border: Border.all(
                  color: AppColors.blackOverlay.withValues(alpha: 0.2),
                ),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Rate(label: 'SOL → USD', value: '3.48'),
                  _Rate(label: 'EUR → USD', value: '1.10'),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.blackOverlay.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Método de Pago',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: options.map((option) {
                      final id = option.id;
                      final selected = selectedId == id;
                      return OutlinedButton.icon(
                        onPressed: id == null
                            ? null
                            : () {
                                context
                                    .read<PosSaleProvider>()
                                    .selectPaymentMethod(id);
                                if (!_isElectronicMethod(option.methodName) &&
                                    !_isDepositMethod(option.methodName)) {
                                  setState(() {
                                    _electronicType = 'Transferencia Bancaria';
                                    _depositType = 'Depósito Bancario';
                                    _cardType = 'Crédito';
                                    _otherType = 'Cheque';
                                    _installmentDays = 7;
                                  });
                                }
                              },
                        icon: selected
                            ? const Icon(Icons.check, size: 15)
                            : const SizedBox.shrink(),
                        label: Text(option.label),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: selected
                              ? Colors.white
                              : Colors.black87,
                          backgroundColor: selected
                              ? Colors.green.shade800
                              : Colors.white,
                          side: BorderSide(
                            color: selected
                                ? Colors.green.shade800
                                : Colors.deepPurple.shade100,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            if (isElectronic) ...[
              const SizedBox(height: 24),
              _FieldShell(
                label: 'Tipo de Dinero Electrónico',
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children:
                      [
                        'Transferencia Bancaria',
                        'Billetera Digital',
                        'Código QR',
                      ].map((type) {
                        final selected = _electronicType == type;
                        return OutlinedButton(
                          onPressed: () =>
                              setState(() => _electronicType = type),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black87,
                            backgroundColor: selected
                                ? Colors.green.shade50
                                : Colors.white,
                            side: BorderSide(
                              color: selected
                                  ? Colors.green.shade800
                                  : Colors.deepPurple.shade100,
                              width: selected ? 1.5 : 1,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            type,
                            style: const TextStyle(fontSize: 11),
                          ),
                        );
                      }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              _FieldShell(
                label: 'Referencia de Transacción',
                child: SharedTextField(
                  controller: _referenceController,
                  hint: 'Número de transacción / Referencia',
                ),
              ),
            ],
            if (isDeposit) ...[
              const SizedBox(height: 24),
              _FieldShell(
                label: 'Tipo de Depósito',
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ['Depósito Bancario', 'Depósito en Efectivo'].map((
                    type,
                  ) {
                    final selected = _depositType == type;
                    return OutlinedButton(
                      onPressed: () => setState(() => _depositType = type),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        backgroundColor: selected
                            ? Colors.green.shade50
                            : Colors.white,
                        side: BorderSide(
                          color: selected
                              ? Colors.green.shade800
                              : Colors.deepPurple.shade100,
                          width: selected ? 1.5 : 1,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(type, style: const TextStyle(fontSize: 11)),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              _FieldShell(
                label: 'Referencia de Transacción',
                child: SharedTextField(
                  controller: _referenceController,
                  hint: 'Número de depósito / Referencia',
                ),
              ),
            ],
            if (isCard) ...[
              const SizedBox(height: 24),
              _FieldShell(
                label: 'Tipo de Tarjeta',
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ['Débito', 'Crédito'].map((type) {
                    final selected = _cardType == type;
                    return OutlinedButton(
                      onPressed: () => setState(() => _cardType = type),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        backgroundColor: selected
                            ? Colors.green.shade50
                            : Colors.white,
                        side: BorderSide(
                          color: selected
                              ? Colors.green.shade800
                              : Colors.deepPurple.shade100,
                          width: selected ? 1.5 : 1,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(type, style: const TextStyle(fontSize: 11)),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              _FieldShell(
                label: 'Referencia de Transacción',
                child: SharedTextField(
                  controller: _referenceController,
                  hint: 'Número de transacción / Referencia',
                ),
              ),
            ],
            if (isOther) ...[
              const SizedBox(height: 24),
              _FieldShell(
                label: 'Tipo de Pago',
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children:
                      [
                        'Cheque',
                        'Pagaré',
                        'Depósito Bancario',
                        'Canje/Voucher',
                      ].map((type) {
                        final selected = _otherType == type;
                        return OutlinedButton(
                          onPressed: () => setState(() => _otherType = type),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black87,
                            backgroundColor: selected
                                ? Colors.green.shade50
                                : Colors.white,
                            side: BorderSide(
                              color: selected
                                  ? Colors.green.shade800
                                  : Colors.deepPurple.shade100,
                              width: selected ? 1.5 : 1,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            type,
                            style: const TextStyle(fontSize: 11),
                          ),
                        );
                      }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              _FieldShell(
                label: 'Referencia de Transacción',
                child: SharedTextField(
                  controller: _referenceController,
                  hint: 'Número de transacción / Referencia',
                ),
              ),
            ],
            if (isInstallment) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Días de Plazo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [7, 15, 30, 45, 60, 90].map((days) {
                        final selected = _installmentDays == days;
                        return OutlinedButton.icon(
                          onPressed: () =>
                              setState(() => _installmentDays = days),
                          icon: selected
                              ? const Icon(Icons.check, size: 14)
                              : const SizedBox.shrink(),
                          label: Text('$days días'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: selected
                                ? Colors.white
                                : Colors.black87,
                            backgroundColor: selected
                                ? Colors.green.shade700
                                : Colors.white,
                            side: BorderSide(
                              color: selected
                                  ? Colors.green.shade700
                                  : Colors.deepPurple.shade100,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        border: Border.all(color: Colors.orange.shade300),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: Colors.orange.shade800,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Vence: $dueDateText',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!isInstallment) ...[
              const SizedBox(height: 36),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: _FieldShell(
                      label: 'Moneda',
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: 'USD',
                          isExpanded: true,
                          items: [
                            DropdownMenuItem(value: 'USD', child: Text('USD')),
                          ],
                          onChanged: null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: _FieldShell(
                      label: 'Monto',
                      child: SharedTextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 34,
                child: ElevatedButton.icon(
                  onPressed: () => context.read<PosSaleProvider>().addPayment(
                    controller.paymentMethods,
                    sale.effectiveTotal(controller.total),
                    amount: double.tryParse(_amountController.text),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar Pago'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              if (payments.isEmpty)
                const Center(
                  child: Text(
                    'Sin pagos registrados',
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              else
                ...payments.asMap().entries.map(
                  (entry) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.payments_outlined),
                    title: Text(entry.value.methodName),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('\$${entry.value.amount.toStringAsFixed(2)}'),
                        IconButton(
                          onPressed: () => context
                              .read<PosSaleProvider>()
                              .removePayment(entry.key),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Rate extends StatelessWidget {
  final String label;
  final String value;

  const _Rate({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    ],
  );
}

class _PaymentOption {
  final String label;
  final Map<String, dynamic>? method;

  const _PaymentOption(this.label, this.method);

  int? get id => method == null ? null : (method!['id'] as num).toInt();

  String get methodName => method?['name']?.toString() ?? '';
}

class _FieldShell extends StatelessWidget {
  final String label;
  final Widget child;

  const _FieldShell({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        child,
      ],
    ),
  );
}
