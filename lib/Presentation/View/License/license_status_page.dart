import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tienda/Presentation/Controller/license_provider.dart';
import 'package:tienda/Presentation/Services/license_service.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:url_launcher/url_launcher.dart';

class LicenseStatusPage extends StatefulWidget {
  const LicenseStatusPage({this.locked = false, super.key});

  final bool locked;

  @override
  State<LicenseStatusPage> createState() => _LicenseStatusPageState();
}

class _LicenseStatusPageState extends State<LicenseStatusPage> {
  final _codeController = TextEditingController();
  String? _feedback;
  bool _feedbackIsError = false;
  LicenseProvider? _licenseProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<LicenseProvider>();
    if (identical(provider, _licenseProvider)) return;
    _licenseProvider = provider;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        provider.setDemoShownInAppBar(!widget.locked, owner: this);
      }
    });
  }

  @override
  void dispose() {
    final provider = _licenseProvider;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider?.setDemoShownInAppBar(false, owner: this);
    });
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _feedback = 'Ingresa el código de activación.';
        _feedbackIsError = true;
      });
      return;
    }
    final result = await context.read<LicenseProvider>().activate(code);
    if (!mounted) return;
    setState(() {
      _feedback = result.message;
      _feedbackIsError = !result.activated;
      if (result.activated) _codeController.clear();
    });
  }

  Future<void> _open(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _statusLabel(LicenseStatus status) => switch (status) {
    LicenseStatus.DEMO_ACTIVA => 'Período de prueba activo',
    LicenseStatus.DEMO_POR_VENCER => 'Período de prueba por vencer',
    LicenseStatus.DEMO_VENCIDA => 'Período de prueba finalizado',
    LicenseStatus.LICENCIA_ACTIVA => 'Licencia activa',
    LicenseStatus.LICENCIA_EXPIRADA => 'Licencia expirada',
    LicenseStatus.LICENCIA_REVOCADA => 'Licencia revocada',
    LicenseStatus.LICENCIA_INVALIDA => 'No se pudo validar la licencia',
  };

  Color _statusColor(LicenseStatus status) => switch (status) {
    LicenseStatus.DEMO_ACTIVA ||
    LicenseStatus.LICENCIA_ACTIVA => AppColors.blackOverlay,
    LicenseStatus.DEMO_POR_VENCER => Colors.deepOrange,
    _ => Colors.red.shade700,
  };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LicenseProvider>();
    final snapshot = provider.snapshot;
    final status = provider.status;
    final title = _statusLabel(status);
    final color = _statusColor(status);
    final isExpiredDemo = status == LicenseStatus.DEMO_VENCIDA;
    final whatsapp = Uri.https('wa.me', '/593959831092', {
      'text': 'Hola, necesito ayuda con la licencia de Tienda.',
    });

    return Scaffold(
      backgroundColor: AppColors.lightWhite,
      appBar: widget.locked
          ? null
          : PreferredSize(
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
                      color: Color.fromARGB(80, 0, 0, 0),
                      blurRadius: 10,
                    ),
                    BoxShadow(
                      offset: Offset(-10, -10),
                      color: Color.fromARGB(150, 255, 255, 255),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: AppBar(
                  leading: IconButton(
                    tooltip: 'Volver',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color(0xfff4f4f4),
                    ),
                  ),
                  title: const Text(
                    'Estado de licencia',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xfff4f4f4),
                    ),
                  ),
                  actions: [
                    if (status == LicenseStatus.DEMO_ACTIVA ||
                        status == LicenseStatus.DEMO_POR_VENCER)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'DEMO · quedan ${provider.remainingDays} ${provider.remainingDays == 1 ? 'día' : 'días'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                  automaticallyImplyLeading: false,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  centerTitle: true,
                ),
              ),
            ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                Icon(
                  widget.locked
                      ? Icons.lock_clock
                      : Icons.verified_user_outlined,
                  color: color,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  isExpiredDemo ? 'Período de prueba finalizado' : title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF202925),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isExpiredDemo
                      ? 'Los 7 días de prueba han terminado. Activa Tienda con un código de licencia para continuar usando las funciones principales.'
                      : snapshot?.message ??
                            'Consulta el estado de la licencia asociada a esta instalación.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (status == LicenseStatus.DEMO_ACTIVA ||
                    status == LicenseStatus.DEMO_POR_VENCER) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Quedan ${provider.remainingDays} ${provider.remainingDays == 1 ? 'día' : 'días'}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                ],
                const SizedBox(height: 24),
                if (snapshot != null && snapshot.installationId.isNotEmpty) ...[
                  _InfoLine(
                    label: 'Instalación',
                    value: snapshot.installationId,
                  ),
                  const SizedBox(height: 8),
                  _InfoLine(
                    label: 'Huella del equipo',
                    value: snapshot.fingerprint,
                  ),
                  const SizedBox(height: 20),
                ],
                TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Código de activación',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.key_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: provider.activating ? null : _activate,
                  icon: provider.activating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_outlined),
                  label: const Text('Activar licencia'),
                ),
                if (_feedback != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _feedback!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _feedbackIsError
                          ? Colors.red.shade700
                          : AppColors.blackOverlay,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  'Dev Kosmosyne',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 6),
                const Text('+593 95 983 1092', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _open(
                        Uri.parse(
                          'https://devkosmosyneah.github.io/devkosmosyne-website/',
                        ),
                      ),
                      icon: const Icon(Icons.language),
                      label: const Text('Sitio web'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _open(whatsapp),
                      icon: const Icon(Icons.chat_outlined),
                      label: const Text('WhatsApp'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      SelectableText(value, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
