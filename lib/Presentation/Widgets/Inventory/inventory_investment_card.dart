import 'package:tienda/Presentation/Model/inventory_model.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InventoryInvestmentCard extends StatelessWidget {
  const InventoryInvestmentCard({
    super.key,
    required this.items,
    required this.fmt,
  });

  final List<InventoryItem> items;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final compraTotalAll = items.fold<double>(
      0,
      (s, i) => s + i.costPrice * i.quantity,
    );
    final ventaTotalAll = items.fold<double>(
      0,
      (s, i) => s + i.sellPrice * i.quantity,
    );
    final diferencia = ventaTotalAll - compraTotalAll;
    final pct = compraTotalAll == 0 ? 0.0 : (diferencia / compraTotalAll) * 100;
    final conExistencia = items.where((i) => i.quantity > 0).length;

    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.primaryBlue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Inversión en Bodega (stock existente)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$conExistencia productos con existencia > 0',
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InventoryInvestmentBox(
                  icon: Icons.shopping_cart_outlined,
                  iconColor: Colors.orange,
                  label: 'Compra total',
                  value: fmt.format(compraTotalAll),
                  valueColor: Colors.orange,
                  bgColor: const Color(0xFFFFF3E0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InventoryInvestmentBox(
                  icon: Icons.label_outline,
                  iconColor: AppColors.primaryBlue,
                  label: 'Venta total',
                  value: fmt.format(ventaTotalAll),
                  valueColor: AppColors.primaryBlue,
                  bgColor: const Color(0xFFE8F0FB),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InventoryInvestmentBox(
                  icon: Icons.trending_up,
                  iconColor: Colors.green,
                  label: 'Diferencia',
                  value: '${fmt.format(diferencia)} (${pct.toStringAsFixed(1)}%)',
                  valueColor: Colors.green,
                  bgColor: const Color(0xFFE8F5E9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class InventoryInvestmentBox extends StatelessWidget {
  const InventoryInvestmentBox({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.bgColor,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
