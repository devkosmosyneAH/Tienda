import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';

class InventoryStatusCards extends StatelessWidget {
  const InventoryStatusCards({
    super.key,
    required this.totalProducts,
    required this.outOfStock,
    required this.toOrder,
    required this.stable,
    required this.excess,
    required this.itemsCount,
  });

  final int totalProducts;
  final int outOfStock;
  final int toOrder;
  final int stable;
  final int excess;
  final int itemsCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 185,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          InventoryStatusCard(
            value: totalProducts.toString(),
            label: 'Total Productos',
            sublabel: 'En inventario',
            icon: Icons.inventory_2_outlined,
            iconColor: AppColors.primaryBlue,
            iconBgColor: AppColors.lightBlue,
            bgColor: AppColors.whiteOverlay,
            valueColor: AppColors.darkGray,
          ),
          InventoryStatusCard(
            value: outOfStock.toString(),
            label: 'Agotado (=0)',
            sublabel: 'Requiere reposición inmediata',
            badge: 'Requiere atención',
            badgeColor: AppColors.primaryRed,
            icon: Icons.cancel_outlined,
            iconColor: AppColors.primaryRed,
            iconBgColor: AppColors.lightRed,
            bgColor: const Color(0xFFFFE8E6),
            valueColor: AppColors.primaryRed,
          ),
          InventoryStatusCard(
            value: toOrder.toString(),
            label: 'Pedir (≤Mín)',
            sublabel: itemsCount == 0
                ? '0.0% del total'
                : '${(toOrder / itemsCount * 100).toStringAsFixed(1)}% del total',
            badge: 'Requiere atención',
            badgeColor: Colors.orange,
            icon: Icons.warning_amber_rounded,
            iconColor: Colors.orange,
            iconBgColor: const Color(0xFFFFEDD5),
            bgColor: const Color(0xFFFFF3E0),
            valueColor: Colors.orange,
          ),
          InventoryStatusCard(
            value: stable.toString(),
            label: 'Estable (Mín<St<Máx)',
            sublabel: 'Stock óptimo',
            icon: Icons.check_circle_outline,
            iconColor: Colors.green,
            iconBgColor: AppColors.lightGreen,
            bgColor: AppColors.whiteOverlay,
            valueColor: AppColors.darkGray,
          ),
          InventoryStatusCard(
            value: excess.toString(),
            label: 'Exceso (≥Máx)',
            sublabel: 'Stock por encima del máximo',
            icon: Icons.trending_up,
            iconColor: AppColors.primaryBlue,
            iconBgColor: AppColors.lightBlue,
            bgColor: AppColors.whiteOverlay,
            valueColor: AppColors.darkGray,
          ),
        ],
      ),
    );
  }
}

class InventoryStatusCard extends StatelessWidget {
  const InventoryStatusCard({
    super.key,
    required this.value,
    required this.label,
    required this.sublabel,
    this.badge,
    this.badgeColor,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.bgColor,
    required this.valueColor,
  });

  final String value;
  final String label;
  final String sublabel;
  final String? badge;
  final Color? badgeColor;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final Color bgColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Container(
        width: 145,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: const TextStyle(fontSize: 10, color: Colors.black54),
                maxLines: 2,
              ),
              if (badge != null) ...[
                const SizedBox(height: 4),
                Text(
                  '● $badge',
                  style: TextStyle(
                    fontSize: 9,
                    color: badgeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
