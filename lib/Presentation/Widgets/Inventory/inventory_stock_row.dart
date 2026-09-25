import 'package:tienda/Presentation/Model/inventory_model.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';

class InventoryStockRow extends StatelessWidget {
  const InventoryStockRow({
    super.key,
    required this.item,
    required this.isZero,
    required this.isLow,
    required this.onTap,
    this.onPurchase,
    this.accentColor,
  });

  final InventoryItem item;
  final bool isZero;
  final bool isLow;
  final VoidCallback onTap;
  final void Function(InventoryItem item)? onPurchase;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = accentColor ?? (isZero ? AppColors.primaryRed : Colors.orange);
    final Color iconBg = isZero
        ? AppColors.lightRed
        : effectiveColor == AppColors.darkGreen
        ? AppColors.darkGreen.withValues(alpha: 0.2)
        : const Color(0xFFFFEDD5);
    final Color iconColor = isZero ? AppColors.primaryRed : effectiveColor;
    final progress = (item.quantity / 5).clamp(0.0, 1.0);
    final code = item.sku.isNotEmpty
        ? item.sku
        : 'Prod${item.productId.toString().padLeft(9, '0')}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.whiteOverlay,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: iconBg,
                border: Border.all(color: AppColors.blackOverlay.withValues(alpha: 0.1), width: 1.5),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isZero
                        ? Icons.cancel_outlined
                        : Icons.warning_amber_rounded,
                    color: iconColor,
                    size: 20,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.quantity.toString(),
                    style: TextStyle(
                      color: iconColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Código: $code',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Stock: ${item.quantity} / 5',
                      style: TextStyle(
                        fontSize: 11,
                        color: isZero ? AppColors.primaryRed : effectiveColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: progress,
                        backgroundColor: Colors.black12,
                        valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Material(
                color: AppColors.blackOverlay,
                borderRadius: BorderRadius.circular(13),
                child: InkWell(
                  borderRadius: BorderRadius.circular(13),
                  onTap: () => onPurchase?.call(item),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.shopping_cart_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
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
