import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';
export 'image_preview.dart';

InputDecoration modernInput({
  required String label,
  String? hint,
  String? prefix,
  String? suffix,
  Widget? prefixIcon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixText: prefix,
    suffixText: suffix,
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: AppColors.lightWhite,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
    ),
    labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
    hintStyle: TextStyle(color: Colors.grey.shade400),
  );
}

Widget formSection({required String title, required List<Widget> children}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 12),
      ...children,
    ],
  );
}

Widget imagePlaceholder() {
  return Container(
    color: AppColors.lightWhite,
    child: Center(
      child: Icon(
        Icons.inventory_2_outlined,
        size: 40,
        color: Colors.grey.shade300,
      ),
    ),
  );
}

// Shows a persistent progress-style SnackBar. Call `hideProgressNotification`
// to dismiss it when the operation completes.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
showProgressNotification(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  return messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(days: 365),
      backgroundColor: Colors.black87,
      content: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}

void hideProgressNotification(BuildContext context) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
}
