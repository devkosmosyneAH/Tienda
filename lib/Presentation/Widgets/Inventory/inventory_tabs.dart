import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';

class InventoryTabs extends StatelessWidget {
  const InventoryTabs({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
  });

  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InventoryNavTab(
          icon: Icons.grid_view_rounded,
          label: 'Resumen',
          isSelected: selectedTab == 0,
          onTap: () => onTabChanged(0),
        ),
        InventoryNavTab(
          icon: Icons.search,
          label: 'Productos',
          isSelected: selectedTab == 1,
          onTap: () => onTabChanged(1),
        ),
        InventoryNavTab(
          icon: Icons.warning_amber_rounded,
          label: 'Stock Bajo',
          isSelected: selectedTab == 2,
          onTap: () => onTabChanged(2),
        ),
      ],
    );
  }
}

class InventoryNavTab extends StatelessWidget {
  const InventoryNavTab({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: isSelected
                ? const Border(
                    bottom: BorderSide(color: AppColors.whiteOverlay, width: 2),
                  )
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.whiteOverlay : Colors.white54,
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.whiteOverlay : Colors.white54,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
