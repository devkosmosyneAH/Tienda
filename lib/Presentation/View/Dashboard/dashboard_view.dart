import 'package:tienda/Presentation/Controller/dashboard_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DashboardView extends StatelessWidget {
  final DashboardController controller = DashboardController();

  DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dashboard')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Ventas del día:')
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: -0.2, end: 0, duration: 400.ms, curve: Curves.easeOut),
            // Aquí puedes agregar widgets para mostrar datos
            ElevatedButton(
              onPressed: () {
                controller.fetchSalesData();
              },
              child: const Text('Actualizar Ventas'),
            )
                .animate()
                .fadeIn(delay: 200.ms, duration: 400.ms)
                .slideY(begin: 0.2, end: 0, delay: 200.ms, duration: 400.ms, curve: Curves.easeOut),
          ],
        ),
      ),
    );
  }
}
