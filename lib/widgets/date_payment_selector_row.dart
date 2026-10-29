import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';

/// Fila simetrica que coordina el selector de fecha y el selector de metodo de pago.
class DatePaymentSelectorRow extends StatelessWidget {
  final DateTime selectedDate;
  final String selectedPaymentMethod;
  final List<String> paymentMethods;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<String> onPaymentMethodChanged;

  const DatePaymentSelectorRow({
    super.key,
    required this.selectedDate,
    required this.selectedPaymentMethod,
    required this.paymentMethods,
    required this.onDateChanged,
    required this.onPaymentMethodChanged,
  });

  Future<void> _presentDatePicker(BuildContext context) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final calendarColor = isDarkMode ? AppColors.primary : AppColors.primaryLight;

    final pickedDate = await showDatePicker(
      context: context,
      locale: const Locale('es', 'ES'),
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      cancelText: "CANCELAR",
      confirmText: "ACEPTAR",
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDarkMode
                ? const ColorScheme.dark(
                    primary: AppColors.primary,
                    onPrimary: Colors.black,
                    surface: AppColors.cardDark,
                  )
                : ColorScheme.light(
                    primary: calendarColor,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      onDateChanged(pickedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _presentDatePicker(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.white10 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('dd/MM/yyyy').format(selectedDate),
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return DropdownMenu<String>(
                expandedInsets: EdgeInsets.zero,
                requestFocusOnTap: false,
                enableFilter: false,
                enableSearch: false,
                initialSelection: selectedPaymentMethod,
                textStyle: TextStyle(
                  fontSize: 15,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: isDarkMode ? Colors.white10 : Colors.grey.shade200,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
                menuStyle: MenuStyle(
                  backgroundColor: WidgetStateProperty.all<Color>(
                    isDarkMode ? const Color(0xFF1C2C20) : Colors.white,
                  ),
                  shape: WidgetStateProperty.all<OutlinedBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                dropdownMenuEntries: paymentMethods.map((String method) {
                  return DropdownMenuEntry<String>(
                    value: method,
                    label: method,
                    style: MenuItemButton.styleFrom(
                      foregroundColor: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  );
                }).toList(),
                onSelected: (newValue) {
                  if (newValue != null) {
                    onPaymentMethodChanged(newValue);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

