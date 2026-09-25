import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:tienda/Presentation/Widgets/Products/shared_inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomerFormFields extends StatelessWidget {
  const CustomerFormFields({
    super.key,
    required this.nameController,
    required this.lastNameController,
    required this.phoneController,
    required this.emailController,
    required this.idController,
    required this.addressController,
    required this.referencesController,
    required this.uuidController,
    required this.notesController,
  });

  final TextEditingController nameController;
  final TextEditingController lastNameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController idController;
  final TextEditingController addressController;
  final TextEditingController referencesController;
  final TextEditingController uuidController;
  final TextEditingController notesController;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 500;
        final width = twoColumns
            ? (constraints.maxWidth - 14) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: width,
              child: SharedTextFormField(
                controller: nameController,
                label: 'Nombre completo',
                prefixIcon: const Icon(Icons.person_outline),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ingresa el nombre'
                    : null,
              ),
            ),
            SizedBox(
              width: width,
              child: SharedTextField(
                controller: lastNameController,
                label: 'Apellidos',
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            SizedBox(
              width: width,
              child: SharedTextField(
                controller: phoneController,
                label: 'Teléfono',
                prefixIcon: const Icon(Icons.phone_outlined),
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            SizedBox(
              width: width,
              child: SharedTextFormField(
                controller: emailController,
                label: 'Correo electrónico',
                prefixIcon: const Icon(Icons.email_outlined),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return null;
                  final isValid = RegExp(
                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                  ).hasMatch(email);
                  return isValid ? null : 'Ingresa un correo válido';
                },
              ),
            ),
            SizedBox(
              width: width,
              child: SharedTextField(
                controller: idController,
                label: 'Cédula',
                prefixIcon: const Icon(Icons.badge_outlined),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            SizedBox(
              width: width,
              child: SharedTextField(
                controller: addressController,
                label: 'Dirección',
                prefixIcon: const Icon(Icons.location_on_outlined),
              ),
            ),
            SizedBox(
              width: width,
              child: SharedTextField(
                controller: referencesController,
                label: 'Referencias',
                prefixIcon: const Icon(Icons.bookmark_border),
              ),
            ),
            SizedBox(
              width: width,
              child: SharedTextField(
                controller: uuidController,
                label: 'Código (UUID)',
                helperText: 'Generado automáticamente · Solo lectura',
                prefixIcon: const Icon(Icons.fingerprint),
                suffixIcon: const Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: AppColors.mediumGray,
                ),
                readOnly: true,
              ),
            ),
            SizedBox(
              width: twoColumns ? constraints.maxWidth : width,
              child: SharedTextField(
                controller: notesController,
                label: 'Notas',
                maxLines: 2,
                alignLabelWithHint: true,
                prefixIcon: const Icon(Icons.description_outlined),
              ),
            ),
          ],
        );
      },
    );
  }
}
