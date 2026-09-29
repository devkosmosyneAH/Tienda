import 'package:provider/provider.dart';
import 'package:tienda/Presentation/Controller/license_provider.dart';
import 'package:tienda/Presentation/Services/license_service.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:tienda/Presentation/View/Auth/app_routes.dart';
import 'package:flutter/material.dart';

class CustomLoginAppBar extends StatefulWidget implements PreferredSizeWidget {
  const CustomLoginAppBar({super.key});

  @override
  State<CustomLoginAppBar> createState() => _CustomLoginAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(56);
}

class _CustomLoginAppBarState extends State<CustomLoginAppBar> {
  LicenseProvider? _licenseProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<LicenseProvider>();
    if (identical(provider, _licenseProvider)) return;
    _licenseProvider = provider;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) provider.setDemoShownInAppBar(true, owner: this);
    });
  }

  @override
  void dispose() {
    final provider = _licenseProvider;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider?.setDemoShownInAppBar(false, owner: this);
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LicenseProvider>(
      builder: (context, provider, _) {
        final showDemo =
            provider.status == LicenseStatus.DEMO_ACTIVA ||
            provider.status == LicenseStatus.DEMO_POR_VENCER;
        return Container(
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
            title: const Text(
              'Inicio de Sesión',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xfff4f4f4),
              ),
            ),
            actions: [
              if (showDemo)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Center(
                    child: TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.license),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.teal.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        'DEMO · quedan ${provider.remainingDays} ${provider.remainingDays == 1 ? 'día' : 'días'}',
                        maxLines: 1,
                        style: const TextStyle(
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
        );
      },
    );
  }
}
