import 'package:tienda/Presentation/Controller/pos_controller.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:tienda/Presentation/Widgets/Products/shared_inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────
//  Dialog: Búsqueda de Producto
// ─────────────────────────────────────────────────────────────────

class PosProductSearchDialog extends StatefulWidget {
  const PosProductSearchDialog({super.key});

  @override
  State<PosProductSearchDialog> createState() => _PosProductSearchDialogState();
}

class _PosProductSearchDialogState extends State<PosProductSearchDialog> {
  int _selectedIndex = 0;
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _products =>
      context.read<PosController>().products;

  void _selectNext() {
    if (_products.isEmpty) return;
    setState(() => _selectedIndex = (_selectedIndex + 1) % _products.length);
  }

  void _selectPrev() {
    if (_products.isEmpty) return;
    setState(
      () => _selectedIndex =
          (_selectedIndex - 1 + _products.length) % _products.length,
    );
  }

  void _addSelected() {
    if (_products.isEmpty) return;
    final ctrl = context.read<PosController>();
    final idx = _selectedIndex.clamp(0, ctrl.products.length - 1);
    final product = ctrl.products[idx];
    final stock = ((product['stock'] as num?)?.toInt()) ?? 0;
    if (stock <= 0) return;
    ctrl.addToCart(product);
    Navigator.pop(context);
  }

  void _updateSearch(String v) {
    context.read<PosController>().updateSearch(v);
    setState(() => _selectedIndex = 0);
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): _selectNext,
        const SingleActivator(LogicalKeyboardKey.arrowUp): _selectPrev,
        const SingleActivator(LogicalKeyboardKey.enter): _addSelected,
      },
      child: Focus(
        autofocus: true,
        child: Dialog(
          backgroundColor: AppColors.lightWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(

            height: 600,
            child: Column(
              children: [
                // ── Título
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
                  child: Row(
                    children: [
                      const Text(
                        'Buscar Producto',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                // ── Campos de búsqueda
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Column(
                    children: [
                      SharedTextField(
                        controller: _codeController,
                        autofocus: true,
                        hint:
                            'Buscar por código, código auxiliar o código de barras...',
                        prefixIcon: const Icon(Icons.search),
                        useFilterStyle: true,
                        onChanged: _updateSearch,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SharedTextField(
                              controller: _nameController,
                              hint: 'Buscar por Producto...',
                              prefixIcon: const Icon(Icons.search, size: 18),
                              useFilterStyle: true,
                              onChanged: _updateSearch,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SharedTextField(
                              controller: _descController,
                              hint: 'Buscar por Descripción...',
                              prefixIcon: const Icon(Icons.search, size: 18),
                              useFilterStyle: true,
                              onChanged: _updateSearch,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // ── Barra de navegación
                Consumer<PosController>(
                  builder: (ctx, ctrl, _) => Container(
                    margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                          onPressed: _selectPrev,
                          tooltip: 'Anterior',
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                          onPressed: _selectNext,
                          tooltip: 'Siguiente',
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Use las flechas para navegar, Enter para seleccionar',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade700,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            ctrl.products.isEmpty
                                ? '0/0'
                                : '${_selectedIndex + 1}/${ctrl.products.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Lista de productos
                Expanded(
                  child: Consumer<PosController>(
                    builder: (ctx, ctrl, _) {
                      if (ctrl.isLoading && ctrl.products.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (ctrl.products.isEmpty) {
                        return const Center(
                          child: Text('No se encontraron productos'),
                        );
                      }
                      final safeIndex = _selectedIndex.clamp(
                        0,
                        ctrl.products.length - 1,
                      );
                      final selectedProduct = ctrl.products[safeIndex];

                      return Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                              itemCount: ctrl.products.length,
                              itemBuilder: (_, index) {
                                final product = ctrl.products[index];
                                final stock =
                                    ((product['stock'] as num?)?.toInt()) ?? 0;
                                final price =
                                    ((product['price'] as num?)?.toDouble()) ??
                                    0;
                                final isSelected = index == safeIndex;

                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedIndex = index),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.blackOverlay.withValues(
                                              alpha: 0.3,
                                            )
                                          : AppColors.blackOverlay.withValues(
                                              alpha: 0.1,
                                            ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.blackOverlay.withValues(
                                                alpha: 0.3,
                                              )
                                            : AppColors.blackOverlay.withValues(
                                                alpha: 0.1,
                                              ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product['name']?.toString() ??
                                                    '',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: isSelected
                                                      ? AppColors.blackOverlay
                                                      : AppColors.blackOverlay,
                                                ),
                                              ),
                                              Text(
                                                'Código: ${product['sku']?.toString() ?? ''}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                              Text(
                                                'Precio: \$${price.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.green.shade700,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                'Stock: $stock',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: stock <= 2
                                                      ? Colors.red
                                                      : Colors.green.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          CircleAvatar(
                                            backgroundColor:
                                                AppColors.blackOverlay,
                                            radius: 16,
                                            child: const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          )
                                        else
                                          GestureDetector(
                                            onTap: stock > 0
                                                ? () {
                                                    ctrl.addToCart(product);
                                                    Navigator.pop(context);
                                                  }
                                                : null,
                                            child: CircleAvatar(
                                              backgroundColor: stock > 0
                                                  ? Colors.green.shade600
                                                  : Colors.grey.shade400,
                                              radius: 16,
                                              child: const Icon(
                                                Icons.add,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          // ── Panel de detalle del producto seleccionado
                          Container(
                            margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.blackOverlay.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.blackOverlay.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Descripción:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.blackOverlay,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  selectedProduct['description']?.toString() ??
                                      selectedProduct['name']?.toString() ??
                                      '',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text(
                                      'Pvp: \$${((selectedProduct['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange.shade800,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Text(
                                      'Stock Disponible: ${((selectedProduct['stock'] as num?)?.toInt()) ?? 0}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                // ── Acciones
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.blackOverlay,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _addSelected,
                        icon: const Icon(Icons.shopping_cart_outlined),
                        label: const Text('Agregar'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
