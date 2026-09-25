import 'package:tienda/Presentation/Controller/pos_controller.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:tienda/Presentation/Widgets/Products/shared_inputs.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────
//  Dialog: Búsqueda de Cliente
// ─────────────────────────────────────────────────────────────────

class PosClientSearchDialog extends StatefulWidget {
  const PosClientSearchDialog({super.key});

  @override
  State<PosClientSearchDialog> createState() => _PosClientSearchDialogState();
}

class _PosClientSearchDialogState extends State<PosClientSearchDialog> {
  String _query = '';
  String _searchBy = 'Nombre';
  final _searchByOptions = ['Nombre', 'Cédula / RUC', 'Teléfono'];

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> customers) {
    final q = _query.toLowerCase().trim();
    if (q.isEmpty) return customers;
    return customers.where((c) {
      switch (_searchBy) {
        case 'Cédula / RUC':
          return (c['cedula']?.toString() ?? '').toLowerCase().contains(q);
        case 'Teléfono':
          return (c['phone']?.toString() ?? '').toLowerCase().contains(q);
        default:
          return (c['name']?.toString() ?? '').toLowerCase().contains(q);
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PosController>();
    final filtered = _filtered(controller.customers);

    return Dialog(
      backgroundColor: AppColors.gery100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 520,
        height: 540,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Cabecera
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
              child: Row(
                children: [
                  const Text(
                    'Buscar Cliente',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            // ── Buscar por
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: Row(
                children: [
                  const Text(
                    'Buscar por: ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  DropdownButton<String>(
                    value: _searchBy,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                    items: _searchByOptions
                        .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _searchBy = v;
                          _query = '';
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            // ── Campo de búsqueda
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SharedTextField(
                autofocus: true,
                hint: 'Ingrese criterio de búsqueda',
                prefixIcon: const Icon(
                  Icons.search,
                  size: 18,
                  color: Colors.black38,
                ),
                useFilterStyle: true,
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 8),
            // ── Lista
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                children: [
                  // Consumidor final
                  GestureDetector(
                    onTap: () {
                      controller.selectCustomer(null);
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.whiteOverlay,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 18,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Consumidor final',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Icon(
                            Icons.check,
                            color: Colors.green.shade600,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  ...filtered.map((c) {
                    final name = c['name']?.toString() ?? '';
                    final cedula = c['cedula']?.toString();
                    return GestureDetector(
                      onTap: () {
                        controller.selectCustomer((c['id'] as num).toInt());
                        Navigator.pop(context);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (cedula != null && cedula.isNotEmpty)
                                    Text(
                                      'Cédula: $cedula',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.check,
                              color: Colors.green.shade600,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (filtered.isEmpty && _query.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'No se encontraron clientes',
                          style: TextStyle(color: Colors.black45),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ── Cancelar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: Material(
                  color: AppColors.primaryRed,
                  elevation: 4,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(25),
                  clipBehavior: Clip.antiAlias,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.whiteOverlay,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
