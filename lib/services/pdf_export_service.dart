import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/transaction_model.dart';
import '../utils/currency_format.dart';

/// Servicio encargado de la generacion y maquetacion de reportes en PDF.
class PdfExportService {
  /// Genera el reporte en PDF e invoca el visualizador/impresor nativo del sistema.
  static Future<void> generateAndPrintReport(
    List<TransactionModel> transactions,
    String monthLabel, [
    DateTime? selectedMonth,
  ]) async {
    final doc = await buildPdfDocument(
      transactions: transactions,
      monthLabel: monthLabel,
      selectedMonth: selectedMonth ??
          (transactions.isNotEmpty ? transactions.first.date : DateTime.now()),
    );

    final cleanMonth = monthLabel.replaceAll(' ', '_');
    final fileName = "Reporte_Financiero_$cleanMonth.pdf";

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: fileName,
    );
  }

  /// Construye la estructura declarativa del documento PDF.
  static Future<pw.Document> buildPdfDocument({
    required List<TransactionModel> transactions,
    required String monthLabel,
    required DateTime selectedMonth,
  }) async {
    final doc = pw.Document();

    // Resolucion de tipografia compatible con caracteres UTF-8
    pw.ThemeData theme;
    try {
      final fontRegular = await PdfGoogleFonts.robotoRegular();
      final fontBold = await PdfGoogleFonts.robotoBold();
      theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);
    } catch (_) {
      theme = pw.ThemeData.base();
    }

    // Carga opcional del logotipo institucional
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/icon/logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {
      logoImage = null;
    }

    // Calculo matematico de metricas clave (KPIs)
    double totalIncome = 0.0;
    double totalExpense = 0.0;
    for (final tx in transactions) {
      if (tx.type == TransactionType.income) {
        totalIncome += tx.amount;
      } else {
        totalExpense += tx.amount;
      }
    }
    final double netBalance = totalIncome - totalExpense;

    // Transformacion de transacciones para la tabla de datos
    final tableData = transactions.map((tx) {
      final dateStr = DateFormat('dd/MM/yyyy').format(tx.date);
      final isExpense = tx.type == TransactionType.expense;
      final typeStr = isExpense ? "Gasto" : "Ingreso";
      final prefix = isExpense ? "- " : "+ ";
      final formattedAmount = "$prefix${CurrencyFormat.format(tx.amount)}";

      return [
        dateStr,
        tx.title,
        tx.categoryName,
        tx.paymentMethod,
        typeStr,
        formattedAmount,
      ];
    }).toList();

    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 16),
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "Finance Local",
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF102216),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "Reporte Financiero Mensual",
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      "Período: $monthLabel",
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                if (logoImage != null)
                  pw.Container(
                    width: 48,
                    height: 48,
                    child: pw.Image(logoImage),
                  ),
              ],
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 12),
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "Generado automáticamente por Finance Local",
                  style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
                ),
                pw.Text(
                  "Página ${context.pageNumber} de ${context.pagesCount}",
                  style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
                ),
              ],
            ),
          );
        },
        build: (context) => [
          // Resumen Ejecutivo (KPIs)
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Row(
              children: [
                _buildKpiCard(
                  title: "Total Ingresos",
                  amountStr: "+ ${CurrencyFormat.format(totalIncome)}",
                  headerColor: const PdfColor.fromInt(0xFF15803D),
                  valueColor: const PdfColor.fromInt(0xFF166534),
                  bgColor: const PdfColor.fromInt(0xFFF0FDF4),
                ),
                pw.SizedBox(width: 12),
                _buildKpiCard(
                  title: "Total Gastos",
                  amountStr: "- ${CurrencyFormat.format(totalExpense)}",
                  headerColor: const PdfColor.fromInt(0xFFB91C1C),
                  valueColor: const PdfColor.fromInt(0xFF991B1B),
                  bgColor: const PdfColor.fromInt(0xFFFEF2F2),
                ),
                pw.SizedBox(width: 12),
                _buildKpiCard(
                  title: "Balance Neto",
                  amountStr: netBalance >= 0
                      ? "+ ${CurrencyFormat.format(netBalance)}"
                      : "- ${CurrencyFormat.format(netBalance.abs())}",
                  headerColor: netBalance >= 0
                      ? const PdfColor.fromInt(0xFF15803D)
                      : const PdfColor.fromInt(0xFFB91C1C),
                  valueColor: netBalance >= 0
                      ? const PdfColor.fromInt(0xFF166534)
                      : const PdfColor.fromInt(0xFF991B1B),
                  bgColor: netBalance >= 0
                      ? const PdfColor.fromInt(0xFFF0FDF4)
                      : const PdfColor.fromInt(0xFFFEF2F2),
                ),
              ],
            ),
          ),

          // Titulo de seccion de detalle
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Text(
              "Detalle de Movimientos",
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
          ),

          // Tabla de transacciones con cebreado suave
          if (transactions.isEmpty)
            pw.Center(
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 30),
                child: pw.Text(
                  "No hay transacciones registradas para este período.",
                  style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 10),
                ),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: const [
                "Fecha",
                "Concepto",
                "Categoría",
                "Método",
                "Tipo",
                "Monto",
              ],
              data: tableData,
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF102216),
              ),
              headerPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              cellStyle: const pw.TextStyle(fontSize: 8.5, color: PdfColors.black),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF9FAFB),
              ),
              border: pw.TableBorder.all(
                color: const PdfColor.fromInt(0xFFE5E7EB),
                width: 0.5,
              ),
              headerAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.center,
                5: pw.Alignment.centerRight,
              },
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.center,
                5: pw.Alignment.centerRight,
              },
            ),
        ],
      ),
    );

    return doc;
  }

  static pw.Widget _buildKpiCard({
    required String title,
    required String amountStr,
    required PdfColor headerColor,
    required PdfColor valueColor,
    required PdfColor bgColor,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: pw.BoxDecoration(
          color: bgColor,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(color: headerColor, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: headerColor,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              amountStr,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

