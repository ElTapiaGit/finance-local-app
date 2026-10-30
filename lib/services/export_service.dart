import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction_model.dart';

/// Servicio encargado de la generacion y exportacion de datos a formato Excel (.xlsx).
class ExportService {
  /// Elimina reportes temporales generados previamente para evitar acumulacion de archivos.
  static Future<void> _cleanOldTempReports(Directory tempDir) async {
    try {
      if (await tempDir.exists()) {
        final entities = tempDir.listSync();
        for (final entity in entities) {
          if (entity is File) {
            final fileName = entity.uri.pathSegments.isNotEmpty
                ? entity.uri.pathSegments.last
                : '';
            if (fileName.startsWith('Reporte_Financiero') ||
                fileName.startsWith('Reporte_Gastos')) {
              try {
                entity.deleteSync();
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {
      // Falla silenciosa si no se pueden limpiar los archivos temporales
    }
  }

  /// Gestiona la solicitud de permisos de almacenamiento en Android legacy.
  static Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      return true;
    }
    return true;
  }

  /// Exporta la lista de transacciones a un libro de trabajo binario de Excel (.xlsx).
  static Future<String?> exportToExcel(
    List<TransactionModel> transactions,
    String monthLabel, {
    bool share = true,
  }) async {
    // Calculo matematico previo de totales
    double totalIngresos = 0.0;
    double totalGastos = 0.0;

    for (final tx in transactions) {
      if (tx.type == TransactionType.income) {
        totalIngresos += tx.amount;
      } else {
        totalGastos += tx.amount;
      }
    }
    final double balance = totalIngresos - totalGastos;

    final excel = Excel.createExcel();
    final sheet = excel['Reporte Financiero'];
    excel.setDefaultSheet('Reporte Financiero');
    excel.delete('Sheet1');

    // Estructura ejecutiva de cabecera
    sheet.appendRow([TextCellValue("Reporte Financiero Mensual - Finance Local")]);
    sheet.appendRow([TextCellValue("Período:"), TextCellValue(monthLabel)]);
    sheet.appendRow([TextCellValue("")]); // Separador

    // Resumen Ejecutivo (KPIs)
    sheet.appendRow([TextCellValue("Resumen Ejecutivo")]);
    sheet.appendRow([TextCellValue("Total Ingresos"), DoubleCellValue(totalIngresos)]);
    sheet.appendRow([TextCellValue("Total Gastos"), DoubleCellValue(-totalGastos)]);
    sheet.appendRow([TextCellValue("Balance Neto"), DoubleCellValue(balance)]);
    sheet.appendRow([TextCellValue("")]); // Separador

    // Cabeceras de tabla detallada
    sheet.appendRow([
      TextCellValue("Fecha"),
      TextCellValue("Hora"),
      TextCellValue("Concepto"),
      TextCellValue("Categoría"),
      TextCellValue("Tipo"),
      TextCellValue("Método de Pago"),
      TextCellValue("Monto"),
    ]);

    // Filas de transacciones con fecha y hora separadas
    for (final tx in transactions) {
      final dateStr = DateFormat('dd/MM/yyyy').format(tx.date);
      final timeStr = DateFormat('HH:mm').format(tx.date);
      final typeStr = tx.type == TransactionType.expense ? "Gasto" : "Ingreso";
      final amountVal =
          tx.type == TransactionType.expense ? -tx.amount : tx.amount;

      sheet.appendRow([
        TextCellValue(dateStr),
        TextCellValue(timeStr),
        TextCellValue(tx.title),
        TextCellValue(tx.categoryName),
        TextCellValue(typeStr),
        TextCellValue(tx.paymentMethod),
        DoubleCellValue(amountVal),
      ]);
    }

    final fileBytes = excel.encode();
    if (fileBytes == null) {
      throw Exception("Error al codificar el libro de trabajo Excel.");
    }

    final String fileName =
        "Reporte_Financiero_${monthLabel.replaceAll(' ', '_')}.xlsx";

    // Limpieza de archivos temporales previos
    final tempDir = await getTemporaryDirectory();
    await _cleanOldTempReports(tempDir);

    if (share) {
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);

      await file.writeAsBytes(fileBytes);

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Reporte financiero de $monthLabel.',
      );
      return null;
    } else {
      Directory? targetDir;

      if (Platform.isAndroid) {
        final bool hasPermission = await _requestStoragePermission();
        if (!hasPermission) {
          throw Exception(
            "Permiso de almacenamiento denegado. No se puede guardar el archivo.",
          );
        }

        targetDir = Directory('/storage/emulated/0/Download');
        if (!await targetDir.exists()) {
          targetDir = await getExternalStorageDirectory();
        }
      } else {
        targetDir = await getApplicationDocumentsDirectory();
      }

      final filePath = '${targetDir!.path}/$fileName';
      final file = File(filePath);

      await file.writeAsBytes(fileBytes);

      return filePath;
    }
  }
}
