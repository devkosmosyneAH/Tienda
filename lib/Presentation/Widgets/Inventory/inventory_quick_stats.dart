import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InventoryQuickStats extends StatelessWidget {
  const InventoryQuickStats({
    super.key,
    required this.totalInvested,
    required this.avgStock,
    required this.outOfStock,
    required this.criticalStock,
    required this.fmt,
  });

  final double totalInvested;
  final double avgStock;
  final int outOfStock;
  final int criticalStock;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.bar_chart, color: AppColors.primaryBlue, size: 20),
            SizedBox(width: 8),
            Text(
              'Estadísticas Rápidas',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InventoryQuickStatCard(
                icon: Icons.attach_money,
                iconColor: Colors.green,
                value: fmt.format(totalInvested),
                label: 'Valor Total',
                dotColor: Colors.green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InventoryQuickStatCard(
                icon: Icons.inventory_2_outlined,
                iconColor: AppColors.primaryBlue,
                value: '${avgStock.toStringAsFixed(1)} un.',
                label: 'Stock Promedio',
                dotColor: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: InventoryQuickStatCard(
                icon: Icons.warning_amber_rounded,
                iconColor: AppColors.primaryRed,
                value: outOfStock.toString(),
                label: 'Sin Stock',
                dotColor: AppColors.primaryRed,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InventoryQuickStatCard(
                icon: Icons.star_outline,
                iconColor: Colors.orange,
                value: criticalStock.toString(),
                label: 'Stock Crítico',
                dotColor: Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class InventoryQuickStatCard extends StatelessWidget {
  const InventoryQuickStatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.dotColor,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.whiteOverlay,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const Spacer(),
              Icon(Icons.circle, color: dotColor, size: 8),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
