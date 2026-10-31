import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TransactionFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String>? onSearchChanged;
  final DateTime? filterDate;
  final String filterMode;
  final VoidCallback onSelectDate;
  final ValueChanged<String> onFilterModeChanged;
  final VoidCallback? onClearFilters;

  static final DateFormat _chipDayFormat = DateFormat('dd', 'es');
  static final DateFormat _chipMonthFormat = DateFormat('MMMM', 'es');

  const TransactionFilterBar({
    super.key,
    required this.searchController,
    this.onSearchChanged,
    this.filterDate,
    required this.filterMode,
    required this.onSelectDate,
    required this.onFilterModeChanged,
    this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDateActive = filterDate != null;
    final inputFillColor = isDark ? Colors.white10 : Colors.grey.shade200;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fila: Campo de busqueda y boton de calendario
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: inputFillColor,
                      hintText: "Buscar transacción...",
                      prefixIcon: Icon(
                        Icons.search,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Boton selector de fecha
              InkWell(
                onTap: onSelectDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDateActive
                        ? colorScheme.primaryContainer
                        : inputFillColor,
                    borderRadius: BorderRadius.circular(12),
                    border: isDateActive
                        ? Border.all(color: colorScheme.primary)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        color: isDateActive
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Chips de filtro cuando hay fecha activa
          if (isDateActive)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Row(
                children: [
                  // Chip: Mes completo
                  _buildChip(
                    context: context,
                    label: "Mes: ${_chipMonthFormat.format(filterDate!)}",
                    isActive: filterMode == 'month',
                    onTap: () => onFilterModeChanged('month'),
                  ),
                  const SizedBox(width: 10),
                  // Chip: Dia exacto
                  _buildChip(
                    context: context,
                    label: "Día: ${_chipDayFormat.format(filterDate!)}",
                    isActive: filterMode == 'day',
                    onTap: () => onFilterModeChanged('day'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required BuildContext context,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? colorScheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? colorScheme.primary : colorScheme.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

