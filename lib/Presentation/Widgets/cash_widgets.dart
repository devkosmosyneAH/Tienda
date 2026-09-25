import 'package:tienda/Presentation/Model/cash_model.dart';
import 'package:tienda/Presentation/Widgets/Products/shared_inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Widget principal: entrada de denominaciones ──────────────────────────────

/// Permite al usuario ingresar cuántos billetes y monedas tiene.
/// Devuelve la lista de [DenominationEntry] y el gran total en tiempo real.
///
/// Uso:
/// ```dart
/// DenominationInputWidget(
///   onChanged: (entries, total) { ... },
/// )
/// ```
class DenominationInputWidget extends StatefulWidget {
  final void Function(List<DenominationEntry> entries, double total) onChanged;
  final List<DenominationEntry>? initialEntries;

  const DenominationInputWidget({
    super.key,
    required this.onChanged,
    this.initialEntries,
  });

  @override
  State<DenominationInputWidget> createState() =>
      _DenominationInputWidgetState();
}

class _DenominationInputWidgetState extends State<DenominationInputWidget> {
  late List<DenominationEntry> _billEntries;
  late List<DenominationEntry> _coinEntries;

  @override
  void initState() {
    super.initState();

    DenominationEntry findOrCreate(CashDenomination denom) {
      if (widget.initialEntries != null) {
        final found = widget.initialEntries!.where(
          (e) =>
              e.denomination.value == denom.value &&
              e.denomination.isCoin == denom.isCoin,
        );
        if (found.isNotEmpty) return found.first;
      }
      return DenominationEntry(denomination: denom);
    }

    _billEntries = CashDenominations.bills.map(findOrCreate).toList();
    _coinEntries = CashDenominations.coins.map(findOrCreate).toList();
  }

  List<DenominationEntry> get _allEntries => [..._billEntries, ..._coinEntries];

  double get _total => _allEntries.fold(0.0, (sum, e) => sum + e.subtotal);

  void _notify() => widget.onChanged(_allEntries, _total);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: 'Billetes', icon: Icons.attach_money),
        const SizedBox(height: 4),
        ..._billEntries.map(
          (e) => _DenominationRow(
            entry: e,
            onQtyChanged: (qty) {
              setState(() => e.quantity = qty);
              _notify();
            },
          ),
        ),
        const Divider(height: 20),
        _SectionLabel(label: 'Monedas', icon: Icons.monetization_on_outlined),
        const SizedBox(height: 4),
        ..._coinEntries.map(
          (e) => _DenominationRow(
            entry: e,
            onQtyChanged: (qty) {
              setState(() => e.quantity = qty);
              _notify();
            },
          ),
        ),
        const Divider(height: 20),
        _TotalRow(
          labelBills: 'Total billetes',
          totalBills: _billEntries.fold(0.0, (s, e) => s + e.subtotal),
          labelCoins: 'Total monedas',
          totalCoins: _coinEntries.fold(0.0, (s, e) => s + e.subtotal),
          grandTotal: _total,
        ),
      ],
    );
  }
}

// ─── Fila de una denominación ─────────────────────────────────────────────────

class _DenominationRow extends StatefulWidget {
  final DenominationEntry entry;
  final ValueChanged<int> onQtyChanged;

  const _DenominationRow({required this.entry, required this.onQtyChanged});

  @override
  State<_DenominationRow> createState() => _DenominationRowState();
}

class _DenominationRowState extends State<_DenominationRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.entry.quantity > 0 ? widget.entry.quantity.toString() : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = widget.entry.subtotal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Denominación
          SizedBox(
            width: 60,
            child: Text(
              widget.entry.denomination.label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          // Botón -
          IconButton(
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            iconSize: 20,
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: widget.entry.quantity > 0
                ? () {
                    final newQty = widget.entry.quantity - 1;
                    _ctrl.text = newQty > 0 ? newQty.toString() : '';
                    widget.onQtyChanged(newQty);
                  }
                : null,
          ),
          // Campo cantidad
          SizedBox(
            width: 56,
            child: SharedTextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              hint: '0',
              onChanged: (v) {
                final qty = int.tryParse(v) ?? 0;
                widget.onQtyChanged(qty);
              },
            ),
          ),
          // Botón +
          IconButton(
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            iconSize: 20,
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              final newQty = widget.entry.quantity + 1;
              _ctrl.text = newQty.toString();
              widget.onQtyChanged(newQty);
            },
          ),
          const Spacer(),
          // Subtotal de esta fila
          SizedBox(
            width: 72,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Text(
                subtotal > 0 ? '\$${subtotal.toStringAsFixed(2)}' : '—',
                key: ValueKey(subtotal),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  color: subtotal > 0
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Etiqueta de sección ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}

// ─── Fila de totales ──────────────────────────────────────────────────────────

class _TotalRow extends StatelessWidget {
  final String labelBills;
  final double totalBills;
  final String labelCoins;
  final double totalCoins;
  final double grandTotal;

  const _TotalRow({
    required this.labelBills,
    required this.totalBills,
    required this.labelCoins,
    required this.totalCoins,
    required this.grandTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _subtotalLine(context, labelBills, totalBills, bold: false),
        _subtotalLine(context, labelCoins, totalCoins, bold: false),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL EN CAJA',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Text(
                '\$${grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _subtotalLine(
    BuildContext ctx,
    String label,
    double amount, {
    required bool bold,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Widget de resumen (solo lectura) ─────────────────────────────────────────

/// Muestra un resumen de denominaciones en modo lectura (p.ej. en el detalle de caja).
class CashBreakdownSummary extends StatelessWidget {
  final CashBreakdown breakdown;
  final String title;

  const CashBreakdownSummary({
    super.key,
    required this.breakdown,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final billEntries = breakdown.entries
        .where((e) => !e.denomination.isCoin && e.quantity > 0)
        .toList();
    final coinEntries = breakdown.entries
        .where((e) => e.denomination.isCoin && e.quantity > 0)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 6),
        if (billEntries.isNotEmpty) ...[
          const Text(
            'Billetes',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          ...billEntries.map((e) => _ReadOnlyRow(entry: e)),
        ],
        if (coinEntries.isNotEmpty) ...[
          const SizedBox(height: 4),
          const Text(
            'Monedas',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          ...coinEntries.map((e) => _ReadOnlyRow(entry: e)),
        ],
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Billetes:', style: TextStyle(fontSize: 12)),
            Text(
              '\$${breakdown.totalBills.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Monedas:', style: TextStyle(fontSize: 12)),
            Text(
              '\$${breakdown.totalCoins.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        const Divider(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              '\$${breakdown.grandTotal.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  final DenominationEntry entry;
  const _ReadOnlyRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              entry.denomination.label,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Text(
            '× ${entry.quantity}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const Spacer(),
          Text(
            '\$${entry.subtotal.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
