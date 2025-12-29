import 'package:flutter/material.dart';
import '../main.dart'; 

class SaveButton extends StatefulWidget {
  final String label;
  final Future<void> Function() onPressed; 
  final bool isEnabled; // Para validaciones externas

  const SaveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isEnabled = true,
  });

  @override
  State<SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<SaveButton> {
  bool _isLoading = false;

  void _handlePress() async {
    // Evitar doble clic si ya esta cargando
    if (_isLoading) return;
    //Bloquear UI y mostrar spinner
    setState(() => _isLoading = true);

    try {
      //Ejecutar la logica que nos paso el padre (Guardar en Hive)
      await widget.onPressed();
      
    } catch (e) {
      //debugPrint("Error en SaveButton: $e");
      // Si fallo
      if (mounted) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: isDarkMode ? const Color(0xFF1C2C20) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.redAccent),
                SizedBox(width: 10),
                Text("Problema Interno", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            // MENSAJE CORREGIDO: Nada de conexion a internet
            content: const Text(
              "Ocurrió un problema inesperado. Inténtalo de nuevo.",
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  "Aceptar", 
                  style: TextStyle(
                    color: isDarkMode ? AppColors.primary : AppColors.primaryLight, 
                    fontWeight: FontWeight.bold
                  )
                ),
              )
            ],
          ),
        );
      }
    } finally {
      // apaga el spinner
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? AppColors.primary : AppColors.primaryLight;
    final textColor = isDarkMode ? Colors.black : Colors.white;

    return SizedBox(
      width: double.infinity,
      height: 55, 
      child: ElevatedButton(
        onPressed: (widget.isEnabled && !_isLoading) ? _handlePress : null,
        
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          // Color visual cuando esta deshabilitado
          disabledBackgroundColor: bgColor.withValues(alpha: 0.6),
        ),
        
        child: _isLoading
            ? SizedBox(
                width: 24, 
                height: 24, 
                child: CircularProgressIndicator(color: textColor, strokeWidth: 2.5),
              )
            : Text(
                widget.label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}