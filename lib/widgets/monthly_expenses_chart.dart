import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../utils/math_utils.dart';

class MonthlyExpensesChart extends StatelessWidget {
  final List<TransactionModel> monthlyTx;
  final String monthLabel;

  const MonthlyExpensesChart({
    super.key,
    required this.monthlyTx,
    required this.monthLabel,
  });

  String _formatCurrency(double amount) {
    final formatter = NumberFormat("#,##0.00", "en_US"); 
    return "Bs ${formatter.format(amount)}";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // PROCESAR Y AGRUPAR CATEGORIAS
    final Map<String, _CategorySummary> grouped = {};

    for (var tx in monthlyTx) {
      if (grouped.containsKey(tx.categoryName)) {
        grouped[tx.categoryName]!.amount += tx.amount;
      } else {
        grouped[tx.categoryName] = _CategorySummary(
          name: tx.categoryName,
          amount: tx.amount,
          colorValue: tx.categoryColor,
          iconCode: tx.categoryIconCode,
        );
      }
    }

    // HIGIENE DE DATOS 
    // limpiamos los decimales sucios (ej: 150.0000004)
    // que se pudieron generar durante la suma del bucle anterior.
    for (var key in grouped.keys) {
      grouped[key]!.amount = roundAmount(grouped[key]!.amount);
    }
    // Ordenar de mayor a menor gasto
    final categories = grouped.values.toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    if (categories.isEmpty) {
      return SizedBox(
        height: 150,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart_rounded, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 10),
              Text(
                "Sin gastos registrados",
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    // Calculamos el monto maximo para definir el 100% del ancho de la barra
    final double maxAmount = categories.first.amount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LISTA DE BARRAS HORIZONTALES
        // Usamos spread operator (...) para crear una lista de widgets
        ...categories.map((cat) {
          // Calculamos el porcentaje (0.0 a 1.0)
          final double percentage = (cat.amount / maxAmount).clamp(0.0, 1.0);

          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              children: [
                //ICONO CATEGORY
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Color(cat.colorValue).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    IconData(cat.iconCode, fontFamily: 'MaterialIcons'),
                    color: Color(cat.colorValue),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),

                // CONTENIDO (Nombre, Barra, Monto)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fila Superior: Nombre y Monto
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            cat.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            _formatCurrency(cat.amount),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Barra de Progreso Customizada usamos LayoutBuilder para saber el ancho disponible
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final maxWidth = constraints.maxWidth;
                          return Stack(
                            children: [
                              // Fondo de la barra Gris suave
                              Container(
                                height: 8,
                                width: maxWidth,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              // Barra de progreso con animacion suabe
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0, end: maxWidth * percentage),
                                duration: const Duration(milliseconds: 800),
                                curve: Curves.easeOutCubic,
                                builder: (context, width, _) {
                                  return Container(
                                    height: 8,
                                    width: width,
                                    decoration: BoxDecoration(
                                      color: Color(cat.colorValue),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _CategorySummary {
  final String name;
  double amount;
  final int colorValue;
  final int iconCode;

  _CategorySummary({
    required this.name,
    required this.amount,
    required this.colorValue,
    required this.iconCode,
  });
}