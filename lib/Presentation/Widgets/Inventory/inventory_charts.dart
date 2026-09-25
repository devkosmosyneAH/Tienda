import 'package:tienda/Presentation/Model/inventory_model.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class InventoryDonutChart extends StatelessWidget {
  const InventoryDonutChart({
    super.key,
    required this.outOfStock,
    required this.toOrder,
    required this.stable,
    required this.excess,
  });

  final int outOfStock;
  final int toOrder;
  final int stable;
  final int excess;

  @override
  Widget build(BuildContext context) {
    final total = outOfStock + toOrder + stable + excess;
    if (total == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.whiteOverlay,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distribución de Stock',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    value: outOfStock.toDouble(),
                    color: AppColors.primaryRed,
                    title: '',
                    radius: 40,
                  ),
                  PieChartSectionData(
                    value: toOrder.toDouble(),
                    color: Colors.orange,
                    title: '',
                    radius: 40,
                  ),
                  PieChartSectionData(
                    value: stable.toDouble(),
                    color: Colors.green,
                    title: '',
                    radius: 40,
                  ),
                  PieChartSectionData(
                    value: excess.toDouble(),
                    color: AppColors.primaryBlue,
                    title: '',
                    radius: 40,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          InventoryChartLegend(
            color: AppColors.primaryRed,
            label: 'Agotado',
            value: outOfStock,
          ),
          InventoryChartLegend(
            color: Colors.orange,
            label: 'Pedir',
            value: toOrder,
          ),
          InventoryChartLegend(
            color: Colors.green,
            label: 'Estable',
            value: stable,
          ),
          InventoryChartLegend(
            color: AppColors.primaryBlue,
            label: 'Exceso',
            value: excess,
          ),
        ],
      ),
    );
  }
}

class InventoryBarChart extends StatelessWidget {
  const InventoryBarChart({
    super.key,
    required this.items,
  });

  final List<InventoryItem> items;

  @override
  Widget build(BuildContext context) {
    final r0 = items.where((i) => i.quantity == 0).length;
    final r1 = items.where((i) => i.quantity >= 1 && i.quantity <= 5).length;
    final r2 = items.where((i) => i.quantity >= 6 && i.quantity <= 10).length;
    final r3 = items.where((i) => i.quantity >= 11 && i.quantity <= 20).length;
    final r4 = items.where((i) => i.quantity >= 21 && i.quantity <= 50).length;
    final r5 = items.where((i) => i.quantity > 50).length;
    final maxY = [r0, r1, r2, r3, r4, r5]
        .fold<int>(1, (m, v) => v > m ? v : m)
        .toDouble();
    final colors = [
      AppColors.primaryRed,
      Colors.orange,
      const Color(0xFFD4A017),
      AppColors.primaryBlue,
      Colors.green,
      Colors.purple,
    ];
    final labels = ['0', '1-5', '6-10', '11-20', '21-50', '50+'];
    final counts = [r0, r1, r2, r3, r4, r5];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.whiteOverlay,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rangos de Stock',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                maxY: maxY * 1.2,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Text(
                        labels[v.toInt()],
                        style: const TextStyle(fontSize: 8),
                      ),
                    ),
                  ),
                ),
                barGroups: List.generate(
                  6,
                  (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: counts[i].toDouble(),
                        color: colors[i],
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InventoryChartLegend extends StatelessWidget {
  const InventoryChartLegend({
    super.key,
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.circle, color: color, size: 10),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11))),
          Text(
            value.toString(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
