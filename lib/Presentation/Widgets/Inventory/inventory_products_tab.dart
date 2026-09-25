import 'package:tienda/Presentation/Context/inventory_provider.dart';
import 'package:tienda/Presentation/Model/inventory_model.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:tienda/Presentation/Widgets/Inventory/inventory_product_card.dart';
import 'package:tienda/Presentation/Widgets/Products/filter_dropdown.dart';
import 'package:tienda/Presentation/Widgets/Products/shared_inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

class InventoryProductsTab extends StatelessWidget {
  const InventoryProductsTab({
    super.key,
    required this.provider,
    required this.searchController,
    required this.codeController,
    required this.onOpenDetail,
    required this.onFilterChanged,
  });

  final InventoryProvider provider;
  final TextEditingController searchController;
  final TextEditingController codeController;
  final ValueChanged<InventoryItem> onOpenDetail;
  final VoidCallback onFilterChanged;

  List<InventoryItem> _filtrarProductos() {
    final texto = searchController.text.trim().toLowerCase();
    final codigo = codeController.text.trim().toLowerCase();
    return provider.inventoryItems.where((item) {
      final matchTexto =
          texto.isEmpty ||
          item.name.toLowerCase().contains(texto) ||
          item.description.toLowerCase().contains(texto) ||
          item.category.toLowerCase().contains(texto);
      final matchCodigo =
          codigo.isEmpty ||
          item.sku.toLowerCase().contains(codigo) ||
          item.auxCode.toLowerCase().contains(codigo) ||
          item.productId.toString().contains(codigo);
      return matchTexto && matchCodigo;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtrarProductos();
    final fmt = NumberFormat('#,##0.00', 'es');

    return Column(
      children: [
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            color: AppColors.lightGray,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.grid_view_rounded,
                  color: AppColors.darkGray,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SharedTextField(
                    controller: codeController,
                    hint:
                        'Buscar por código, código auxiliar o código de barras...',
                    useFilterStyle: true,
                    onChanged: (_) => onFilterChanged(),
                  ),
                ),
                if (codeController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      codeController.clear();
                      onFilterChanged();
                    },
                    child: const Icon(
                      Icons.clear,
                      size: 18,
                      color: Colors.black38,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          color: AppColors.lightGray,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              if (provider.stores.length > 1) ...[
                FilterDropdown<int>(
                  label: 'Bazar',
                  value: provider.selectedStoreId,
                  items: provider.stores
                      .map(
                        (s) => DropdownMenuItem<int>(
                          value: (s['id'] as num).toInt(),
                          child: Text(s['name'] ?? 'Tienda'),
                        ),
                      )
                      .toList(),
                  onChanged: (id) {
                    if (id != null) {
                      provider.selectStore(id);
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: SharedTextField(
                      controller: searchController,
                      hint: 'Buscar producto o descripción...',
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 18,
                        color: Colors.black38,
                      ),
                      suffixIcon: searchController.text.isEmpty
                          ? null
                          : GestureDetector(
                              onTap: () {
                                searchController.clear();
                                onFilterChanged();
                              },
                              child: const Icon(
                                Icons.clear,
                                size: 16,
                                color: Colors.black38,
                              ),
                            ),
                      useFilterStyle: true,
                      onChanged: (_) => onFilterChanged(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '${filtered.length} productos encontrados',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No hay productos para este local'))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth >= 1100
                        ? 4
                        : constraints.maxWidth >= 700
                            ? 3
                            : 2;
                    final availableWidth = constraints.maxWidth - 24;
                    final cardWidth =
                        (availableWidth - (crossAxisCount - 1) * 10) /
                            crossAxisCount;

                    return ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: List.generate(
                            filtered.length,
                            (i) => SizedBox(
                              width: cardWidth,
                              child: InventoryProductCard(
                                item: filtered[i],
                                fmt: fmt,
                                onTap: () => onOpenDetail(filtered[i]),
                              )
                                  .animate()
                                  .fadeIn(
                                    delay: Duration(
                                      milliseconds: 25 * (i % 24),
                                    ),
                                    duration: 300.ms,
                                  )
                                  .slideY(
                                    begin: 0.15,
                                    end: 0,
                                    delay: Duration(
                                      milliseconds: 25 * (i % 24),
                                    ),
                                    duration: 300.ms,
                                    curve: Curves.easeOut,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}
