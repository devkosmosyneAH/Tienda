import 'package:tienda/Presentation/Context/inventory_provider.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:tienda/Presentation/Widgets/Inventory/inventory_attention_section.dart';
import 'package:tienda/Presentation/Widgets/Inventory/inventory_charts.dart';
import 'package:tienda/Presentation/Widgets/Inventory/inventory_investment_card.dart';
import 'package:tienda/Presentation/Widgets/Inventory/inventory_quick_stats.dart';
import 'package:tienda/Presentation/Widgets/Inventory/inventory_status_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

class InventorySummaryTab extends StatelessWidget {
  const InventorySummaryTab({
    super.key,
    required this.provider,
  });

  final InventoryProvider provider;

  @override
  Widget build(BuildContext context) {
    final items = provider.inventoryItems;
    final outOfStock = items.where((i) => i.quantity == 0).length;
    final toOrder = items.where((i) => i.quantity > 0 && i.quantity <= 2).length;
    final stable = items.where((i) => i.quantity > 2 && i.quantity <= 10).length;
    final excess = items.where((i) => i.quantity > 10).length;
    final avgStock = items.isEmpty
        ? 0.0
        : (provider.summary?.totalUnits ?? 0) / items.length;
    final criticalStock = items
        .where((i) => i.quantity > 0 && i.quantity <= 5)
        .length;
    final fmt = NumberFormat('#,##0.0', 'es');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.blackOverlay,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondaryLogo,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.grid_view_rounded,
                  color: AppColors.whiteOverlay,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard de Inventario',
                    style: TextStyle(
                      color: AppColors.whiteOverlay,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Análisis completo de tu inventario',
                    style: TextStyle(
                      color: AppColors.greyOverlay,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(
              begin: -0.1,
              end: 0,
              duration: 400.ms,
              curve: Curves.easeOut,
            ),
        const SizedBox(height: 16),
        InventoryStatusCards(
          totalProducts: provider.summary?.totalProducts ?? 0,
          outOfStock: outOfStock,
          toOrder: toOrder,
          stable: stable,
          excess: excess,
          itemsCount: items.length,
        )
            .animate()
            .fadeIn(delay: 100.ms, duration: 350.ms)
            .slideX(
              begin: 0.2,
              end: 0,
              delay: 100.ms,
              duration: 350.ms,
              curve: Curves.easeOut,
            ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEF2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: InventoryQuickStats(
            totalInvested: provider.summary?.totalInvested ?? 0,
            avgStock: avgStock,
            outOfStock: outOfStock,
            criticalStock: criticalStock,
            fmt: fmt,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Valor promedio por producto: ${fmt.format(provider.summary?.averageProductValue ?? 0)}',
            style: const TextStyle(fontSize: 12, color: AppColors.mediumGray),
          ),
        ),
        const SizedBox(height: 16),
        InventoryInvestmentCard(items: items, fmt: fmt)
            .animate()
            .fadeIn(delay: 200.ms, duration: 400.ms)
            .slideY(
              begin: 0.1,
              end: 0,
              delay: 200.ms,
              duration: 400.ms,
              curve: Curves.easeOut,
            ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: InventoryDonutChart(
                outOfStock: outOfStock,
                toOrder: toOrder,
                stable: stable,
                excess: excess,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: InventoryBarChart(items: items)),
          ],
        )
            .animate()
            .fadeIn(delay: 300.ms, duration: 400.ms)
            .slideY(
              begin: 0.1,
              end: 0,
              delay: 300.ms,
              duration: 400.ms,
              curve: Curves.easeOut,
            ),
        const SizedBox(height: 16),
        InventoryAttentionSection(items: items, fmt: fmt)
            .animate()
            .fadeIn(delay: 400.ms, duration: 400.ms)
            .slideY(
              begin: 0.1,
              end: 0,
              delay: 400.ms,
              duration: 400.ms,
              curve: Curves.easeOut,
            ),
        const SizedBox(height: 16),
      ],
    );
  }
}
