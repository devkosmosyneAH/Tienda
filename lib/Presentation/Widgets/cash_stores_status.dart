import 'package:tienda/Presentation/Controller/cash_controller.dart';
import 'package:flutter/material.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';

class CashStoresStatus extends StatelessWidget {
  const CashStoresStatus({
    required this.controller,
    required this.isMobile,
    super.key,
  });

  final CashController controller;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    if (controller.stores.isEmpty) {
      return const Text(
        'Cajas',
        style: TextStyle(
          color: AppColors.cream,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: controller.stores.map((store) {
        final storeId = (store['id'] as num).toInt();
        final isOpen = controller.isStoreOpen(storeId);
        final color = isOpen ? AppColors.plumGray : AppColors.dustyRose;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOpen ? Icons.check_circle : Icons.lock,
              color: color,
              size: isMobile ? 14 : 13,
            ),
            const SizedBox(width: 4),
            Text(
              '${store['name']}: ${isOpen ? 'Abierta' : 'Cerrada'}',
              style: TextStyle(
                color: color,
                fontSize: isMobile ? 9 : 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
