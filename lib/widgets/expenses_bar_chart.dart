import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/transaction_model.dart';

class ExpensesBarChart extends StatelessWidget {
  final List<TransactionModel> transactions;

  const ExpensesBarChart({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // PROCESAMIENTO DE DATOS
    final topCategories = _processData();

    // Si no hay gastos este mes, mostramos un mensaje
    if (topCategories.isEmpty) {
      return Center(
        child: Text(
          "Sin gastos este mes",
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    // Calculamos el gasto maximo para escalar el grafico (eje Y)
    // Le agregamos un 20% extra para que la barra mas alta no toque el techo
    final double maxY = topCategories.first.totalAmount * 1.2; 

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        // Ocultar bordes y grillas del grafico
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        
        // Titulos (Eje X e Y)
        titlesData: FlTitlesData(
          show: true,
          // Ocultar titulos izquierda, derecha y arriba
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          
          // Configurar titulos de abajo (iconos de categoria)
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index >= 0 && index < topCategories.length) {
                  final data = topCategories[index];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Icon(
                      IconData(data.iconCode, fontFamily: 'MaterialIcons'),
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                      size: 20,
                    ),
                  );
                }
                return const SizedBox();
              },
              reservedSize: 40, // Espacio reservado para los iconos
            ),
          ),
        ),

        // DATOS DE LAS BARRAS
        barGroups: topCategories.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: data.totalAmount,
                color: Color(data.colorValue), // Usamos el color de la categoria
                width: 16, // Grosor de la barra
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                // Fondo de la barra (track)
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY, // Altura total del fondo
                  color: isDarkMode ? Colors.white10 : Colors.grey.shade100,
                ),
              ),
            ],
            // Tooltip al tocar la barra (muestra el monto)
            showingTooltipIndicators: [0], 
          );
        }).toList(),

        // Configuracion de los Tooltips (textos flotantes sobre las barras)
        barTouchData: BarTouchData(
          enabled: false, // Desactivamos interaccion manual para dejar los textos fijos
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.transparent, // fondo transparente
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: 4, // Distancia entre barra y texto
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                // Formateamos numeros grandes (ej: 1.5k)
                _formatCompact(rod.toY),
                TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black54,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // LOGICA DE PROCESAMIENTO 
  List<_CategorySummary> _processData() {
    final now = DateTime.now();
    final Map<String, _CategorySummary> grouped = {};

    for (var tx in transactions) {
      // Filtro: solo gastos del mes y año actual
      if (tx.type == TransactionType.expense && 
          tx.date.month == now.month && 
          tx.date.year == now.year) {
            
        // Sumar montos por nombre de categoria
        if (grouped.containsKey(tx.categoryName)) {
          grouped[tx.categoryName]!.totalAmount += tx.amount;
        } else {
          grouped[tx.categoryName] = _CategorySummary(
            name: tx.categoryName,
            totalAmount: tx.amount,
            colorValue: tx.categoryColor,
            iconCode: tx.categoryIconCode,
          );
        }
      }
    }

    // Convertir a lista y ordenar desde el mayor gasto
    final sortedList = grouped.values.toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    // Tomar solo los Top 5
    return sortedList.take(5).toList();
  }

  // Formateador simple para números (ej: 1500 -> 1.5k)
  String _formatCompact(double amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}k';
    }
    return amount.toInt().toString();
  }
}

// Clase auxiliar privada para manejar los datos agrupados
class _CategorySummary {
  String name;
  double totalAmount;
  int colorValue;
  int iconCode;

  _CategorySummary({
    required this.name,
    required this.totalAmount,
    required this.colorValue,
    required this.iconCode,
  });
}