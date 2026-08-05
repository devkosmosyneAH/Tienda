// ignore_for_file: file_names

import 'package:tienda/Presentation/View/Auth/app_routes.dart';
import 'package:tienda/Presentation/Services/auth_service.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:tienda/Presentation/Widgets/Login/custom_app_bar.dart';
import 'package:tienda/Presentation/Widgets/Login/email_input.dart';
import 'package:tienda/Presentation/Widgets/Login/login_button.dart';
import 'package:tienda/Presentation/Widgets/Login/logo_image.dart';
import 'package:tienda/Presentation/Widgets/Login/password_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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

  Future<void> login() async {
    // Validación básica
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightWhite,
      appBar: const CustomLoginAppBar(),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LogoImage()
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 500.ms, curve: Curves.easeOut),
                const SizedBox(height: 30),
                EmailInput(controller: emailController)
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 400.ms)
                    .slideY(begin: 0.2, end: 0, delay: 200.ms, duration: 400.ms, curve: Curves.easeOut),
                const SizedBox(height: 16),
                PasswordInput(
                  controller: passwordController,
                  obscurePassword: _obscurePassword,
                  onToggle: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                )
                    .animate()
                    .fadeIn(delay: 320.ms, duration: 400.ms)
                    .slideY(begin: 0.2, end: 0, delay: 320.ms, duration: 400.ms, curve: Curves.easeOut),
                const SizedBox(height: 24),
                (loading
                    ? const CircularProgressIndicator()
                    : LoginButton(onPressed: login))
                    .animate()
                    .fadeIn(delay: 440.ms, duration: 400.ms)
                    .slideY(begin: 0.2, end: 0, delay: 440.ms, duration: 400.ms, curve: Curves.easeOut),
                const SizedBox(height: 24),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
