import 'package:tienda/Presentation/Context/pos_sale_provider.dart';
import 'package:tienda/Presentation/Controller/pos_controller.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:tienda/Presentation/Widgets/Products/shared_inputs.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────
//  Widget: Sección de Cliente con panel de edición
// ─────────────────────────────────────────────────────────────────

class PosClienteSection extends StatelessWidget {
  final void Function(BuildContext, PosController) onShowClientSearch;

  const PosClienteSection({super.key, required this.onShowClientSearch});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PosController>();
    final sale = context.watch<PosSaleProvider>();

    final selectedCustomer = controller.selectedCustomerId != null
        ? controller.customers.firstWhere(
            (c) => (c['id'] as num).toInt() == controller.selectedCustomerId,
            orElse: () => {},
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Fila de título
        Row(
          children: [
            const Text(
              'Cliente',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            if (selectedCustomer != null && selectedCustomer.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, color: Colors.white, size: 13),
                    SizedBox(width: 4),
                    Text(
                      'Seleccionado',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            const Spacer(),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.blackOverlay,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => onShowClientSearch(context, controller),
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Buscar Cliente'),
            ),
          ],
        ),
        // ── Checkbox consumidor final
        Row(
          children: [
            Checkbox(
              value: sale.isConsumerFinal,
              activeColor: AppColors.blackOverlay,
              onChanged: (v) {
                if (v != null) {
                  context.read<PosSaleProvider>().setConsumerFinal(v);
                  if (v) controller.selectCustomer(null);
                }
              },
            ),
            const Text('Consumidor final'),
          ],
        ),
        // ── Panel editable del cliente seleccionado
        if (!sale.isConsumerFinal)
          PosClienteDetailPanel(
            customer: selectedCustomer ?? const <String, dynamic>{},
            onUpdate: selectedCustomer == null
                ? (_) async {}
                : (data) => controller.updateCustomer(
                    id: (selectedCustomer['id'] as num).toInt(),
                    name: data['name'] ?? '',
                    phone: data['phone'],
                    email: data['email'],
                    notes: data['notes'],
                    cedula: data['cedula'],
                    identificationType: data['identification_type'],
                    address: data['address'],
                  ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Widget: Panel editable de datos del cliente
// ─────────────────────────────────────────────────────────────────

class PosClienteDetailPanel extends StatefulWidget {
  final Map<String, dynamic> customer;
  final Future<void> Function(Map<String, String?>) onUpdate;

  const PosClienteDetailPanel({
    super.key,
    required this.customer,
    required this.onUpdate,
  });

  @override
  State<PosClienteDetailPanel> createState() => _PosClienteDetailPanelState();
}

class _PosClienteDetailPanelState extends State<PosClienteDetailPanel> {
  late TextEditingController _cedulaCtrl;
  late TextEditingController _nombresCtrl;
  late TextEditingController _apellidosCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _telefonoCtrl;
  late TextEditingController _direccionCtrl;
  late String _idType;
  bool _saving = false;

  final _idTypes = ['cedula', 'ruc', 'pasaporte', 'otro'];

  @override
  void initState() {
    super.initState();
    _initControllers(widget.customer);
  }

  @override
  void didUpdateWidget(PosClienteDetailPanel old) {
    super.didUpdateWidget(old);
    if (old.customer['id'] != widget.customer['id']) {
      _disposeControllers();
      _initControllers(widget.customer);
    }
  }

  void _initControllers(Map<String, dynamic> c) {
    final fullName = c['name']?.toString() ?? '';
    final parts = fullName.trim().split(' ');
    final half = (parts.length / 2).ceil();
    final nombres = parts.sublist(0, half).join(' ');
    final apellidos = parts.length > 1 ? parts.sublist(half).join(' ') : '';
    _cedulaCtrl = TextEditingController(text: c['cedula']?.toString() ?? '');
    _nombresCtrl = TextEditingController(text: nombres);
    _apellidosCtrl = TextEditingController(text: apellidos);
    _emailCtrl = TextEditingController(text: c['email']?.toString() ?? '');
    _telefonoCtrl = TextEditingController(text: c['phone']?.toString() ?? '');
    _direccionCtrl = TextEditingController(
      text: c['address']?.toString() ?? '',
    );
    final rawType = c['identification_type']?.toString() ?? '';
    _idType = _idTypes.contains(rawType) ? rawType : 'cedula';
  }

  void _disposeControllers() {
    _cedulaCtrl.dispose();
    _nombresCtrl.dispose();
    _apellidosCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final n = _nombresCtrl.text.trim();
      final a = _apellidosCtrl.text.trim();
      final fullName = [n, a].where((s) => s.isNotEmpty).join(' ');
      await widget.onUpdate({
        'name': fullName.isNotEmpty ? fullName : n,
        'phone': _telefonoCtrl.text.trim().isNotEmpty
            ? _telefonoCtrl.text.trim()
            : null,
        'email': _emailCtrl.text.trim().isNotEmpty
            ? _emailCtrl.text.trim()
            : null,
        'notes': null,
        'cedula': _cedulaCtrl.text.trim().isNotEmpty
            ? _cedulaCtrl.text.trim()
            : null,
        'identification_type': _idType,
        'address': _direccionCtrl.text.trim().isNotEmpty
            ? _direccionCtrl.text.trim()
            : null,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cliente actualizado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Aviso
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.blackOverlay.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.blackOverlay.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.blackOverlay,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cliente seleccionado. Puedes editar cualquier campo y '
                      'presionar "Actualizar Cliente" para guardar los cambios.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.blackOverlay.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── Tipo ident + Cédula
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tipo ident.:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    DropdownButton<String>(
                      value: _idType,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down, size: 18),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                      items: _idTypes
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _idType = v);
                      },
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _idType,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black45,
                        ),
                      ),
                      SharedTextField(
                        controller: _cedulaCtrl,
                        keyboardType: TextInputType.number,
                        hint: 'Número de identificación',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // ── Nombres + Apellidos
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nombres',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SharedTextField(
                        controller: _nombresCtrl,
                        label: 'Nombres',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Apellidos',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SharedTextField(
                        controller: _apellidosCtrl,
                        label: 'Apellidos',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // ── Correo + Teléfono
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Correo electrónico',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SharedTextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        label: 'Correo electrónico',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Teléfono',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SharedTextField(
                        controller: _telefonoCtrl,
                        keyboardType: TextInputType.phone,
                        label: 'Teléfono',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // ── Dirección
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dirección',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SharedTextField(
                  controller: _direccionCtrl,
                  label: 'Dirección',
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (widget.customer['id'] != null)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.blackOverlay,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Actualizar Cliente'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
