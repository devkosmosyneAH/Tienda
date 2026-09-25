import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:tienda/Presentation/Widgets/Products/shared_inputs.dart';
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
        SharedTextField(
          controller: controller,
          prefixIcon: Icon(Icons.email, color: AppColors.accentColor),
          keyboardType: TextInputType.emailAddress,
        ),
      ],
    );
  }
}
