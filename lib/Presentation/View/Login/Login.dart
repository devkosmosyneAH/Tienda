// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tienda/Presentation/Services/auth_service.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:tienda/Presentation/View/Auth/app_routes.dart';
import 'package:tienda/Presentation/Widgets/Login/custom_app_bar.dart';
import 'package:tienda/Presentation/Widgets/Login/email_input.dart';
import 'package:tienda/Presentation/Widgets/Login/login_button.dart';
import 'package:tienda/Presentation/Widgets/Login/logo_image.dart';
import 'package:tienda/Presentation/Widgets/Login/password_input.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool loading = false;
  bool _obscurePassword = true;
  bool _buttonHovered = false;

  static const String _websiteUrl =
      'https://devkosmosyneah.github.io/devkosmosyne-website/';
  static const String _portfolioUrl = 'https://18-anth.github.io/CV_Anth_/';

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, complete todos los campos')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final user = await _authService.login(email, password);
      if (!mounted) return;

      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Bienvenido, ${user['email'] ?? email}!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Credenciales inválidas'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !(uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL inválida. Compruebe la configuración.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!await canLaunchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se puede abrir la URL en este dispositivo.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showAboutSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.whiteOverlay,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Wrap(
            runSpacing: 16,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.greyOverlay,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Acerca de',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              _AboutListTile(
                icon: Icons.business_center_outlined,
                title: 'Sistema de Gestión Comercial',
                subtitle: 'Aplicación desarrollada con Flutter.',
              ),
              _AboutListTile(
                icon: Icons.info_outline,
                title: 'Versión',
                subtitle: '1.0.0',
              ),
              _AboutListTile(
                icon: Icons.handshake_outlined,
                title: 'Desarrollado por',
                subtitle: 'Kosmosyne AH',
              ),
              _AboutListTile(
                icon: Icons.language,
                title: 'Sitio Web',
                subtitle: _websiteUrl,
                actionLabel: 'Abrir sitio',
                onAction: () => _openUrl(_websiteUrl),
              ),
              _AboutListTile(
                icon: Icons.work_outline,
                title: 'Portafolio',
                subtitle: _portfolioUrl,
                actionLabel: 'Ver Portafolio',
                onAction: () => _openUrl(_portfolioUrl),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
          children: [
            const LogoImage(),
            const SizedBox(height: 24),
            const Text(
              'Iniciar sesión',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryLogo,
              ),
            ),
            const SizedBox(height: 5),
          ],
        )
        .animate()
        .fadeIn(duration: 520.ms)
        .scale(
          begin: const Offset(0.96, 0.96),
          end: const Offset(1, 1),
          duration: 520.ms,
          curve: Curves.easeOut,
        );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Semantics(
          label: 'Formulario de inicio de sesión',
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.whiteOverlay,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.whiteOverlay.withValues(alpha: 0.98),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.blackOverlay.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EmailInput(controller: emailController),
                const SizedBox(height: 18),
                PasswordInput(
                  controller: passwordController,
                  obscurePassword: _obscurePassword,
                  onToggle: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                const SizedBox(height: 28),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _buttonHovered = true),
                  onExit: (_) => setState(() => _buttonHovered = false),
                  child: AnimatedPhysicalModel(
                    duration: const Duration(milliseconds: 200),
                    shape: BoxShape.rectangle,
                    elevation: _buttonHovered ? 14 : 4,
                    color: Colors.transparent,
                    shadowColor: AppColors.primaryLogo.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    child: _LoginActionButton(
                      loading: loading,
                      onPressed: login,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: _showAboutSheet,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryLogo,
                      textStyle: const TextStyle(fontSize: 14),
                    ),
                    child: const Text('Acerca de'),
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(delay: 180.ms, duration: 520.ms)
        .slideY(
          begin: 0.2,
          end: 0,
          delay: 180.ms,
          duration: 520.ms,
          curve: Curves.easeOut,
        );
  }

  Widget _buildFooter(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        const Divider(height: 1, thickness: 1),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: AppColors.whiteOverlay.withValues(alpha: 0.5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _FooterLink(
                  label: 'Términos',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.terms),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: AppColors.darkGray.withValues(alpha: 0.2),
                ),
                _FooterLink(
                  label: 'Privacidad',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.privacy),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: AppColors.darkGray.withValues(alpha: 0.2),
                ),
                _FooterLink(label: 'Acerca de', onTap: _showAboutSheet),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '© 2024. Todos los derechos reservados',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.darkGray.withValues(alpha: 0.6),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 360.ms, duration: 400.ms);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightWhite,
      appBar: const CustomLoginAppBar(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.lightWhite,
              AppColors.threeColor.withValues(alpha: 0.08),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  _buildHeader(context),
                  const SizedBox(height: 28),
                  _buildLoginCard(context),
                  const SizedBox(height: 26),
                  _buildFooter(context),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginActionButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;

  const _LoginActionButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Botón iniciar sesión',
      child: loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            )
          : LoginButton(onPressed: onPressed),
    );
  }
}

class _FooterLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _FooterLink({required this.label, required this.onTap});

  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: TextButton(
        onPressed: widget.onTap,
        style: TextButton.styleFrom(
          foregroundColor: hovering
              ? AppColors.primaryLogo
              : AppColors.darkGray,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        child: Text(widget.label),
      ),
    );
  }
}

class _AboutListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _AboutListTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: AppColors.lightWhite,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primaryLogo, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: AppColors.darkGray.withValues(alpha: 0.84),
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryLogo,
                  ),
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
