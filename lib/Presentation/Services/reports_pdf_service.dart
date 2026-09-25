import 'dart:typed_data';

import 'package:tienda/Presentation/Controller/reports_controller.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ReportsPdfService {
  const ReportsPdfService();

  String buildReportFilename() {
    final now = DateTime.now();
    final yyyy = now.year.toString();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    return 'reporte_comercial_$yyyy-$mm-$dd.pdf';
  }

  Future<Uint8List> generateCommercialReport(
    ReportsController controller, {
    DateTime? generatedAt,
  }) async {
    final pdf = pw.Document();
    final generatedDate = generatedAt ?? DateTime.now();
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 16),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey300, width: 0.8),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Reporte comercial',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ),
        build: (context) {
          final summaryTable = pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: const {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(10),
                    child: pw.Text(
                      'VENTAS HOY',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(10),
                    child: pw.Text(
                      'INGRESOS HOY',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(12),
                    child: pw.Text(
                      controller.salesCountToday.toString(),
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(12),
                    child: pw.Text(
                      currencyFormat.format(controller.totalToday),
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );

          final salesByStoreRows = controller.salesByStore.isEmpty
              ? null
              : [
                  ['Local', 'Ventas', 'Total'],
                  ...controller.salesByStore.map((row) {
                    final total = (row['total'] as num?)?.toDouble() ?? 0;
                    final count = (row['sales_count'] as num?)?.toInt() ?? 0;
                    return [
                      (row['name'] ?? '').toString(),
                      count.toString(),
                      currencyFormat.format(total),
                    ];
                  }),
                ];

          final productsRows = controller.topProducts.isEmpty
              ? null
              : [
                  ['#', 'Producto', 'Unidades', 'Ingresos'],
                  ...controller.topProducts.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final row = entry.value;
                    final revenue = (row['revenue'] as num?)?.toDouble() ?? 0;
                    final units = (row['units'] as num?)?.toInt() ?? 0;
                    return [
                      index.toString(),
                      (row['name'] ?? '').toString(),
                      units.toString(),
                      currencyFormat.format(revenue),
                    ];
                  }),
                ];

          return [
            pw.Container(
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'REPORTES COMERCIALES',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Resumen del rendimiento comercial',
                    style: pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    'Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(generatedDate)}',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 22),
            if (controller.salesCountToday == 0)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Text(
                  'No hay ventas registradas para este período.',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              )
            else if (controller.salesByStore.isEmpty)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Text(
                  'No existen datos de ventas por local.',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ),
            pw.Text(
              'Resumen',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 10),
            summaryTable,
            pw.SizedBox(height: 22),
            pw.Text(
              'Ventas por local',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 10),
            if (salesByStoreRows == null)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Text(
                  'No existen datos de ventas por local.',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                context: context,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
                cellStyle: pw.TextStyle(fontSize: 9, color: PdfColors.black),
                headers: salesByStoreRows.first,
                data: salesByStoreRows.sublist(1),
                border: null,
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2.5),
                  1: const pw.FlexColumnWidth(1.1),
                  2: const pw.FlexColumnWidth(1.5),
                },
              ),
            pw.SizedBox(height: 22),
            pw.Text(
              'Top productos',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 10),
            if (productsRows == null)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Text(
                  'No hay productos vendidos para este período.',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                context: context,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
                cellStyle: pw.TextStyle(fontSize: 9, color: PdfColors.black),
                headers: productsRows.first,
                data: productsRows.sublist(1),
                border: null,
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.6),
                  1: const pw.FlexColumnWidth(2.4),
                  2: const pw.FlexColumnWidth(1.1),
                  3: const pw.FlexColumnWidth(1.2),
                },
              ),
          ];
        },
      ),
    );

    return pdf.save();
  }
}
