import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyFormat {
  // Metodo para formato moneda ej: 23,540.00
  static String format(double amount) {
    final formatter = NumberFormat("#,##0.00", "en_US"); 
    return "Bs ${formatter.format(amount)}";
  }
}

//clase para formateria input de monto
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    // Quitamos todo lo que no sea digito o punto
    String newText = newValue.text.replaceAll(',', ''); 
    
    // Evitar multiples puntos decimales
    if ('.'.allMatches(newText).length > 1) {
      return oldValue;
    }

    // Separamos parte entera y decimal
    List<String> parts = newText.split('.');
    String integerPart = parts[0];
    String? decimalPart = parts.length > 1 ? parts[1] : null;

    // Limitamos decimales a 2 (ej: 45.68)
    if (decimalPart != null && decimalPart.length > 2) {
      decimalPart = decimalPart.substring(0, 2);
    }

    // Formateamos la parte entera con comas
    final formatter = NumberFormat("#,###");
    String newIntegerPart = "";
    
    if (integerPart.isNotEmpty) {
      try {
        newIntegerPart = formatter.format(int.parse(integerPart));
      } catch (e) {
        return oldValue; // Si falla el parseo (ej: caracteres raros)
      }
    }

    // Reconstruimos el texto final
    String newString = newIntegerPart;
    if (parts.length > 1 || newText.endsWith('.')) {
      newString += ".";
      if (decimalPart != null) {
        newString += decimalPart;
      }
    }
    // Calculamos la nueva posicion del cursor 
    int selectionIndex = newString.length - (newValue.text.length - newValue.selection.end);

    return TextEditingValue(
      text: newString,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}
