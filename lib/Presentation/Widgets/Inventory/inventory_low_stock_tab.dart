import 'package:tienda/Presentation/Model/inventory_model.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:tienda/Presentation/Widgets/Inventory/inventory_empty_state.dart';
import 'package:tienda/Presentation/Widgets/Inventory/inventory_filter_chips.dart';
import 'package:tienda/Presentation/Widgets/Inventory/inventory_stock_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class InventoryLowStockTab extends StatefulWidget {
  const InventoryLowStockTab({
    super.key,
    required this.items,
    required this.onOpenDetail,
    this.onBuyProduct,
  });

  final List<InventoryItem> items;
  final ValueChanged<InventoryItem> onOpenDetail;
  final ValueChanged<InventoryItem>? onBuyProduct;

  @override
  State<InventoryLowStockTab> createState() => _InventoryLowStockTabState();
}

class _InventoryLowStockTabState extends State<InventoryLowStockTab> {
  int activeFilter = 0;

  @override
  Widget build(BuildContext context) {
    final allSorted = [...widget.items]..sort((a, b) => a.quantity.compareTo(b.quantity));
    List<InventoryItem> filtered = allSorted;

    switch (activeFilter) {
      case 1:
        filtered = allSorted.where((i) => i.quantity == 0).toList();
        break;
      case 2:
        filtered = allSorted.where((i) => i.quantity >= 1 && i.quantity <= 2).toList();
        break;
      case 3:
        filtered = allSorted.where((i) => i.quantity >= 3 && i.quantity <= 5).toList();
        break;
      case 4:
        filtered = allSorted.where((i) => i.quantity > 10).toList()
          ..sort((a, b) => b.quantity.compareTo(a.quantity));
        break;
      default:
        filtered = allSorted;
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(18, 8, 18, 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.blackOverlay,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.filter_list_rounded,
                  size: 30,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filtros de Stock Bajo',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '${filtered.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'de ${allSorted.length} productos',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.primaryRed,
                    width: 1.5,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.primaryRed,
                  size: 22,
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 350.ms)
            .slideY(
              begin: -0.1,
              end: 0,
              duration: 350.ms,
              curve: Curves.easeOut,
            ),
        Container(
          color: AppColors.lightGray,
          padding: const EdgeInsets.fromLTRB(15, 0, 15, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                InventoryFilterChip(
                  label: 'Todos',
                  icon: Icons.apps,
                  active: activeFilter == 0,
                  onTap: () => setState(() => activeFilter = 0),
                ),
                const SizedBox(width: 8),
                InventoryFilterChip(
                  label: 'Agotado (=0)',
                  icon: Icons.cancel_outlined,
                  active: activeFilter == 1,
                  color: AppColors.primaryRed,
                  onTap: () => setState(() => activeFilter = 1),
                ),
                const SizedBox(width: 8),
                InventoryFilterChip(
                  label: 'Pedir (≤Mín)',
                  icon: Icons.warning_amber_rounded,
                  active: activeFilter == 2,
                  color: Colors.orange,
                  onTap: () => setState(() => activeFilter = 2),
                ),
                const SizedBox(width: 8),
                InventoryFilterChip(
                  label: 'Estable',
                  icon: Icons.check_circle_outline,
                  active: activeFilter == 3,
                  color: AppColors.darkGreen,
                  onTap: () => setState(() => activeFilter = 3),
                ),
                const SizedBox(width: 8),
                InventoryFilterChip(
                  label: 'Exceso (≥Max)',
                  icon: Icons.trending_up,
                  active: activeFilter == 4,
                  color: AppColors.primaryBlue,
                  onTap: () => setState(() => activeFilter = 4),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: 80.ms, duration: 350.ms),
        const SizedBox(height: 10),
        Expanded(
          child: filtered.isEmpty
              ? const InventoryEmptyState(
                  icon: Icons.check_circle_outline,
                  title: '¡Sin productos en este filtro!',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final item = filtered[i];
                    final isZero = item.quantity == 0;
                    final isLow = !isZero && item.quantity <= 5;
                    return InventoryStockRow(
                      item: item,
                      isZero: isZero,
                      isLow: isLow,
                      accentColor: activeFilter == 3 ? AppColors.darkGreen : null,
                      onTap: () => widget.onOpenDetail(item),
                      onPurchase: widget.onBuyProduct,
                    )
                        .animate()
                        .fadeIn(
                          delay: Duration(milliseconds: 40 * (i % 20)),
                          duration: 320.ms,
                        )
                        .slideX(
                          begin: -0.1,
                          end: 0,
                          delay: Duration(milliseconds: 40 * (i % 20)),
                          duration: 320.ms,
                          curve: Curves.easeOut,
                        );
                  },
                ),
        ),
      ],
    );
  }
}
