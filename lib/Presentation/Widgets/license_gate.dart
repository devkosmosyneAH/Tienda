import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tienda/Presentation/Controller/license_provider.dart';
import 'package:tienda/Presentation/Services/license_service.dart';
import 'package:tienda/Presentation/View/License/license_status_page.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';

class LicenseGate extends StatelessWidget {
  const LicenseGate({
    required this.child,
    required this.onStatusTap,
    super.key,
  });

  final Widget child;
  final VoidCallback onStatusTap;

  @override
  Widget build(BuildContext context) {
    return Consumer<LicenseProvider>(
      builder: (context, provider, _) {
        if (provider.loading) return child;
        final status = provider.status;
        if (provider.snapshot?.isBlocked ?? true) {
          return Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => const LicenseStatusPage(locked: true),
            ),
          );
        }

        if (status == LicenseStatus.DEMO_ACTIVA ||
            status == LicenseStatus.DEMO_POR_VENCER) {
          if (provider.demoShownInAppBar) return child;
          final color = status == LicenseStatus.DEMO_POR_VENCER
              ? AppColors.dustyRose
              : AppColors.mutedMauve;
          final days = provider.remainingDays;
          return Column(
            children: [
              Material(
                color: color,
                child: SizedBox(
                  height: 30,
                  width: double.infinity,
                  child: InkWell(
                    onTap: onStatusTap,
                    child: Center(
                      child: Text(
                        'DEMO · quedan $days ${days == 1 ? 'día' : 'días'}',
                        style: const TextStyle(
                          color: AppColors.cream,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(child: child),
            ],
          );
        }
        return child;
      },
    );
  }
}
