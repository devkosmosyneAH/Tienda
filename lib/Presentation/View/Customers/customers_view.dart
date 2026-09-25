import 'dart:math';

import 'package:tienda/Presentation/Controller/customers_controller.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:tienda/Presentation/View/Customers/customer_details_dialog.dart';
import 'package:tienda/Presentation/View/Customers/customer_background.dart';
import 'package:tienda/Presentation/View/Customers/customer_form_fields.dart';
import 'package:tienda/Presentation/View/Customers/customer_table.dart';
import 'package:tienda/Presentation/Widgets/Products/shared_inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

String _generateCustomerUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
  final value = hex.join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
      '${value.substring(12, 16)}-${value.substring(16, 20)}-'
      '${value.substring(20)}';
}

class CustomersView extends StatefulWidget {
  const CustomersView({super.key});

  @override
  State<CustomersView> createState() => _CustomersViewState();
}

class _CustomersViewState extends State<CustomersView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _idController = TextEditingController();
  final _addressController = TextEditingController();
  final _referencesController = TextEditingController();
  final _uuidController = TextEditingController(text: _generateCustomerUuid());
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();
  bool _isReadyForNextCustomer = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomersController>().initialize();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _idController.dispose();
    _addressController.dispose();
    _referencesController.dispose();
    _uuidController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = context.read<CustomersController>();
    try {
      if (_isReadyForNextCustomer) {
        _uuidController.text = _generateCustomerUuid();
        _isReadyForNextCustomer = false;
      }

      await controller.createCustomer(
        name: _nameController.text,
        uid: _uuidController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        notes: _notesController.text,
        apellidos: _lastNameController.text,
        cedula: _idController.text,
        address: _addressController.text,
        referencias: _referencesController.text,
      );

      _nameController.clear();
      _lastNameController.clear();
      _phoneController.clear();
      _emailController.clear();
      _idController.clear();
      _addressController.clear();
      _referencesController.clear();
      _notesController.clear();
      _isReadyForNextCustomer = true;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente registrado correctamente')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _resetCustomerForm() {
    _nameController.clear();
    _lastNameController.clear();
    _phoneController.clear();
    _emailController.clear();
    _idController.clear();
    _addressController.clear();
    _referencesController.clear();
    _uuidController.text = _generateCustomerUuid();
    _notesController.clear();
    _isReadyForNextCustomer = false;
  }

  void _showCustomerDialog() {
    _resetCustomerForm();
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.lightGray,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.lightWhite,
                        child: Icon(
                          Icons.person_add_alt_1,
                          color: AppColors.primaryLogo,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nuevo cliente',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryLogo,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text('Agrega la información del cliente'),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  CustomerFormFields(
                    nameController: _nameController,
                    lastNameController: _lastNameController,
                    phoneController: _phoneController,
                    emailController: _emailController,
                    idController: _idController,
                    addressController: _addressController,
                    referencesController: _referencesController,
                    uuidController: _uuidController,
                    notesController: _notesController,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _saveCustomer,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: AppColors.whiteOverlay,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Guardar cliente'),
                    ),
                  ),
                  Visibility(
                    visible: false,
                    child: LayoutBuilder(
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
                                controller: _nameController,
                                label: 'Nombre completo',
                                prefixIcon: const Icon(Icons.person_outline),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Ingresa el nombre'
                                    : null,
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: SharedTextField(
                                controller: _lastNameController,
                                label: 'Apellidos',
                                prefixIcon: const Icon(Icons.person_outline),
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: SharedTextField(
                                controller: _phoneController,
                                label: 'Teléfono',
                                prefixIcon: const Icon(Icons.phone_outlined),
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: SharedTextFormField(
                                controller: _emailController,
                                label: 'Correo electrónico',
                                prefixIcon: const Icon(Icons.email_outlined),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  final email = value?.trim() ?? '';
                                  if (email.isEmpty) return null;
                                  return RegExp(
                                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                      ).hasMatch(email)
                                      ? null
                                      : 'Ingresa un correo válido';
                                },
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: SharedTextField(
                                controller: _idController,
                                label: 'Cédula',
                                prefixIcon: const Icon(Icons.badge_outlined),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: SharedTextField(
                                controller: _addressController,
                                label: 'Dirección',
                                prefixIcon: const Icon(
                                  Icons.location_on_outlined,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: SharedTextField(
                                controller: _referencesController,
                                label: 'Referencias',
                                prefixIcon: const Icon(Icons.bookmark_border),
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: SharedTextField(
                                controller: _uuidController,
                                label: 'Código (UUID)',
                                helperText:
                                    'Generado automáticamente · Solo lectura',
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
                                controller: _notesController,
                                label: 'Notas',
                                maxLines: 2,
                                alignLabelWithHint: true,
                                prefixIcon: const Icon(
                                  Icons.description_outlined,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCustomerDetails(Map<String, dynamic> customer) {
    showDialog<void>(
      context: context,
      builder: (_) => CustomerDetailsDialog(customer: customer),
    );
  }

  void _showEditCustomerDialog(Map<String, dynamic> customer) {
    final id = (customer['id'] as num).toInt();
    _nameController.text = customer['name']?.toString() ?? '';
    _lastNameController.text = customer['apellidos']?.toString() ?? '';
    _phoneController.text = customer['phone']?.toString() ?? '';
    _emailController.text = customer['email']?.toString() ?? '';
    _idController.text = customer['cedula']?.toString() ?? '';
    _addressController.text = customer['address']?.toString() ?? '';
    _referencesController.text = customer['referencias']?.toString() ?? '';
    _uuidController.text = customer['uid']?.toString() ?? '';
    _notesController.text = customer['notes']?.toString() ?? '';

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.lightGray,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Editar cliente',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _editField(
                    _nameController,
                    'Nombre completo',
                    Icons.person_outline,
                    true,
                  ),
                  _editField(
                    _lastNameController,
                    'Apellidos',
                    Icons.person_outline,
                    false,
                  ),
                  _editField(
                    _phoneController,
                    'Teléfono',
                    Icons.phone_outlined,
                    false,
                    true,
                  ),
                  _editEmailField(),
                  _editField(
                    _idController,
                    'Cédula',
                    Icons.badge_outlined,
                    false,
                    true,
                  ),
                  _editField(
                    _addressController,
                    'Dirección',
                    Icons.location_on_outlined,
                    false,
                  ),
                  _editField(
                    _referencesController,
                    'Referencias',
                    Icons.bookmark_border,
                    false,
                  ),
                  _editField(
                    _uuidController,
                    'Código (UUID)',
                    Icons.fingerprint,
                    false,
                    false,
                    true,
                  ),
                  SizedBox(
                    width: 620,
                    child: SharedTextField(
                      controller: _notesController,
                      label: 'Notas',
                      maxLines: 2,
                      prefixIcon: const Icon(Icons.description_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.primaryRed),
            ),
          ),
          FilledButton.icon(
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;
              await context.read<CustomersController>().updateCustomer(
                id: id,
                name: _nameController.text,
                uid: _uuidController.text,
                phone: _phoneController.text,
                email: _emailController.text,
                notes: _notesController.text,
                apellidos: _lastNameController.text,
                cedula: _idController.text,
                address: _addressController.text,
                referencias: _referencesController.text,
              );
              if (mounted) Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.blackOverlay,
              foregroundColor: AppColors.whiteOverlay,
            ),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _editField(
    TextEditingController controller,
    String label,
    IconData icon,
    bool required, [
    bool digitsOnly = false,
    bool readOnly = false,
  ]) {
    return SizedBox(
      width: 290,
      child: required
          ? SharedTextFormField(
              controller: controller,
              label: label,
              prefixIcon: Icon(icon),
              readOnly: readOnly,
              inputFormatters: digitsOnly
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : null,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Ingresa el nombre'
                  : null,
            )
          : SharedTextField(
              controller: controller,
              label: label,
              prefixIcon: Icon(icon),
              readOnly: readOnly,
              inputFormatters: digitsOnly
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : null,
            ),
    );
  }

  Widget _editEmailField() {
    return SizedBox(
      width: 290,
      child: SharedTextFormField(
        controller: _emailController,
        label: 'Correo electrónico',
        prefixIcon: const Icon(Icons.email_outlined),
        validator: (value) {
          final email = value?.trim() ?? '';
          if (email.isEmpty) return null;
          final isValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
          return isValid ? null : 'Ingresa un correo válido';
        },
      ),
    );
  }

  Future<void> _confirmDeleteCustomer(Map<String, dynamic> customer) async {
    final customerName = customer['name']?.toString().trim().isNotEmpty == true
        ? customer['name'].toString()
        : 'este cliente';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 12),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icono
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withValues(alpha: 10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 32,
                    color: AppColors.primaryRed,
                  ),
                ),

                const SizedBox(height: 20),

                // Título
                const Text(
                  'Eliminar cliente',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blackOverlay,
                  ),
                ),

                const SizedBox(height: 10),

                // Mensaje
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.black54,
                    ),
                    children: [
                      const TextSpan(
                        text: '¿Estás seguro de que deseas eliminar a ',
                      ),
                      TextSpan(
                        text: customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.blackOverlay,
                        ),
                      ),
                      const TextSpan(
                        text:
                            '? Esta acción es permanente y no se puede deshacer.',
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Botones
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop(false);
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.blackOverlay,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(dialogContext).pop(true);
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 19,
                        ),
                        label: const Text(
                          'Eliminar',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await context.read<CustomersController>().deleteCustomer(
      (customer['id'] as num).toInt(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        backgroundColor: AppColors.primaryLogo,
        foregroundColor: AppColors.whiteOverlay,
        title: const Text('Clientes'),
      ),
      body: Consumer<CustomersController>(
        builder: (context, controller, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              const CustomerBackground(),
              Column(
                children: [
                  /// TAB 1
                  SizedBox(
                    height: 0,
                    child: Visibility(
                      visible: false,
                      maintainState: false,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 28, 16, 32),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 580),
                            child: SizedBox(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  28,
                                  24,
                                  24,
                                ),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Center(
                                        child: Column(
                                          children: [
                                            SizedBox(
                                              width: 88,
                                              height: 88,
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  CircleAvatar(
                                                    radius: 42,
                                                    backgroundColor:
                                                        AppColors.whiteOverlay,
                                                    child: Icon(
                                                      Icons.person_outline,
                                                      size: 48,
                                                      color:
                                                          AppColors.primaryLogo,
                                                    ),
                                                  ),
                                                  Positioned(
                                                    right: 0,
                                                    bottom: 3,
                                                    child: Container(
                                                      width: 28,
                                                      height: 28,
                                                      decoration: BoxDecoration(
                                                        color: AppColors
                                                            .primaryLogo,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: AppColors
                                                              .whiteOverlay,
                                                          width: 3,
                                                        ),
                                                      ),
                                                      child: const Icon(
                                                        Icons.add,
                                                        size: 17,
                                                        color: AppColors
                                                            .whiteOverlay,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            const Text(
                                              'Registrar cliente',
                                              style: TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primaryLogo,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Agrega un nuevo cliente a tu sistema',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: AppColors.mediumGray,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 28),
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          final isTwoColumns =
                                              constraints.maxWidth >= 520;
                                          final fieldWidth = isTwoColumns
                                              ? (constraints.maxWidth - 14) / 2
                                              : constraints.maxWidth;

                                          return Wrap(
                                            spacing: 14,
                                            runSpacing: 14,
                                            children: [
                                              SizedBox(
                                                width: fieldWidth,
                                                child: SharedTextFormField(
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    color: Colors.black87,
                                                  ),
                                                  controller: _nameController,
                                                  label: 'Nombre completo',
                                                  prefixIcon: const Icon(
                                                    Icons.person_outline,
                                                  ),
                                                  validator: (value) =>
                                                      value == null ||
                                                          value.trim().isEmpty
                                                      ? 'Ingresa el nombre'
                                                      : null,
                                                ),
                                              ),
                                              SizedBox(
                                                width: fieldWidth,
                                                child: SharedTextField(
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    color: Colors.black87,
                                                  ),
                                                  controller:
                                                      _lastNameController,
                                                  label: 'Apellidos',
                                                  prefixIcon: const Icon(
                                                    Icons.person_outline,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: fieldWidth,
                                                child: SharedTextField(
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    color: Colors.black87,
                                                  ),
                                                  controller: _phoneController,
                                                  label: 'Teléfono',
                                                  prefixIcon: const Icon(
                                                    Icons.phone_outlined,
                                                  ),
                                                  keyboardType:
                                                      TextInputType.phone,
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter
                                                        .digitsOnly,
                                                  ],
                                                ),
                                              ),
                                              SizedBox(
                                                width: fieldWidth,
                                                child: SharedTextFormField(
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    color: Colors.black87,
                                                  ),
                                                  controller: _emailController,
                                                  label: 'Correo',
                                                  prefixIcon: const Icon(
                                                    Icons.email_outlined,
                                                  ),
                                                  keyboardType: TextInputType
                                                      .emailAddress,
                                                  validator: (value) {
                                                    final email =
                                                        value?.trim() ?? '';
                                                    if (email.isEmpty) {
                                                      return null;
                                                    }
                                                    final isValid = RegExp(
                                                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                                    ).hasMatch(email);
                                                    return isValid
                                                        ? null
                                                        : 'Ingresa un correo válido';
                                                  },
                                                ),
                                              ),
                                              SizedBox(
                                                width: fieldWidth,
                                                child: SharedTextField(
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    color: Colors.black87,
                                                  ),
                                                  controller: _idController,
                                                  label: 'Cédula',
                                                  prefixIcon: const Icon(
                                                    Icons.badge_outlined,
                                                  ),
                                                  keyboardType:
                                                      TextInputType.number,
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter
                                                        .digitsOnly,
                                                  ],
                                                ),
                                              ),
                                              SizedBox(
                                                width: fieldWidth,
                                                child: SharedTextField(
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    color: Colors.black87,
                                                  ),
                                                  controller:
                                                      _addressController,
                                                  label: 'Dirección',
                                                  prefixIcon: const Icon(
                                                    Icons.location_on_outlined,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: fieldWidth,
                                                child: SharedTextField(
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    color: Colors.black87,
                                                  ),
                                                  controller:
                                                      _referencesController,
                                                  label: 'Referencias',
                                                  prefixIcon: const Icon(
                                                    Icons.bookmark_border,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: fieldWidth,
                                                child: SharedTextField(
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: AppColors.mediumGray,
                                                  ),
                                                  controller: _uuidController,
                                                  label: 'Código (UUID)',
                                                  hint:
                                                      'Se genera automáticamente',
                                                  helperText:
                                                      'Generado automáticamente · Solo lectura',
                                                  prefixIcon: const Icon(
                                                    Icons.fingerprint,
                                                  ),
                                                  suffixIcon: const Icon(
                                                    Icons.lock_outline,
                                                    size: 18,
                                                    color: AppColors.mediumGray,
                                                  ),
                                                  readOnly: true,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 24),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 52,
                                        child: FilledButton.icon(
                                          onPressed: _saveCustomer,
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Colors.black,
                                            foregroundColor:
                                                AppColors.whiteOverlay,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.person_add_alt_1,
                                          ),
                                          label: const Text('Guardar cliente'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  /// TAB 2
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 900;

                        final listPanel = Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              SizedBox(height: 5),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'Lista de Clientes',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryLogo,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        if (controller.customers.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 9,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.blackOverlay,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              controller.customers.isEmpty
                                                  ? 'Sin Clientes'
                                                  : '${controller.customers.length} ${controller.customers.length == 1 ? 'Cliente' : 'Clientes'}',

                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.whiteOverlay,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SharedTextField(
                                            style: const TextStyle(
                                              fontSize: 15,
                                              color: Colors.black87,
                                            ),
                                            controller: _searchController,
                                            hint:
                                                'Buscar cliente por nombre, correo o teléfono',
                                            prefixIcon: const Icon(
                                              Icons.search,
                                            ),
                                            suffixIcon:
                                                _searchController.text.isEmpty
                                                ? null
                                                : IconButton(
                                                    onPressed: () {
                                                      _searchController.clear();
                                                      controller
                                                          .loadCustomers();
                                                      setState(() {});
                                                    },
                                                    icon: const Icon(
                                                      Icons.clear,
                                                    ),
                                                  ),
                                            useFilterStyle: true,
                                            onChanged: (value) {
                                              setState(() {});
                                              controller.loadCustomers(
                                                searchValue: value,
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        FilledButton.icon(
                                          onPressed: _showCustomerDialog,
                                          icon: const Icon(
                                            Icons.person_add_alt_1,
                                            size: 18,
                                          ),
                                          label: const Text('Nuevo'),
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                AppColors.primaryBlue,
                                            foregroundColor:
                                                AppColors.whiteOverlay,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 10),

                              Expanded(
                                child:
                                    controller.isLoading &&
                                        controller.customers.isEmpty
                                    ? const Center(
                                        child: Icon(
                                          Icons.hourglass_top_rounded,
                                          color: AppColors.mediumGray,
                                          size: 28,
                                        ),
                                      )
                                    : CustomerTable(
                                        customers: controller.customers,
                                        selectedCustomer:
                                            controller.selectedCustomer,
                                        onCustomerTap: (customer) {
                                          controller.selectCustomer(customer);
                                          _showCustomerDetails(customer);
                                        },
                                        onEdit: _showEditCustomerDialog,
                                        onDelete: _confirmDeleteCustomer,
                                      ),
                              ),
                            ],
                          ),
                        );

                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: isWide
                              ? listPanel
                              : ListView(
                                  children: [
                                    const SizedBox(height: 16),
                                    SizedBox(height: 340, child: listPanel),
                                  ],
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
