import 'package:flutter/material.dart';
import '../main.dart'; 

class CustomSnackBar {
  /// Muestra un SnackBar flotante, moderno y adaptado al tema.
  static void show({
    required BuildContext context,
    required String message,
    required IconData icon,
    Color? backgroundColor,
    Color? iconColor,
    SnackBarAction? action,
    int durationSeconds = 3,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // colores por defecto basados en tu tema
    final bgColor = backgroundColor ?? (isDark ? AppColors.primary : Colors.green.shade700);
    final contentColor = isDark ? Colors.black : Colors.white;

    // oculta el SnackBar anterior si el usuario hace clic rapido en varias cosas
    ScaffoldMessenger.of(context).clearSnackBars(); 

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: bgColor,
        duration: Duration(seconds: durationSeconds),
        action: action,
        content: Row(
          children: [
            Icon(icon, color: iconColor ?? contentColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: contentColor, 
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}