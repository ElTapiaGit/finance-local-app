// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import '../models/transaction_model.dart';
import '../services/export_service.dart';
import '../utils/custom_snackbar.dart';
import '../main.dart'; 

class ExportBottomSheet extends StatefulWidget {
  final List<TransactionModel> allTransactions;

  const ExportBottomSheet({super.key, required this.allTransactions});

  @override
  State<ExportBottomSheet> createState() => _ExportBottomSheetState();
}

class _ExportBottomSheetState extends State<ExportBottomSheet> {
  // ignore: prefer_final_fields
  List<DateTime> _availableMonths = [];
  DateTime? _selectedMonth;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _extractAvailableMonths();
  }

  void _extractAvailableMonths() {
    final Set<String> uniqueKeys = {};
    
    for (var tx in widget.allTransactions) {
      final key = '${tx.date.year}-${tx.date.month}';
      if (!uniqueKeys.contains(key)) {
        uniqueKeys.add(key);
        _availableMonths.add(DateTime(tx.date.year, tx.date.month, 1));
      }
    }

    _availableMonths.sort((a, b) => b.compareTo(a));

    if (_availableMonths.isNotEmpty) {
      _selectedMonth = _availableMonths.first;
    } else {
      _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
      _availableMonths.add(_selectedMonth!);
    }
  }

  Future<void> _handleExport(bool isShare) async {
    if (_selectedMonth == null) return;
    
    setState(() => _isExporting = true);
    
    try {
      final filteredTx = widget.allTransactions.where((tx) {
        return tx.date.year == _selectedMonth!.year &&
              tx.date.month == _selectedMonth!.month;
      }).toList();

      String monthLabel = DateFormat('MMMM yyyy', 'es').format(_selectedMonth!);
      monthLabel = monthLabel[0].toUpperCase() + monthLabel.substring(1);

      // Llamamos al servicio (ahora es seguro porque tiene timestamp)
      final String? downloadedPath = await ExportService.exportToCSV(filteredTx, monthLabel, share: isShare);

      if (mounted) {
        Navigator.pop(context); 
      
        final isDark = Theme.of(context).brightness == Brightness.dark;
      
        CustomSnackBar.show(
          context: context,
          message: isShare ? "Opciones de compartir listas" : "Archivo descargado",
          icon: isShare ? Icons.share_rounded : Icons.check_circle_rounded,
          backgroundColor: isShare 
              ? (isDark ? AppColors.primaryLight : Colors.blue.shade600) 
              : null, 
          durationSeconds: 5, 
          
          action: downloadedPath != null 
            ? SnackBarAction(
                label: "ABRIR",
                textColor: isDark ? Colors.black : Colors.white,
                onPressed: () async {
                  // Forza el MIME type para que Android entienda que app usar
                  final result = await OpenFilex.open(downloadedPath, type: 'text/csv');
                  
                  if (result.type != ResultType.done && context.mounted) {
                    CustomSnackBar.show(
                      context: context,
                      message: "Búscalo en tu carpeta de Descargas",
                      icon: Icons.folder_open_rounded,
                      backgroundColor: Colors.orange.shade700,
                    );
                  }
                },
              )
            : null,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerramos el modal
        CustomSnackBar.show(
          context: context,
          message: "Error al exportar. Revisa los permisos de tu celular.",
          icon: Icons.error_rounded,
          backgroundColor: Colors.red.shade700,
          iconColor: Colors.white,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false); 
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final btnBgColor = isDark ? AppColors.primary : AppColors.primaryLight;
    final btnTextColor = isDark ? Colors.black : Colors.white;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 20, 
        left: 24,
        right: 24,
        top: 20
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24))
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, 
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          
          Text("Exportar Reporte", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 24),

          // SELECTOR DE MES CORREGIDO 
          LayoutBuilder(
            builder: (context, constraints) {
              return DropdownMenu<DateTime>(
                expandedInsets: EdgeInsets.zero, 
                menuHeight: 250, 
                requestFocusOnTap: false, 
                enableFilter: false, 
                enableSearch: false,
                initialSelection: _selectedMonth,
                hintText: "Selecciona el mes", 
                textStyle: TextStyle(color: textColor, fontSize: 16),
                
                menuStyle: MenuStyle(
                  backgroundColor: WidgetStateProperty.all<Color>(isDark ? AppColors.cardDark : Colors.white),
                  shape: WidgetStateProperty.all<OutlinedBorder>(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.grey.shade200,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                
                dropdownMenuEntries: _availableMonths.map((month) {
                  String label = DateFormat('MMMM yyyy', 'es').format(month);
                  label = label[0].toUpperCase() + label.substring(1);
                  return DropdownMenuEntry<DateTime>(
                    value: month,
                    label: label,
                    style: MenuItemButton.styleFrom(
                      foregroundColor: textColor,
                    ),
                  );
                }).toList(),
                
                onSelected: (val) {
                  if (val != null) setState(() => _selectedMonth = val);
                },
              );
            }
          ),
          const SizedBox(height: 30),

          // BOTONES DIVIDIDOS DESCARGAR Y COMPARTIR
          if (_isExporting)
            const SizedBox(
              height: 55, 
              child: Center(child: CircularProgressIndicator())
            )
          else
            Row(
              children: [
                // BOTON SOLO DESCARGAR
                Expanded(
                  child: SizedBox(
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: widget.allTransactions.isEmpty ? null : () => _handleExport(false),
                      icon: Icon(Icons.download_rounded, color: btnTextColor),
                      label: Text(
                        "Descargar", 
                        style: TextStyle(color: btnTextColor, fontWeight: FontWeight.bold, fontSize: 15)
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: btnBgColor,
                        disabledBackgroundColor: Colors.grey.shade600,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // BOTON 2 COMPARTIR
                Expanded(
                  child: SizedBox(
                    height: 55,
                    child: OutlinedButton.icon(
                      onPressed: widget.allTransactions.isEmpty ? null : () => _handleExport(true),
                      icon: Icon(Icons.share_rounded, color: btnBgColor),
                      label: Text(
                        "Compartir", 
                        style: TextStyle(color: btnBgColor, fontWeight: FontWeight.bold, fontSize: 15)
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: btnBgColor, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                      ),
                    ),
                  ),
                ),
              ],
            ),
          
          if (widget.allTransactions.isEmpty) ...[
            const SizedBox(height: 12),
            const Text("No hay datos registrados para exportar.", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
          ]
        ],
      ),
    );
  }
}