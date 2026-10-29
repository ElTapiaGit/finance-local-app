import 'package:flutter/material.dart';
import '../main.dart';

/// Selector tipo pill para alternar entre Gasto e Ingreso.
class TransactionTypeSelector extends StatelessWidget {
  final bool isExpense;
  final ValueChanged<bool> onTypeChanged;

  const TransactionTypeSelector({
    super.key,
    required this.isExpense,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final incomeColor = isDarkMode ? AppColors.primary : AppColors.primaryLight;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTypeButton(
          label: "Gasto",
          isExpenseBtn: true,
          incomeColor: incomeColor,
        ),
        const SizedBox(width: 12),
        _buildTypeButton(
          label: "Ingreso",
          isExpenseBtn: false,
          incomeColor: incomeColor,
        ),
      ],
    );
  }

  Widget _buildTypeButton({
    required String label,
    required bool isExpenseBtn,
    required Color incomeColor,
  }) {
    final isSelected = isExpense == isExpenseBtn;
    final color = isExpenseBtn ? Colors.redAccent : incomeColor;

    return GestureDetector(
      onTap: () => onTypeChanged(isExpenseBtn),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

