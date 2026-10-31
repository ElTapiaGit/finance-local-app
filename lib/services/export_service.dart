import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
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

  /// Gestiona la verificacion y solicitud de permisos de almacenamiento en Android.
  static Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      // En Android 13+ (API 33+), el permiso de almacenamiento clasico READ/WRITE_EXTERNAL_STORAGE
      // ya no aplica para documentos genericos y se utiliza Scoped Storage.
      if (sdkInt >= 33) {
        return true;
      }

      // En Android 12 y versiones anteriores (API <= 32), se solicita permiso si no esta otorgado
      final status = await Permission.storage.status;
      if (status.isGranted) {
        return true;
      }
      final result = await Permission.storage.request();
      return result.isGranted;
    } catch (_) {
      return true;
    }
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

        // 1. Intento primario: ruta publica /storage/emulated/0/Download
        // Valido para Android 9 o inferior, o Android 10 con legacy storage.
        if (hasPermission) {
          try {
            final publicDownloadDir = Directory('/storage/emulated/0/Download');
            if (await publicDownloadDir.exists()) {
              final publicFilePath = '${publicDownloadDir.path}/$fileName';
              final publicFile = File(publicFilePath);
              await publicFile.writeAsBytes(fileBytes);
              return publicFilePath;
            }
          } on FileSystemException {
            // Scoped Storage en Android 10+ bloquea la escritura directa POSIX
            // en /storage/emulated/0/Download. Se captura la excepcion y se continua
            // de inmediato al almacenamiento seguro de la aplicacion.
          } catch (_) {
            // Continuar al almacenamiento seguro ante cualquier otro error de acceso
          }
        }

        // 2. Fallback compatible con Scoped Storage (Android 10, 11, 12, 13, 14, 15):
        // Se utiliza el directorio externo de Descargas propio de la aplicacion
        // (context.getExternalFilesDirs(Environment.DIRECTORY_DOWNLOADS)).
        // No requiere permisos de almacenamiento y garantiza escritura en cualquier version de Android.
        try {
          final extDirs =
              await getExternalStorageDirectories(type: StorageDirectory.downloads);
          if (extDirs != null && extDirs.isNotEmpty) {
            targetDir = extDirs.first;
          }
        } catch (_) {}

        targetDir ??= await getExternalStorageDirectory();
        targetDir ??= await getApplicationDocumentsDirectory();
      } else {
        targetDir = await getApplicationDocumentsDirectory();
      }

      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final filePath = '${targetDir.path}/$fileName';
      final file = File(filePath);

      await file.writeAsBytes(fileBytes);

      return filePath;
    }
  }
}
