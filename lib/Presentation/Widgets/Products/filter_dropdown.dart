import 'package:flutter/material.dart';
import 'shared_inputs.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';

class FilterDropdown<T> extends StatelessWidget {
  const FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    super.key,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonFormField<T>(
        elevation: 5,
        isExpanded: true,
        value: value,
        style: const TextStyle(fontSize: 15, color: AppColors.plumGray87),
        dropdownColor: AppColors.cream,
        decoration: filterFieldDecoration(hint: label),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppColors.mediumGray,
          size: 22,
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}
