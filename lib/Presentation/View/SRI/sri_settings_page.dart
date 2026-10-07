import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tienda/Presentation/Controller/cash_controller.dart';
import 'package:tienda/Presentation/Model/sri_store_config_model.dart';
import 'package:tienda/Presentation/Services/auth_service.dart';
import 'package:tienda/Presentation/Services/sri_invoice_service.dart';
import 'package:tienda/Presentation/Services/sri_config_service.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';

class SriSettingsPage extends StatefulWidget {
  const SriSettingsPage({super.key});

  @override
  State<SriSettingsPage> createState() => _SriSettingsPageState();
}

class _SriSettingsPageState extends State<SriSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _rucController = TextEditingController();
  final _legalNameController = TextEditingController();
  final _commercialNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _establishmentController = TextEditingController();
  final _emissionPointController = TextEditingController();
  final _emissionTypeController = TextEditingController();
  final _invoiceTypeController = TextEditingController();
  final _certificatePathController = TextEditingController();
  final _certificatePasswordController = TextEditingController();

  int? _selectedStoreId;
  int? _loadedStoreId;
  int? _loadingStoreId;
  int _environment = 1;
  bool _sriEnabled = false;
  bool _autoEmit = false;
  bool _hasStoredPassword = false;
  bool _checkingAccess = true;
  bool _authorized = false;
  bool _isLoadingConfig = true;
  bool _isSaving = false;
  String? _loadError;
  List<Map<String, Object?>> _invoices = [];
  bool _isLoadingInvoices = true;
  int? _retryingInvoiceId;
  String? _invoiceLoadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePage();
    });
  }

  Future<void> _initializePage() async {
    final user = await AuthService().getCurrentUser();
    if (!mounted) return;
    final role = user?['role'] as String?;
    final authorized = const {
      'admin',
      'admin_superior',
      'administrador',
    }.contains(role);
    setState(() {
      _authorized = authorized;
      _checkingAccess = false;
    });
    if (!authorized) return;

    final controller = context.read<CashController>();
    if (controller.stores.isEmpty && !controller.isLoading) {
      await controller.initialize();
    }
  }

  @override
  void dispose() {
    _rucController.dispose();
    _legalNameController.dispose();
    _commercialNameController.dispose();
    _addressController.dispose();
    _establishmentController.dispose();
    _emissionPointController.dispose();
    _emissionTypeController.dispose();
    _invoiceTypeController.dispose();
    _certificatePathController.dispose();
    _certificatePasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig(int storeId) async {
    try {
      final config = await SriConfigService.getConfig(storeId);
      if (!mounted || _selectedStoreId != storeId) return;
      setState(() {
        _applyConfig(config);
        _loadedStoreId = storeId;
        _loadingStoreId = null;
        _isLoadingConfig = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted || _selectedStoreId != storeId) return;
      setState(() {
        _loadingStoreId = null;
        _isLoadingConfig = false;
        _loadError = 'No se pudo cargar la configuración SRI: $error';
      });
    }
  }

  Future<void> _loadInvoices(int storeId) async {
    try {
      final invoices = await SriInvoiceService.getInvoicesForStore(storeId);
      if (!mounted || _selectedStoreId != storeId) return;
      setState(() {
        _invoices = invoices;
        _isLoadingInvoices = false;
        _invoiceLoadError = null;
      });
    } catch (error) {
      if (!mounted || _selectedStoreId != storeId) return;
      setState(() {
        _isLoadingInvoices = false;
        _invoiceLoadError = 'No se pudo cargar el historial SRI: $error';
      });
    }
  }

  Future<void> _retryInvoice(int invoiceId, int storeId) async {
    setState(() => _retryingInvoiceId = invoiceId);
    try {
      final result = await SriInvoiceService.retry(
        electronicInvoiceId: invoiceId,
        storeId: storeId,
      );
      await _loadInvoices(storeId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message.isEmpty
                ? 'Estado del comprobante: ${result.status}.'
                : result.message,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo reintentar el comprobante: $error')),
      );
    } finally {
      if (mounted) setState(() => _retryingInvoiceId = null);
    }
  }

  void _applyConfig(SriStoreConfig? config) {
    _rucController.text = config?.ruc ?? '';
    _legalNameController.text = config?.razonSocial ?? '';
    _commercialNameController.text = config?.nombreComercial ?? '';
    _addressController.text = config?.direccionMatriz ?? '';
    _establishmentController.text = config?.codigoEstablecimiento ?? '';
    _emissionPointController.text = config?.puntoEmision ?? '';
    _emissionTypeController.text = config?.tipoEmision ?? '';
    _invoiceTypeController.text = config?.facturaTipo ?? '01';
    _certificatePathController.text = config?.pathP12 ?? '';
    _certificatePasswordController.clear();
    _environment = config?.ambiente ?? 1;
    _sriEnabled = config?.sriEnabled ?? false;
    _autoEmit = config?.autoEmitOnCheckout ?? false;
    _hasStoredPassword = config?.p12Password.isNotEmpty ?? false;
  }

  Future<void> _pickCertificate() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['p12', 'pfx'],
      );
      final path = result?.files.single.path;
      if (path == null || !mounted) return;
      setState(() => _certificatePathController.text = path);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo seleccionar el certificado: $error'),
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final storeId = _selectedStoreId;
    if (storeId == null) return;

    if (_sriEnabled &&
        _certificatePasswordController.text.isEmpty &&
        !_hasStoredPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa la contraseña del certificado .p12.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await SriConfigService.saveConfig(
        storeId: storeId,
        sriEnabled: _sriEnabled,
        autoEmitOnCheckout: _autoEmit,
        ambiente: _environment,
        ruc: _rucController.text,
        razonSocial: _legalNameController.text,
        nombreComercial: _commercialNameController.text,
        direccionMatriz: _addressController.text,
        codigoEstablecimiento: _establishmentController.text,
        puntoEmision: _emissionPointController.text,
        tipoEmision: _emissionTypeController.text,
        facturaTipo: _invoiceTypeController.text,
        pathP12: _certificatePathController.text,
        p12Password: _certificatePasswordController.text.isEmpty
            ? null
            : _certificatePasswordController.text,
      );
      final saved = await SriConfigService.getConfig(storeId);
      if (!mounted) return;
      setState(() {
        _hasStoredPassword = saved?.p12Password.isNotEmpty ?? false;
        _certificatePasswordController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuración SRI guardada en este local.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la configuración: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _requiredValue(String? value, String label) {
    if (!_sriEnabled) return null;
    if (value == null || value.trim().isEmpty) return 'Ingresa $label.';
    return null;
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    maxLines: maxLines,
    maxLength: maxLength,
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      counterText: '',
    ),
  );

  Widget _sectionTitle(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.blackOverlay,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.mediumGray),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _settingsCard({required Widget child}) => Card(
    color: AppColors.whiteOverlay,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: AppColors.lightSlateGrey),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    if (_checkingAccess) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_authorized) {
      return Scaffold(
        backgroundColor: AppColors.lightWhite,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),

          child: Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              gradient: LinearGradient(
                colors: [AppColors.primaryLogo, AppColors.primaryLogo],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              boxShadow: [
                BoxShadow(
                  offset: Offset(-10, 10),
                  color: AppColors.plumGray31,
                  blurRadius: 10,
                ),
                BoxShadow(
                  offset: Offset(-10, -10),
                  color: AppColors.cream59,
                  blurRadius: 10,
                ),
              ],
            ),
            child: AppBar(
              title: const Text('Facturación SRI'),
              centerTitle: true,
              backgroundColor: AppColors.lightWhite,
              foregroundColor: AppColors.blackOverlay,
              surfaceTintColor: Colors.transparent,
            ),
          ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No tienes permisos para configurar el SRI.',
              style: TextStyle(color: AppColors.mediumGray),
            ),
          ),
        ),
      );
    }

    final baseTheme = Theme.of(context);
    final sriTheme = baseTheme.copyWith(
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: AppColors.primaryBlue,
        onSurface: AppColors.blackOverlay,
        surface: AppColors.whiteOverlay,
        error: AppColors.primaryRed,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.whiteOverlay,
        labelStyle: TextStyle(color: AppColors.mediumGray),
        floatingLabelStyle: TextStyle(
          color: AppColors.primaryBlue,
          fontWeight: FontWeight.w600,
        ),
        helperStyle: TextStyle(color: AppColors.mediumGray),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: AppColors.lightSlateGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: AppColors.primaryRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: AppColors.primaryRed, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: AppColors.whiteOverlay,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );

    return Theme(
      data: sriTheme,
      child: Scaffold(
        backgroundColor: AppColors.lightGray,
        appBar: AppBar(
          title: const Text('Facturación SRI'),
          backgroundColor: AppColors.lightWhite,
          foregroundColor: AppColors.blackOverlay,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        body: Consumer<CashController>(
          builder: (context, cashController, _) {
            if (cashController.isLoading && cashController.stores.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (cashController.stores.isEmpty) {
              return const Center(
                child: Text('Crea un local antes de configurar el SRI.'),
              );
            }

            final storeIds = cashController.stores
                .map((store) => (store['id'] as num).toInt())
                .toSet();
            final storeId =
                _selectedStoreId != null && storeIds.contains(_selectedStoreId)
                ? _selectedStoreId!
                : (cashController.selectedStoreId != null &&
                          storeIds.contains(cashController.selectedStoreId)
                      ? cashController.selectedStoreId!
                      : storeIds.first);

            if (_loadedStoreId != storeId && _loadingStoreId != storeId) {
              _selectedStoreId = storeId;
              _loadingStoreId = storeId;
              _isLoadingConfig = true;
              _isLoadingInvoices = true;
              _invoiceLoadError = null;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _loadConfig(storeId);
                  _loadInvoices(storeId);
                }
              });
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final fieldWidth = constraints.maxWidth >= 850
                    ? (constraints.maxWidth - 56) / 2
                    : constraints.maxWidth;
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 920),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DropdownButtonFormField<int>(
                              value: storeId,
                              decoration: const InputDecoration(
                                labelText: 'Local',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.storefront_outlined),
                              ),
                              items: cashController.stores.map((store) {
                                final id = (store['id'] as num).toInt();
                                return DropdownMenuItem(
                                  value: id,
                                  child: Text(
                                    (store['name'] as String?) ?? 'Local $id',
                                  ),
                                );
                              }).toList(),
                              onChanged: _isSaving
                                  ? null
                                  : (value) {
                                      if (value == null) return;
                                      setState(() {
                                        _selectedStoreId = value;
                                        _loadedStoreId = null;
                                        _loadingStoreId = value;
                                        _isLoadingConfig = true;
                                        _isLoadingInvoices = true;
                                        _loadError = null;
                                        _invoiceLoadError = null;
                                      });
                                      _loadConfig(value);
                                      _loadInvoices(value);
                                    },
                            ),
                            const SizedBox(height: 20),
                            if (!SriConfigService.globalEnabled)
                              _settingsCard(
                                child: const ListTile(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  leading: Icon(
                                    Icons.info_outline,
                                    color: AppColors.primaryBlue,
                                  ),
                                  title: Text('Emisión SRI deshabilitada'),
                                  subtitle: Text(
                                    'Esta compilación tiene la emisión global desactivada. Puedes guardar los datos del local, pero no se emitirán comprobantes hasta habilitar SRI en la configuración de la aplicación.',
                                  ),
                                ),
                              ),
                            if (_isLoadingConfig)
                              const Padding(
                                padding: EdgeInsets.all(36),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_loadError != null)
                              _settingsCard(
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.error_outline,
                                    color: AppColors.primaryRed,
                                  ),
                                  title: Text(_loadError!),
                                  trailing: IconButton(
                                    tooltip: 'Reintentar',
                                    onPressed: () => _loadConfig(storeId),
                                    icon: const Icon(Icons.refresh),
                                  ),
                                ),
                              )
                            else
                              Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _settingsCard(
                                      child: SwitchListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                            ),
                                        activeTrackColor: AppColors.primaryBlue,
                                        title: const Text(
                                          'Activar SRI para este local',
                                          style: TextStyle(
                                            color: AppColors.blackOverlay,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        subtitle: const Text(
                                          'Permite generar comprobantes electrónicos para las ventas.',
                                          style: TextStyle(
                                            color: AppColors.mediumGray,
                                          ),
                                        ),
                                        value: _sriEnabled,
                                        onChanged: (value) =>
                                            setState(() => _sriEnabled = value),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    _settingsCard(
                                      child: const ListTile(
                                        leading: Icon(
                                          Icons.warning_amber_outlined,
                                          color: AppColors.primaryRed,
                                        ),
                                        title: Text(
                                          'Emisión temporalmente bloqueada',
                                        ),
                                        subtitle: Text(
                                          'La factura electrónica requiere una tarifa SRI verificada por producto. El precio del POS representa el PVP final; la base imponible e IVA se derivan de forma determinista. Las ventas se registran aunque falte una tarifa, pero no se emite XML ni se consume secuencial.',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    _sectionTitle(
                                      'Datos tributarios',
                                      'Identificación y datos del establecimiento emisor.',
                                    ),
                                    Wrap(
                                      spacing: 16,
                                      runSpacing: 16,
                                      children: [
                                        SizedBox(
                                          width: fieldWidth,
                                          child: _textField(
                                            label: 'RUC',
                                            controller: _rucController,
                                            keyboardType: TextInputType.number,
                                            maxLength: 13,
                                            validator: (value) {
                                              final required = _requiredValue(
                                                value,
                                                'el RUC',
                                              );
                                              if (required != null) {
                                                return required;
                                              }
                                              if (_sriEnabled &&
                                                  value!.trim().length != 13) {
                                                return 'El RUC debe tener 13 dígitos.';
                                              }
                                              if (_sriEnabled &&
                                                  int.tryParse(value!.trim()) ==
                                                      null) {
                                                return 'El RUC solo debe contener números.';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                        SizedBox(
                                          width: fieldWidth,
                                          child: DropdownButtonFormField<int>(
                                            value: _environment,
                                            decoration: const InputDecoration(
                                              labelText: 'Ambiente SRI',
                                              border: OutlineInputBorder(),
                                            ),
                                            items: const [
                                              DropdownMenuItem(
                                                value: 1,
                                                child: Text('Pruebas'),
                                              ),
                                              DropdownMenuItem(
                                                value: 2,
                                                child: Text('Producción'),
                                              ),
                                            ],
                                            onChanged: (value) => setState(
                                              () => _environment = value ?? 1,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: fieldWidth,
                                          child: _textField(
                                            label: 'Razón social',
                                            controller: _legalNameController,
                                            validator: (value) =>
                                                _requiredValue(
                                                  value,
                                                  'la razón social',
                                                ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: fieldWidth,
                                          child: _textField(
                                            label: 'Nombre comercial',
                                            controller:
                                                _commercialNameController,
                                          ),
                                        ),
                                        SizedBox(
                                          width: fieldWidth,
                                          child: _textField(
                                            label: 'Código de establecimiento',
                                            controller:
                                                _establishmentController,
                                            keyboardType: TextInputType.number,
                                            maxLength: 3,
                                            validator: (value) => _requiredValue(
                                              value,
                                              'el código de establecimiento',
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: fieldWidth,
                                          child: _textField(
                                            label: 'Punto de emisión',
                                            controller:
                                                _emissionPointController,
                                            keyboardType: TextInputType.number,
                                            maxLength: 3,
                                            validator: (value) =>
                                                _requiredValue(
                                                  value,
                                                  'el punto de emisión',
                                                ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: fieldWidth,
                                          child: _textField(
                                            label: 'Tipo de emisión',
                                            controller: _emissionTypeController,
                                            validator: (value) =>
                                                _requiredValue(
                                                  value,
                                                  'el tipo de emisión',
                                                ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: fieldWidth,
                                          child: _textField(
                                            label: 'Tipo de comprobante',
                                            controller: _invoiceTypeController,
                                            validator: (value) =>
                                                _requiredValue(
                                                  value,
                                                  'el tipo de comprobante',
                                                ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: constraints.maxWidth,
                                          child: _textField(
                                            label: 'Dirección matriz',
                                            controller: _addressController,
                                            maxLines: 2,
                                            validator: (value) =>
                                                _requiredValue(
                                                  value,
                                                  'la dirección matriz',
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    _sectionTitle(
                                      'Certificado electrónico',
                                      'Selecciona el archivo .p12 o .pfx y su contraseña.',
                                    ),
                                    TextFormField(
                                      controller: _certificatePathController,
                                      readOnly: true,
                                      validator: (value) => _requiredValue(
                                        value,
                                        'el certificado .p12',
                                      ),
                                      decoration: InputDecoration(
                                        labelText: 'Archivo de certificado',
                                        border: const OutlineInputBorder(),
                                        suffixIcon: IconButton(
                                          tooltip: 'Seleccionar certificado',
                                          onPressed: _pickCertificate,
                                          icon: const Icon(Icons.attach_file),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller:
                                          _certificatePasswordController,
                                      obscureText: true,
                                      decoration: InputDecoration(
                                        labelText: 'Contraseña del certificado',
                                        helperText: _hasStoredPassword
                                            ? 'Ya hay una contraseña protegida. Déjalo vacío para conservarla.'
                                            : 'Se guardará en el almacén seguro del sistema.',
                                        border: const OutlineInputBorder(),
                                        prefixIcon: const Icon(
                                          Icons.key_outlined,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _settingsCard(
                                      child: SwitchListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                            ),
                                        activeTrackColor: AppColors.primaryBlue,
                                        title: const Text(
                                          'Emitir automáticamente al cerrar una venta',
                                          style: TextStyle(
                                            color: AppColors.blackOverlay,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        value: _autoEmit,
                                        onChanged: _sriEnabled
                                            ? (value) => setState(
                                                () => _autoEmit = value,
                                              )
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: FilledButton.icon(
                                        onPressed: _isSaving ? null : _save,
                                        icon: _isSaving
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(Icons.save_outlined),
                                        label: const Text(
                                          'Guardar configuración',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 28),
                            _invoiceHistorySection(storeId),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _invoiceHistorySection(int storeId) {
    return _settingsCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Comprobantes electrónicos de este local',
                    style: TextStyle(
                      color: AppColors.blackOverlay,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Actualizar historial',
                  onPressed: _isLoadingInvoices
                      ? null
                      : () {
                          setState(() => _isLoadingInvoices = true);
                          _loadInvoices(storeId);
                        },
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (_isLoadingInvoices)
              const LinearProgressIndicator()
            else if (_invoiceLoadError != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.error_outline,
                  color: AppColors.primaryRed,
                ),
                title: Text(_invoiceLoadError!),
              )
            else if (_invoices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Este local todavía no tiene comprobantes SRI.'),
              )
            else
              ..._invoices.map((invoice) {
                final id = (invoice['id'] as num).toInt();
                final status = invoice['estado']?.toString() ?? 'DESCONOCIDO';
                final errorMessage =
                    invoice['error_message']?.toString().trim() ?? '';
                final canRetry = status == 'ERROR' || status == 'PENDIENTE';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    status == 'AUTORIZADO'
                        ? Icons.verified_outlined
                        : status == 'ERROR' || status == 'RECHAZADO'
                        ? Icons.error_outline
                        : Icons.receipt_long_outlined,
                    color: status == 'AUTORIZADO'
                        ? Colors.green
                        : status == 'ERROR' || status == 'RECHAZADO'
                        ? AppColors.primaryRed
                        : AppColors.primaryBlue,
                  ),
                  title: Text(
                    'Venta ${invoice['sale_id']} · $status',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    errorMessage.isNotEmpty
                        ? errorMessage
                        : 'Creado: ${invoice['created_at'] ?? 'sin fecha'}',
                  ),
                  trailing: canRetry
                      ? IconButton(
                          tooltip: 'Reintentar comprobante',
                          onPressed: _retryingInvoiceId == id
                              ? null
                              : () => _retryInvoice(id, storeId),
                          icon: _retryingInvoiceId == id
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh),
                        )
                      : null,
                );
              }),
          ],
        ),
      ),
    );
  }
}
