import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/transaction_model.dart';
import '../utils/currency_format.dart'; 

class ExportService {
  
  static String _sanitizeText(String text) {
    return text
        .replaceAll('á', 'a').replaceAll('Á', 'A')
        .replaceAll('é', 'e').replaceAll('É', 'E')
        .replaceAll('í', 'i').replaceAll('Í', 'I')
        .replaceAll('ó', 'o').replaceAll('Ó', 'O')
        .replaceAll('ú', 'u').replaceAll('Ú', 'U')
        .replaceAll('ñ', 'n').replaceAll('Ñ', 'N');
  }

  // para permisos de almacenamiento (dispositivos < android 10)
  static Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      // Pedimos el permiso de almacenamiento
      await Permission.storage.request(); // en android 11+ la ignorara

      return true;
    }
    return true; // En iOS no solemos pedir esto para la carpeta de documentos interna
  }

  static Future<String?> exportToCSV(List<TransactionModel> transactions, String monthLabel, {bool share = true}) async {
    List<List<dynamic>> rows = [];
    
    rows.add(["Fecha", "Concepto", "Categoria", "Tipo", "Monto (${CurrencyFormat.currencySymbol})", "Metodo de Pago"]);

    for (var tx in transactions) {
      final dateStr = DateFormat('dd/MM/yyyy').format(tx.date);
      final typeStr = tx.type == TransactionType.expense ? "Gasto" : "Ingreso";
      final exportAmount = tx.type == TransactionType.expense ? -tx.amount : tx.amount;

      final cleanTitle = _sanitizeText(tx.title);
      final cleanCategory = _sanitizeText(tx.categoryName);
      final cleanPayment = _sanitizeText(tx.paymentMethod);

      rows.add([dateStr, cleanTitle, cleanCategory, typeStr, exportAmount, cleanPayment]);
    }

    String csvData = const ListToCsvConverter(
      fieldDelimiter: ';',
      textDelimiter: '"',
      textEndDelimiter: '"',
    ).convert(rows);

    // Agregamos milisegundos para que el nombre del archivo 
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = "Reporte_Gastos_${monthLabel.replaceAll(' ', '_')}_$timestamp.csv";

    if (share) {
      // NOTA: pa compartir (Share), guardamos en la carpeta temporal
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);

      await file.writeAsBytes(utf8.encode(csvData));
      
      await Share.shareXFiles([XFile(filePath)], text: 'Reporte financiero de $monthLabel.');
      return null; 
    
    } else {
      // descarga directa (considera android viejos)
      Directory? targetDir;
      
      if (Platform.isAndroid) {
        // ANTES de intentar guardar, verificamos que el usuario nos dé permiso.
        bool hasPermission = await _requestStoragePermission();

        if (!hasPermission) {
          // Si el usuario nos nego el permiso, lanzamos un error que tu UI debe atrapar
          throw Exception("Permiso de almacenamiento denegado. No se puede guardar el archivo.");
        }
        // si tenemos permiso buscamos la carpeta de descarga
        targetDir = Directory('/storage/emulated/0/Download');
        if (!await targetDir.exists()) {
          targetDir = await getExternalStorageDirectory(); 
        }
      } else {
        targetDir = await getApplicationDocumentsDirectory();
      }

      final filePath = '${targetDir!.path}/$fileName';
      final file = File(filePath);
      
      // Intentamos escribir. Si Android falla, el try-catch del BottomSheet atrapará el error.
      await file.writeAsBytes(utf8.encode(csvData));
      
      return filePath;
    }
  }
}