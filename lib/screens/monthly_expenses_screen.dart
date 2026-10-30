import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart'; // Para AppColors
import '../models/transaction_model.dart';
import '../utils/math_utils.dart'; // utilidad de redondeo
import '../services/database_service.dart';
import '../utils/string_extensions.dart';
import '../widgets/monthly_report_card.dart';

class _PeriodMetrics {
  final double income;
  final double expense;
  final double balance;
  final bool isNegative;
  final List<TransactionModel> chartData;

  const _PeriodMetrics({
    required this.income,
    required this.expense,
    required this.balance,
    required this.isNegative,
    required this.chartData,
  });
}

class MonthlyExpensesScreen extends StatefulWidget {
  const MonthlyExpensesScreen({super.key});

  @override
  State<MonthlyExpensesScreen> createState() => _MonthlyExpensesScreenState();
}

class _MonthlyExpensesScreenState extends State<MonthlyExpensesScreen> {
  final DatabaseService _dbService = DatabaseService();
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  
  List<TransactionModel> _transactions = [];
  StreamSubscription<List<TransactionModel>>? _dbSubscription;

  // Filtro de período Año-Mes (primer día del mes seleccionado)
  DateTime? selectedPeriod;
  // Lista de fechas únicas (Año-Mes)
  List<DateTime> _allHistoryYearMonths = [];
  // Mapa para acceder a las transacciones de un mes instantaneamente
  final Map<String, List<TransactionModel>> _groupedTransactions = {};

  // Métricas memoizadas del período actual y meses visibles
  double _currentTotalIncome = 0.0;
  double _currentTotalExpense = 0.0;
  double _currentNetBalance = 0.0;
  bool _currentIsNegative = false;
  List<TransactionModel> _currentChartData = [];
  List<DateTime> _visibleMonths = [];
  final Map<String, _PeriodMetrics> _memoizedPeriodMetrics = {};

  late Future<double> _totalBalanceFuture; //cargar saldo total

  @override
  void initState() {
    super.initState();
    _totalBalanceFuture = _dbService.getTotalBalance();

    _dbSubscription = _dbService.listenToTransactions().listen((data) {
      if (mounted) {
        setState(() {
          _transactions = data;
          _calculateHistoryData();
          _updatePeriodMetrics();
          _totalBalanceFuture = _dbService.getTotalBalance();
        });
      }
    });
  }

  // Limpiar el controlador y la suscripción al salir para evitar fugas de memoria
  @override
  void dispose() {
    _dbSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Calculamos los datos agrupados
  void _calculateHistoryData() {
    _groupedTransactions.clear();
    final Set<String> uniqueKeys = {};
    final List<DateTime> yearMonths = [];

    // AGRUPAR TRANSACCIONES (Indexacion)
    for (var tx in _transactions) {
      // Clave única por mes
      final key = "${tx.date.year}-${tx.date.month}";
      if (!_groupedTransactions.containsKey(key)) {
        _groupedTransactions[key] = [];
      }
      // Agregamos la transacción a su mes correspondiente
      _groupedTransactions[key]!.add(tx);
      // Lista de los meses disponibles
      if (!uniqueKeys.contains(key)) {
        uniqueKeys.add(key);
        yearMonths.add(DateTime(tx.date.year, tx.date.month, 1));
      }
    }
    // Ordenar del más reciente al más antiguo
    yearMonths.sort((a, b) => b.compareTo(a));
    _allHistoryYearMonths = yearMonths;

    // Si la lista no está vacía y selectedPeriod es null, asigna el primer elemento por defecto
    if (_allHistoryYearMonths.isNotEmpty) {
      if (selectedPeriod == null ||
          !_allHistoryYearMonths.any((d) =>
              d.year == selectedPeriod!.year && d.month == selectedPeriod!.month)) {
        selectedPeriod = _allHistoryYearMonths.first;
      }
    } else {
      selectedPeriod = null;
    }
  }

  // Actualiza y memoiza las métricas del período evitando cálculos en el método build
  void _updatePeriodMetrics() {
    _memoizedPeriodMetrics.clear();

    // 1. Determinar meses candidatos según selectedPeriod
    List<DateTime> candidates;
    if (selectedPeriod != null) {
      candidates = _allHistoryYearMonths.where((date) {
        return date.year == selectedPeriod!.year && date.month == selectedPeriod!.month;
      }).toList();
    } else {
      candidates = _allHistoryYearMonths.take(4).toList();
    }

    // 2. Pre-calcular totales y filtrar transacciones por búsqueda fuera de build
    final List<DateTime> filteredVisible = [];
    final lowerQuery = searchQuery.toLowerCase();

    for (final monthDate in candidates) {
      final key = "${monthDate.year}-${monthDate.month}";
      final monthTxs = _groupedTransactions[key] ?? [];

      double inc = 0.0;
      double exp = 0.0;
      final List<TransactionModel> chartList = [];
      bool hasMatchingCategory = lowerQuery.isEmpty;

      for (final tx in monthTxs) {
        if (tx.type == TransactionType.income) {
          inc += tx.amount;
        } else {
          exp += tx.amount;
          if (lowerQuery.isEmpty || tx.categoryName.toLowerCase().contains(lowerQuery)) {
            chartList.add(tx);
          }
        }
        if (!hasMatchingCategory && tx.categoryName.toLowerCase().contains(lowerQuery)) {
          hasMatchingCategory = true;
        }
      }

      if (hasMatchingCategory) {
        filteredVisible.add(monthDate);
      }

      final roundedInc = roundAmount(inc);
      final roundedExp = roundAmount(exp);
      final roundedBal = roundAmount(roundedInc - roundedExp);

      _memoizedPeriodMetrics[key] = _PeriodMetrics(
        income: roundedInc,
        expense: roundedExp,
        balance: roundedBal,
        isNegative: roundedBal < 0,
        chartData: chartList,
      );
    }

    _visibleMonths = filteredVisible;

    // 3. Asignación a variables de estado del período seleccionado
    if (selectedPeriod != null) {
      final key = "${selectedPeriod!.year}-${selectedPeriod!.month}";
      final metrics = _memoizedPeriodMetrics[key];
      if (metrics != null) {
        _currentTotalIncome = metrics.income;
        _currentTotalExpense = metrics.expense;
        _currentNetBalance = metrics.balance;
        _currentIsNegative = metrics.isNegative;
        _currentChartData = metrics.chartData;
      } else {
        _currentTotalIncome = 0.0;
        _currentTotalExpense = 0.0;
        _currentNetBalance = 0.0;
        _currentIsNegative = false;
        _currentChartData = [];
      }
    } else if (_visibleMonths.isNotEmpty) {
      final firstKey = "${_visibleMonths.first.year}-${_visibleMonths.first.month}";
      final metrics = _memoizedPeriodMetrics[firstKey];
      if (metrics != null) {
        _currentTotalIncome = metrics.income;
        _currentTotalExpense = metrics.expense;
        _currentNetBalance = metrics.balance;
        _currentIsNegative = metrics.isNegative;
        _currentChartData = metrics.chartData;
      }
    } else {
      _currentTotalIncome = 0.0;
      _currentTotalExpense = 0.0;
      _currentNetBalance = 0.0;
      _currentIsNegative = false;
      _currentChartData = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
                              setState(() {
                                searchQuery = "";
                                _updatePeriodMetrics();
                              }); 
                            },
                          )
                        : null,
                      filled: true,
                      fillColor: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                        _updatePeriodMetrics();
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // FILTRO POR MES
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<DateTime?>(
                        value: selectedPeriod,
                        hint: Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            "Recientes (Últimos 4)",
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodyMedium?.color ??
                                  (isDarkMode ? Colors.white : Colors.black87),
                              fontSize: 15,
                            ),
                          ),
                        ),
                        isExpanded: true,
                        icon: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Theme.of(context).iconTheme.color ?? Colors.grey,
                          ),
                        ),
                        borderRadius: BorderRadius.circular(16),
                        dropdownColor: isDarkMode ? AppColors.cardDark : Colors.white,
                        menuMaxHeight: 300,
                        selectedItemBuilder: (BuildContext context) {
                          final textColor = Theme.of(context).textTheme.bodyMedium?.color ??
                              (isDarkMode ? Colors.white : Colors.black87);
                          return [
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "Recientes (Últimos 4)",
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                            ..._allHistoryYearMonths.map((period) {
                              final monthName = DateFormat("MMMM", "es").format(period).capitalize();
                              final periodName = "$monthName ${period.year}";
                              return Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    periodName,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ];
                        },
                        items: [
                          DropdownMenuItem<DateTime?>(
                            value: null,
                            child: _buildDropdownItemContent(
                              "Recientes (Últimos 4)",
                              selectedPeriod == null,
                            ),
                          ),
                          ..._allHistoryYearMonths.map((period) {
                            final monthName = DateFormat("MMMM", "es").format(period).capitalize();
                            final periodName = "$monthName ${period.year}";
                            return DropdownMenuItem<DateTime?>(
                              value: period,
                              child: _buildDropdownItemContent(
                                periodName,
                                selectedPeriod != null &&
                                    selectedPeriod!.year == period.year &&
                                    selectedPeriod!.month == period.month,
                              ),
                            );
                          }),
                        ],
                        onChanged: (newPeriod) {
                          setState(() {
                            selectedPeriod = newPeriod;
                            _updatePeriodMetrics();
                          });
                        },
                      ),
                    ),
                  )
                ],
              ),
            ),

            // LISTA DE TARJETAS (REPORTES)
            Expanded(
              child: FutureBuilder<double>(
                future: _totalBalanceFuture,
                builder: (context, snapshot) {
                  final totalHistoricalBalance = snapshot.data ?? 0.0;

                  if (_visibleMonths.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      16 + MediaQuery.paddingOf(context).bottom,
                    ),
                    itemCount: _visibleMonths.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 20),
                    itemBuilder: (_, index) {
                      final yearMonthDate = _visibleMonths[index];
                      final key = "${yearMonthDate.year}-${yearMonthDate.month}";
                      final metrics = _memoizedPeriodMetrics[key] ??
                          _PeriodMetrics(
                            income: _currentTotalIncome,
                            expense: _currentTotalExpense,
                            balance: _currentNetBalance,
                            isNegative: _currentIsNegative,
                            chartData: _currentChartData,
                          );

                      return MonthlyReportCard(
                        period: yearMonthDate,
                        totalIncome: metrics.income,
                        totalExpense: metrics.expense,
                        netBalance: metrics.balance,
                        isNegative: metrics.isNegative,
                        expenseTxsForChart: metrics.chartData,
                        totalHistoricalBalance: totalHistoricalBalance,
                        searchQuery: searchQuery,
                        initiallyExpanded: _visibleMonths.length == 1,
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

  // HELPER para diseñar el item seleccionado vs no seleccionado dentro del menu
  Widget _buildDropdownItemContent(String text, bool isSelected) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: textColor,
          fontSize: 15,
        ),
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
