import 'package:tienda/Presentation/Controller/reports_controller.dart';
import 'package:tienda/Presentation/Renders/responsive_helper.dart';
import 'package:tienda/Presentation/Services/reports_pdf_service.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportsController>().initialize();
    });
  }

  Future<void> _generatePdf() async {
    if (_isGeneratingPdf) return;

    setState(() => _isGeneratingPdf = true);

    try {
      final controller = context.read<ReportsController>();
      final pdfService = const ReportsPdfService();
      final pdfBytes = await pdfService.generateCommercialReport(controller);
      final filename = pdfService.buildReportFilename();

      await Printing.sharePdf(bytes: pdfBytes, filename: filename);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo generar el reporte PDF.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  Future<void> _pickDateRange() async {
    final controller = context.read<ReportsController>();
    final initialRange = DateTimeRange(
      start: controller.selectedFromDate ?? DateTime.now(),
      end: controller.selectedToDate ?? DateTime.now(),
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      initialDateRange: initialRange,
      saveText: 'Aplicar',
    );

    if (picked == null) return;

    await controller.setDateRange(
      fromDate: picked.start,
      toDate: picked.end,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appBarHeight = ResponsiveHelper.getAppBarHeight(context);
    return Scaffold(
      backgroundColor: AppColors.lightGray,
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
              title: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reportes comerciales',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.whiteOverlay,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Resumen del rendimiento de tu negocio',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.greyOverlay,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Consumer<ReportsController>(
        builder: (context, controller, _) {
          final horizontalPadding = ResponsiveHelper.getAdaptiveMargin(
            context,
            smallMargin: 16,
            mediumMargin: 28,
            largeMargin: 40,
          );
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 22,
            ),
            child:
                controller.isLoading &&
                    controller.salesByStore.isEmpty &&
                    controller.topProducts.isEmpty
                ? const _ReportsLoading()
                : ListView(
                    children: [
                      _ReportsHeader(
                        controller: controller,
                        isGenerating: _isGeneratingPdf,
                        onGeneratePdf: _generatePdf,
                        onSelectDateRange: _pickDateRange,
                      ),
                      const SizedBox(height: 18),
                      _MetricsGrid(controller: controller),
                      const SizedBox(height: 18),
                      if (controller.errorMessage != null)
                        _ErrorBanner(message: controller.errorMessage!),
                      if (controller.errorMessage != null)
                        const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final salesCard = _SalesSummaryCard(
                            total: controller.totalToday,
                            salesCount: controller.salesCountToday,
                          );
                          final storesCard = _StoreSalesCard(
                            rows: controller.salesByStore,
                          );
                          if (constraints.maxWidth >= 850) {
                            return Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: salesCard),
                                    const SizedBox(width: 18),
                                    Expanded(child: storesCard),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                _TopProductsCard(rows: controller.topProducts),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              salesCard,
                              const SizedBox(height: 18),
                              storesCard,
                              const SizedBox(height: 18),
                              _TopProductsCard(rows: controller.topProducts),
                            ],
                          );
                        },
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
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title.toUpperCase(), style: _eyebrowStyle)),
              Icon(icon, color: AppColors.primaryBlue, size: 22),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: _mutedStyle),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final ReportsController controller;

  const _MetricsGrid({required this.controller});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 14.0;
        final columns = constraints.maxWidth >= 600 ? 2 : 1;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: width,
              child: _MetricCard(
                title: 'Ventas hoy',
                value: controller.salesCountToday.toString(),
                subtitle: 'Transacciones registradas',
                icon: Icons.shopping_bag_outlined,
              ).animate().fadeIn(duration: 400.ms).slideY(begin: .12, end: 0),
            ),
            SizedBox(
              width: width,
              child:
                  _MetricCard(
                        title: 'Ingresos',
                        value: '\$${controller.totalToday.toStringAsFixed(2)}',
                        subtitle: 'Monto facturado hoy',
                        icon: Icons.account_balance_wallet_outlined,
                      )
                      .animate()
                      .fadeIn(delay: 100.ms, duration: 400.ms)
                      .slideY(begin: .12, end: 0),
            ),
          ],
        );
      },
    );
  }
}

const _eyebrowStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: .7,
  color: AppColors.mediumGray,
);
const _mutedStyle = TextStyle(fontSize: 12, color: AppColors.mediumGray);

class _ReportCard extends StatelessWidget {
  final Widget child;

  const _ReportCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveHelper.isSmallScreen(context) ? 18.0 : 22.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppColors.whiteOverlay,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightSlateGrey.withAlpha(89)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ReportsHeader extends StatelessWidget {
  final ReportsController controller;
  final bool isGenerating;
  final VoidCallback onGeneratePdf;
  final VoidCallback onSelectDateRange;

  const _ReportsHeader({
    required this.controller,
    required this.isGenerating,
    required this.onGeneratePdf,
    required this.onSelectDateRange,
  });

  @override
  Widget build(BuildContext context) {
    final hasRange = controller.selectedFromDate != null || controller.selectedToDate != null;
    final rangeLabel = hasRange
        ? '${controller.selectedFromDate != null ? _formatDate(controller.selectedFromDate!) : 'Inicio'} - ${controller.selectedToDate != null ? _formatDate(controller.selectedToDate!) : 'Fin'}'
        : 'Hoy';

    final button = FilledButton.icon(
      onPressed: isGenerating ? null : onGeneratePdf,
      icon: isGenerating
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.picture_as_pdf_outlined),
      label: Text(isGenerating ? 'Generando reporte...' : 'Generar reporte PDF'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.blackOverlay,
        foregroundColor: AppColors.whiteOverlay,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );

    final dateButton = Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: isGenerating ? null : onSelectDateRange,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                color: Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  rangeLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.grey.shade400,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactLayout = constraints.maxWidth < 700;

        if (compactLayout) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  dateButton,
                  if (hasRange)
                    TextButton.icon(
                      onPressed: isGenerating ? null : () async {
                        await controller.clearDateRange();
                      },
                      icon: const Icon(Icons.clear),
                      label: const Text('Limpiar'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: button),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: dateButton),
            const SizedBox(width: 12),
            if (hasRange)
              TextButton.icon(
                onPressed: isGenerating ? null : () async {
                  await controller.clearDateRange();
                },
                icon: const Icon(Icons.clear),
                label: const Text('Limpiar'),
              ),
            const SizedBox(width: 12),
            button,
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeading({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 21, color: AppColors.primaryBlue),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _SalesSummaryCard extends StatelessWidget {
  final double total;
  final int salesCount;

  const _SalesSummaryCard({required this.total, required this.salesCount});

  @override
  Widget build(BuildContext context) {
    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(title: 'Ventas', icon: Icons.insights_outlined),
          const SizedBox(height: 20),
          Text(
            '\$${total.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text('$salesCount transacciones hoy', style: _mutedStyle),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.lightWhite,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.bar_chart_outlined, color: AppColors.primaryBlue),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'El historial por periodo estará disponible cuando el controller lo proporcione.',
                    style: _mutedStyle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 450.ms);
  }
}

class _StoreSalesCard extends StatelessWidget {
  final List<Map<String, dynamic>> rows;

  const _StoreSalesCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final maxTotal = rows.fold<double>(0, (max, row) {
      final total = (row['total'] as num?)?.toDouble() ?? 0;
      return total > max ? total : max;
    });
    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            title: 'Ventas por local',
            icon: Icons.store_outlined,
          ),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            const _EmptyReportState(
              icon: Icons.store_mall_directory_outlined,
              message: 'Aún no hay ventas registradas.',
            )
          else
            ...rows.asMap().entries.map(
              (entry) => _StoreSalesItem(
                row: entry.value,
                maxTotal: maxTotal,
                isLast: entry.key == rows.length - 1,
              ),
            ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 450.ms);
  }
}

class _StoreSalesItem extends StatelessWidget {
  final Map<String, dynamic> row;
  final double maxTotal;
  final bool isLast;

  const _StoreSalesItem({
    required this.row,
    required this.maxTotal,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final total = (row['total'] as num?)?.toDouble() ?? 0;
    final count = (row['sales_count'] as num?)?.toInt() ?? 0;
    final progress = maxTotal == 0 ? 0.0 : (total / maxTotal).clamp(0.0, 1.0);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row['name']?.toString() ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text('$count ventas', style: _mutedStyle),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AppColors.lightSlateGrey.withAlpha(89),
              valueColor: const AlwaysStoppedAnimation(AppColors.primaryBlue),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopProductsCard extends StatelessWidget {
  final List<Map<String, dynamic>> rows;

  const _TopProductsCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            title: 'Top productos',
            icon: Icons.inventory_2_outlined,
          ),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            const _EmptyReportState(
              icon: Icons.inventory_2_outlined,
              message: 'Todavía no hay productos vendidos.',
            )
          else
            ...rows.asMap().entries.map(
              (entry) => _TopProductItem(index: entry.key, row: entry.value),
            ),
        ],
      ),
    ).animate().fadeIn(delay: 180.ms, duration: 450.ms);
  }
}

class _TopProductItem extends StatelessWidget {
  final int index;
  final Map<String, dynamic> row;

  const _TopProductItem({required this.index, required this.row});

  @override
  Widget build(BuildContext context) {
    final units = (row['units'] as num?)?.toInt() ?? 0;
    final revenue = (row['revenue'] as num?)?.toDouble() ?? 0;
    final highlighted = index < 3;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 19,
        backgroundColor: highlighted
            ? AppColors.lightBlue
            : AppColors.lightWhite,
        child: highlighted
            ? const Icon(
                Icons.emoji_events_outlined,
                size: 20,
                color: AppColors.primaryBlue,
              )
            : Text(
                '${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
      ),
      title: Text(
        row['name']?.toString() ?? '',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('$units unidades', style: _mutedStyle),
      trailing: Text(
        '\$${revenue.toStringAsFixed(2)}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyReportState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyReportState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.lightWhite,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: AppColors.greyOverlay),
          const SizedBox(height: 9),
          Text(message, textAlign: TextAlign.center, style: _mutedStyle),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightRed.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.primaryRed),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.darkGray),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportsLoading extends StatelessWidget {
  const _ReportsLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Ventas por local',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        ...List.generate(
          4,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              height: index < 2 ? 128 : 210,
              decoration: BoxDecoration(
                color: AppColors.whiteOverlay,
                borderRadius: BorderRadius.circular(20),
              ),
            ).animate().fadeIn(delay: (index * 80).ms, duration: 350.ms),
          ),
        ),
      ],
    );
  }
}
