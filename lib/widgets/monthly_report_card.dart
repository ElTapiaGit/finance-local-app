import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/transaction_model.dart';
import '../utils/currency_format.dart';
import '../utils/string_extensions.dart';
import 'monthly_expenses_chart.dart';

/// Tarjeta colapsable para el resumen mensual con KPIs ejecutivos, alertas de sobregiro y grafico detallado.
class MonthlyReportCard extends StatefulWidget {
  final DateTime period;
  final double totalIncome;
  final double totalExpense;
  final double netBalance;
  final bool isNegative;
  final List<TransactionModel> expenseTxsForChart;
  final double totalHistoricalBalance;
  final String searchQuery;
  final bool initiallyExpanded;

  const MonthlyReportCard({
    super.key,
    required this.period,
    required this.totalIncome,
    required this.totalExpense,
    required this.netBalance,
    required this.isNegative,
    required this.expenseTxsForChart,
    required this.totalHistoricalBalance,
    this.searchQuery = "",
    this.initiallyExpanded = false,
  });

  @override
  State<MonthlyReportCard> createState() => _MonthlyReportCardState();
}

class _MonthlyReportCardState extends State<MonthlyReportCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant MonthlyReportCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyExpanded != oldWidget.initiallyExpanded) {
      _isExpanded = widget.initiallyExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: isDarkMode ? AppColors.cardDark : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isDarkMode
            ? BorderSide.none
            : BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ENCABEZADO TOUCH
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Fila 1: Titulo e Icono animado
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat("MMMM yyyy", "es")
                            .format(widget.period)
                            .capitalize(),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                      ),
                      AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Theme.of(context).iconTheme.color ??
                              Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Fila 2: Metricas de balance (100% de ancho)
                  _buildMonthBalanceSummary(
                    context,
                    income: widget.totalIncome,
                    expense: widget.totalExpense,
                    balance: widget.netBalance,
                  ),
                ],
              ),
            ),
          ),

          // CUERPO COLAPSABLE
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isNegative) ...[
                    const SizedBox(height: 10),
                    _buildNegativeBalanceAlert(
                      context,
                      widget.netBalance,
                      widget.totalHistoricalBalance,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (widget.expenseTxsForChart.isNotEmpty) ...[
                    const Divider(),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Detalle de Gastos",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        if (widget.searchQuery.isNotEmpty)
                          Text(
                            "Filtrado: ${widget.searchQuery}",
                            style: TextStyle(
                              fontSize: 10,
                              color: isDarkMode
                                  ? AppColors.primary
                                  : AppColors.primaryLight,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    MonthlyExpensesChart(
                      monthlyTx: widget.expenseTxsForChart,
                      monthLabel: "",
                    ),
                  ] else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          widget.searchQuery.isNotEmpty
                              ? 'No hay gastos de "${widget.searchQuery}" este mes'
                              : "Sin gastos registrados este mes",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthBalanceSummary(
    BuildContext context, {
    required double income,
    required double expense,
    required double balance,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: _buildMiniSummaryItem(
              label: "Ingresos",
              amount: income,
              color: isDarkMode ? AppColors.primary : AppColors.primaryLight,
              isDarkMode: isDarkMode,
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: _buildMiniSummaryItem(
              label: "Gastos",
              amount: expense,
              color: Colors.redAccent,
              isDarkMode: isDarkMode,
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: _buildMiniSummaryItem(
              label: "Balance",
              amount: balance,
              color: balance >= 0 ? Colors.blue : Colors.orange,
              isDarkMode: isDarkMode,
              showSign: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniSummaryItem({
    required String label,
    required double amount,
    required Color color,
    required bool isDarkMode,
    bool showSign = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            "${showSign && amount > 0 ? '+' : ''}${CurrencyFormat.format(amount)}",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNegativeBalanceAlert(
    BuildContext context,
    double monthlyBalance,
    double totalHistoricalBalance,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isOverdraft = totalHistoricalBalance <= 0;

    Color bgColor;
    Color borderColor;
    Color iconColor;
    Color titleColor;
    Color textColor;

    if (isOverdraft) {
      final baseColor = Colors.orange;
      bgColor = isDarkMode
          ? baseColor.withValues(alpha: 0.15)
          : baseColor.withValues(alpha: 0.1);
      borderColor = isDarkMode
          ? baseColor.withValues(alpha: 0.3)
          : baseColor.withValues(alpha: 0.3);
      iconColor = isDarkMode ? baseColor.shade300 : baseColor;
      titleColor = isDarkMode ? baseColor.shade200 : baseColor.shade800;
      textColor = isDarkMode ? Colors.grey.shade300 : baseColor.shade900;
    } else {
      final baseColor = Colors.indigo;
      bgColor = isDarkMode
          ? baseColor.withValues(alpha: 0.2)
          : baseColor.withValues(alpha: 0.1);
      borderColor = isDarkMode
          ? baseColor.withValues(alpha: 0.4)
          : baseColor.withValues(alpha: 0.3);
      iconColor = isDarkMode ? baseColor.shade200 : baseColor;
      titleColor = isDarkMode ? Colors.white : baseColor;
      textColor = isDarkMode ? Colors.grey.shade300 : baseColor.shade800;
    }

    String title;
    Widget message;
    final monthlyDeficitString = CurrencyFormat.format(monthlyBalance.abs());

    if (isOverdraft) {
      title = "Saldo Insuficiente / Sobregiro";
      message = Text(
        "Tus gastos superaron tus ingresos y tu saldo acumulado. Es posible que hayas utilizado dinero en efectivo no registrado (reserva externa) o un préstamo.",
        style: TextStyle(color: textColor, fontSize: 13, height: 1.4),
      );
    } else {
      title = "Uso de Ahorros";
      message = RichText(
        text: TextSpan(
          style: TextStyle(color: textColor, fontSize: 13, height: 1.4),
          children: [
            const TextSpan(
              text: "Este mes tus gastos superaron a tus ingresos. Has utilizado ",
            ),
            TextSpan(
              text: monthlyDeficitString,
              style: TextStyle(fontWeight: FontWeight.bold, color: titleColor),
            ),
            const TextSpan(
              text: " de tu saldo acumulado para cubrirlos.",
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isOverdraft
                ? Icons.warning_amber_rounded
                : Icons.savings_outlined,
            color: iconColor,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                message,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
