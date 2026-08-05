import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';

class EmailInput extends StatelessWidget {
  final TextEditingController controller;

  const EmailInput({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Correo electrónico:",
          style: TextStyle(
            color: AppColors.primaryLogo,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.email, color: AppColors.accentColor),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primaryLogo),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primaryLogo, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
