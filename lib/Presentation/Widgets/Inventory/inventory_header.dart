import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';

import 'inventory_tabs.dart';

class InventoryHeader extends StatelessWidget implements PreferredSizeWidget {
  const InventoryHeader({
    super.key,
    required this.appBarHeight,
    required this.selectedTab,
    required this.onTabChanged,
    required this.onRefresh,
    required this.onBack,
  });

  final double appBarHeight;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onRefresh;
  final VoidCallback onBack;

  @override
  Size get preferredSize => Size.fromHeight(appBarHeight + 50);

  @override
  Widget build(BuildContext context) {
    return PreferredSize(
      preferredSize: preferredSize,
      child: ClipRRect(
        clipBehavior: Clip.hardEdge,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(25),
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.blackOverlay,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 5,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: AppBar(
            surfaceTintColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: AppColors.whiteOverlay,
                size: 26,
              ),
              onPressed: onBack,
            ),
            title: const Text(
              'Gestión de Inventario',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.whiteOverlay,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.refresh,
                  color: AppColors.whiteOverlay,
                ),
                onPressed: onRefresh,
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: InventoryTabs(
                selectedTab: selectedTab,
                onTabChanged: onTabChanged,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
