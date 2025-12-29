import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart'; // Para AppColors
import '../models/transaction_model.dart';
import '../widgets/monthly_expenses_chart.dart';
import '../utils/math_utils.dart'; // utilidad de redondeo
import '../utils/currency_format.dart';
import '../services/database_service.dart';

class MonthlyExpensesScreen extends StatefulWidget {
  final List<TransactionModel> transactions;

  const MonthlyExpensesScreen({super.key, required this.transactions});

  @override
  State<MonthlyExpensesScreen> createState() => _MonthlyExpensesScreenState();
}

class _MonthlyExpensesScreenState extends State<MonthlyExpensesScreen> {
  final DatabaseService _dbService = DatabaseService();
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  
  // Filtro de mes (1 = Enero a 12 = Diciembre)
  int? selectedMonthIndex; 
  // Lista de fechas unicas (Año-Mes)
  late List<DateTime> _allHistoryYearMonths; 
  // Indices para el dropdown
  late List<int> _uniqueMonthIndices;
  // Mapa para acceder a las transacciones de un mes instantaneamente
  final Map<String, List<TransactionModel>> _groupedTransactions = {};

  late Future<double> _totalBalanceFuture; //cargar saldo total

  @override
  void initState() {
    super.initState();
    _calculateHistoryData();
    _totalBalanceFuture = _dbService.getTotalBalance();
  }
  // Limpiar el controlador al salir para evitar fugas de memoria
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Calculamos todo al inicio
  void _calculateHistoryData() {
    _groupedTransactions.clear();
    final Set<String> uniqueKeys = {};
    final List<DateTime> yearMonths = [];

    // AGRUPAR TRANSACCIONES (Indexacion)
    for (var tx in widget.transactions) {
      // Clave única por mes
      final key = "${tx.date.year}-${tx.date.month}";
      if (!_groupedTransactions.containsKey(key)) {
        _groupedTransactions[key] = [];
      }
      // Agregamos la transacción a su mes correspondiente
      _groupedTransactions[key]!.add(tx);
      //lista de los meses disponibles
      if (!uniqueKeys.contains(key)) {
        uniqueKeys.add(key);
        yearMonths.add(DateTime(tx.date.year, tx.date.month, 1));
      }
    }
    // Ordenar del mas reciente
    yearMonths.sort((a, b) => b.compareTo(a));
    _allHistoryYearMonths = yearMonths;

    // Obtener solo los MESES unicos para el DROPDOWN
    final Set<int> monthsIndices = {};
    for (var date in yearMonths) {
      monthsIndices.add(date.month);
    }
    _uniqueMonthIndices = monthsIndices.toList()..sort();
  }

  // Ya no recorre toda la lista, solo consulta el mapa
  List<TransactionModel> _getTransactionsFast(DateTime date) {
    final key = "${date.year}-${date.month}";
    return _groupedTransactions[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
  
    // filtrado de meses visibles
    List<DateTime> visibleYearMonths;

    if (selectedMonthIndex != null) {
      visibleYearMonths = _allHistoryYearMonths.where((date) {
        return date.month == selectedMonthIndex;
      }).toList();
    } else {
      // Mostrar solo ultimos 4 si no hay filtro
      visibleYearMonths = _allHistoryYearMonths.take(4).toList();
    }

    // filtro por busqueda
    final cardsContent = visibleYearMonths.where((m) {
      if (searchQuery.isEmpty) return true;
      // Obtenemos transacciones del mapa
      final monthTxs = _getTransactionsFast(m); 
      //buscamos coincidencias solo en este mes
      return monthTxs.any((t) => t.categoryName.toLowerCase().contains(searchQuery.toLowerCase()));
    }).toList();

    

    return Scaffold(
      appBar: AppBar(
        title: const Text("Reporte Mensual", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, 
            color: isDarkMode ? Colors.white : Colors.black87
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // SECCION DE FILTROS 
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                children: [
                  // Buscador
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Buscar categoría...",
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: searchQuery.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear(); 
                              setState(() => searchQuery = ""); 
                            },
                          )
                        : null,
                      filled: true,
                      fillColor: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    ),
                    onChanged: (value) => setState(() => searchQuery = value),
                  ),
                  const SizedBox(height: 12),

                  // FILTRO POR MES
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedMonthIndex,
                        hint: Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            "Recientes (Últimos 4)",
                            style: TextStyle(color: isDarkMode ? AppColors.primary : AppColors.primaryLight),
                          ),
                        ),
                        isExpanded: true,
                        icon: const Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: Icon(Icons.keyboard_arrow_down_rounded),
                        ),
                        borderRadius: BorderRadius.circular(16),
                        dropdownColor: isDarkMode ? AppColors.cardDark : Colors.white,
                        menuMaxHeight: 300,
                        items: [
                          DropdownMenuItem<int>(
                            value: null,
                            child: _buildDropdownItemContent(
                              "Recientes (Últimos 4)",
                              selectedMonthIndex == null,
                            ),
                          ),
                          ..._uniqueMonthIndices.map((monthIndex) {
                            final dummyDate = DateTime(DateTime.now().year, monthIndex, 1);
                            final monthName = DateFormat("MMMM", "es").format(dummyDate).capitalize();
                            return DropdownMenuItem<int>(
                              value: monthIndex,
                              child: _buildDropdownItemContent(
                                monthName,
                                selectedMonthIndex == monthIndex,
                              ),
                            );
                          }),
                        ],
                        onChanged: (newMonthIndex) {
                          setState(() => selectedMonthIndex = newMonthIndex);
                        },
                      ),
                    ),
                  )
                ],
              ),
            ),

            //  LISTA DE TARJETAS (REPORTES) 
            Expanded(
              child: FutureBuilder<double>(
                future: _totalBalanceFuture,
                builder: (context, snapshot) {
                  final totalHistoricalBalance = snapshot.data ?? 0.0;

                  if (cardsContent.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: cardsContent.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 20),
                    itemBuilder: (_, index) {
                      final yearMonthDate = cardsContent[index];
                      
                      // Obtenemos TODAS las transacciones del mes
                      final allMonthTxs = _getTransactionsFast(yearMonthDate);
                      
                      // Calculamos totales
                      double totalIncome = 0;
                      double totalExpense = 0;

                      for (var tx in allMonthTxs) {
                        if (tx.type == TransactionType.income) {
                          totalIncome += tx.amount;
                        } else {
                          totalExpense += tx.amount;
                        }
                      }
                      
                      totalIncome = roundAmount(totalIncome);
                      totalExpense = roundAmount(totalExpense);

                      final double netBalance = roundAmount(totalIncome - totalExpense);
                      final bool isNegative = netBalance < 0;

                      // filtrar para el grafico segun la busqueda
                      final expenseTxsForChart = allMonthTxs.where((tx) {
                        final isExpense = tx.type == TransactionType.expense;
                        final matchesSearch = searchQuery.isEmpty || 
                                              tx.categoryName.toLowerCase().contains(searchQuery.toLowerCase());
                        return isExpense && matchesSearch;
                      }).toList();

                      return Card(
                        elevation: 0,
                        color: isDarkMode ? AppColors.cardDark : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: isDarkMode ? BorderSide.none : BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // CABECERA: Mes y Año
                              Text(
                                DateFormat("MMMM yyyy", "es").format(yearMonthDate).capitalize(),
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode ? Colors.white : Colors.black87,
                                    ),
                              ),
                              const SizedBox(height: 20),

                              // RESUMEN DE BALANCE (Ingreso vs Gasto)
                              _buildMonthBalanceSummary(
                                context, 
                                income: totalIncome, 
                                expense: totalExpense, 
                                balance: netBalance
                              ),
                              const SizedBox(height: 20),

                              // ALERTA DE BALANCE NEGATIVO
                              if (isNegative)
                                _buildNegativeBalanceAlert(
                                  context, 
                                  netBalance, 
                                  totalHistoricalBalance 
                                ),

                              if (isNegative) const SizedBox(height: 20),

                              // GRAFICO solo del gasto filtrado
                              if (expenseTxsForChart.isNotEmpty) ...[
                                const Divider(),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("Detalle de Gastos", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    if (searchQuery.isNotEmpty)
                                       Text("Filtrado: $searchQuery", style: TextStyle(fontSize: 10, color: isDarkMode ? AppColors.primary : AppColors.primaryLight, fontStyle: FontStyle.italic)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                MonthlyExpensesChart(
                                  monthlyTx: expenseTxsForChart,
                                  monthLabel: "", 
                                ),
                              ] else 
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 20),
                                    child: Text(
                                      searchQuery.isNotEmpty 
                                        ? "No hay gastos de \"$searchQuery\" este mes"
                                        : "Sin gastos registrados este mes", 
                                      style: const TextStyle(color: Colors.grey)
                                    ),
                                  ),
                                )
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }
  // HELPER para diseñar el item seleccionado vs no seleccionado
  Widget _buildDropdownItemContent(String text, bool isSelected) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDarkMode ? AppColors.primary : AppColors.primaryLight;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        // Si esta seleccionado, le ponemos un fondo suave del color primario
        color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: TextStyle(
              // Texto en negrita y color activo si esta seleccionado
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? activeColor : (isDarkMode ? Colors.white : Colors.black87),
            ),
          ),
          // Icono Check solo si esta seleccionado
          if (isSelected)
            Icon(Icons.check_rounded, color: activeColor, size: 18),
        ],
      ),
    );
  }

  // WIDGETS AUXILIARES DE CASRD BALANCE 
  Widget _buildMonthBalanceSummary(BuildContext context, {required double income, required double expense, required double balance}) { 
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
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
              isDarkMode: isDarkMode
            ),
          ),
          // Separador visual o espacio opcional, pero Expanded ya maneja el espacio
          const SizedBox(width: 2), 
          Expanded(
            child: _buildMiniSummaryItem(
              label: "Gastos", 
              amount: expense, 
              color: Colors.redAccent,
              isDarkMode: isDarkMode
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: _buildMiniSummaryItem(
              label: "Balance", 
              amount: balance, 
              color: balance >= 0 ? Colors.blue : Colors.orange, 
              isDarkMode: isDarkMode,
              showSign: true
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniSummaryItem({required String label, required double amount, required Color color, required bool isDarkMode, bool showSign = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis,),
        const SizedBox(height: 2),
        // FITTEDBOX: Si el numero es muy grande, reduce la fuente
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            "${showSign && amount > 0 ? '+' : ''}${CurrencyFormat.format(amount)}",
            style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.bold, 
              color: color
            ),
          ),
        )
      ],
    );
  }

  // ALERTA DE FLUJO DE CAJA 
  Widget _buildNegativeBalanceAlert(BuildContext context, double monthlyBalance, double totalHistoricalBalance) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // (Saldo Total es negativo o cero).
    final isOverdraft = totalHistoricalBalance <= 0;

    Color bgColor;
    Color borderColor;
    Color iconColor;
    Color titleColor;
    Color textColor;

    if (isOverdraft) {
      // PALETA: ALERTA / SOBREGIRO (Naranja/Rojo)
      final baseColor = Colors.orange;
      bgColor = isDarkMode ? baseColor.withValues(alpha: 0.15) : baseColor.withValues(alpha: 0.1);
      borderColor = isDarkMode ? baseColor.withValues(alpha: 0.3) : baseColor.withValues(alpha: 0.3);
      iconColor = isDarkMode ? baseColor.shade300 : baseColor;
      titleColor = isDarkMode ? baseColor.shade200 : baseColor.shade800;
      textColor = isDarkMode ? Colors.grey.shade300 : baseColor.shade900;
    } else {
      // PALETA: USO DE AHORROS (Azul Informativo)
      final baseColor = Colors.indigo;
      bgColor = isDarkMode ? baseColor.withValues(alpha: 0.2) : baseColor.withValues(alpha: 0.1);
      borderColor = isDarkMode ? baseColor.withValues(alpha: 0.4) : baseColor.withValues(alpha: 0.3);
      // En Dark Mode 
      iconColor = isDarkMode ? baseColor.shade200 : baseColor;
      titleColor = isDarkMode ? Colors.white : baseColor; 
      textColor = isDarkMode ? Colors.grey.shade300 : baseColor.shade800;
    }

    // MENSAJE INFORMATIVO
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
            const TextSpan(text: "Este mes tus gastos superaron a tus ingresos. Has utilizado "),
            TextSpan(
              text: monthlyDeficitString, 
              style: TextStyle(fontWeight: FontWeight.bold, color: titleColor)
            ),
            const TextSpan(text: " de tu saldo acumulado para cubrirlos."),
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
            isOverdraft ? Icons.warning_amber_rounded : Icons.savings_outlined, // Icono cambia segun caso
            color: iconColor, 
            size: 26
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
                    fontSize: 14
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            searchQuery.isNotEmpty 
              ? "No se encontraron resultados"
              : "No hay registros disponibles",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}