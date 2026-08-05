import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'hover_card.dart';
import 'shared_inputs.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    required this.item,
    required this.index,
    required this.onEdit,
    super.key,
  });

  final Map<String, dynamic> item;
  final int index;
  final VoidCallback onEdit;

  Widget _buildStockBadge(int stock) {
    final Color badgeColor;
    final String emoji;
    if (stock <= 5) {
      badgeColor = const Color(0xFFFFE5E5);
      emoji = '🔴';
    } else if (stock <= 20) {
      badgeColor = const Color(0xFFFFF8E1);
      emoji = '🟡';
    } else {
      badgeColor = const Color(0xFFE8F5E9);
      emoji = '🟢';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$emoji $stock uds.',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstImage =
        item['images'] != null && (item['images'] as String).isNotEmpty
            ? (item['images'] as String).split(',').first
            : null;
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final totalStock = (item['total_stock'] as num?)?.toInt() ?? 0;
    final category = item['category']?.toString() ?? '';
    final sku = item['sku']?.toString() ?? '';

    return HoverCard(
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
            ),
            child: SizedBox(
              height: 160,
              width: double.infinity,
              child: firstImage != null
                  ? imagePreview(
                      firstImage,
                      width: double.infinity,
                      height: 160,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => imagePlaceholder(),
                    )
                  : imagePlaceholder(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name']?.toString() ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                if (category.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lightWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      '📦 $category',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  '\$${price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue,
                    letterSpacing: -0.3,
                  ),
                ),
                if (sku.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'SKU: $sku',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                _buildStockBadge(totalStock),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryBlue,
                      side: BorderSide(
                        color: AppColors.primaryBlue.withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: onEdit,
                    child: const Text(
                      'Editar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 40 * (index % 20)),
          duration: 300.ms,
        )
        .slideY(
          begin: 0.12,
          end: 0,
          delay: Duration(milliseconds: 40 * (index % 20)),
          duration: 300.ms,
          curve: Curves.easeOut,
        );
  }
}
