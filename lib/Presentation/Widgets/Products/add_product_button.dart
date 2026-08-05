import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';

class AddProductButton extends StatelessWidget {
  const AddProductButton({required this.onPressed, super.key});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.zero,
          minimumSize: const Size(42, 42),
        ),
        onPressed: onPressed,
        child: const Icon(Icons.add, size: 30, color: AppColors.whiteOverlay),
      ),
    );
  }
}
