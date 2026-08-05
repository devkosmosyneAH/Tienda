import 'package:tienda/Presentation/Controller/reports_controller.dart';
import 'package:tienda/Presentation/Renders/responsive_helper.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportsController>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appBarHeight = ResponsiveHelper.getAppBarHeight(context);
    return Scaffold(
      backgroundColor:  AppColors.lightGray,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(appBarHeight),
        child: ClipRRect(
          clipBehavior: Clip.hardEdge,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(25),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.blackOverlay,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.blackOverlay, AppColors.blackOverlay],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: AppBar(
              surfaceTintColor: Colors.transparent,
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.whiteOverlay,
                  size: 30,
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: const Text(
                    'Reportes comerciales',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.whiteOverlay,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Consumer<ReportsController>(
        builder: (context, controller, _) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child:
                controller.isLoading &&
                    controller.salesByStore.isEmpty &&
                    controller.topProducts.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _MetricCard(
                            title: 'Ventas por día',
                            value: controller.salesCountToday.toString(),
                            subtitle: 'Transacciones de hoy',
                          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.15, end: 0, duration: 400.ms, curve: Curves.easeOut),
                          _MetricCard(
                            title: 'Total del día',
                            value:
                                '\$${controller.totalToday.toStringAsFixed(2)}',
                            subtitle: 'Monto facturado hoy',
                          ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.15, end: 0, delay: 100.ms, duration: 400.ms, curve: Curves.easeOut),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Card(
                        color: AppColors.whiteOverlay,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ventas por local',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (controller.salesByStore.isEmpty)
                                const Text('Aún no hay ventas registradas.')
                              else
                                ...controller.salesByStore.map(
                                  (row) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                      Icons.store_mall_directory_outlined,
                                    ),
                                    title: Text(row['name']?.toString() ?? ''),
                                    subtitle: Text(
                                      '${((row['sales_count'] as num?)?.toInt() ?? 0)} ventas',
                                    ),
                                    trailing: Text(
                                      '\$${((row['total'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        color: AppColors.whiteOverlay,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Top productos',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (controller.topProducts.isEmpty)
                                const Text('Todavía no hay productos vendidos.')
                              else
                                ...controller.topProducts.asMap().entries.map((
                                  entry,
                                ) {
                                  final index = entry.key;
                                  final row = entry.value;
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      child: Text('${index + 1}'),
                                    ),
                                    title: Text(row['name']?.toString() ?? ''),
                                    subtitle: Text(
                                      '${((row['units'] as num?)?.toInt() ?? 0)} unidades',
                                    ),
                                    trailing: Text(
                                      '\$${((row['revenue'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.whiteOverlay,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(subtitle),
        ],
      ),
    );
  }
}
