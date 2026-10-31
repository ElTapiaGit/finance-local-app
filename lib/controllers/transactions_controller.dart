import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';

class TransactionsController extends ChangeNotifier {
  final DatabaseService _dbService;

  // Suscripcion a la base de datos reactiva
  StreamSubscription<List<TransactionModel>>? _dbSubscription;

  // Formateadores de fecha para agrupacion
  static final DateFormat _dayFormat = DateFormat("d 'de' MMMM", 'es');
  static final DateFormat _fullDateFormat = DateFormat("d 'de' MMMM 'de' yyyy", 'es');

  // Estado de transacciones y paginacion
  List<TransactionModel> _transactions = [];
  List<dynamic> _groupedTransactions = [];
  bool _isLoading = false;
  bool _hasMoreData = true;
  int _currentOffset = 0;
  final int _limit = 20;

  // Estado de filtros
  String _searchText = "";
  DateTime? _filterDate;
  String _filterMode = 'month';
  Timer? _debounceTimer;

  TransactionsController({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService();

  // Getters publicos
  List<TransactionModel> get transactions => _transactions;
  List<dynamic> get groupedTransactions => _groupedTransactions;
  bool get isLoading => _isLoading;
  bool get hasMoreData => _hasMoreData;
  String get searchText => _searchText;
  DateTime? get filterDate => _filterDate;
  String get filterMode => _filterMode;
  bool get isFiltering => _searchText.isNotEmpty || _filterDate != null;

  // Inicializacion del controlador
  void init() {
    loadMoreData();

    _dbSubscription = _dbService.listenToTransactions().listen((_) {
      resetAndReload(silent: true);
    });
  }

  // Carga de datos paginados o filtrados
  Future<void> loadMoreData({bool force = false}) async {
    if (_isLoading && !force) return;

    if (!_isLoading) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      // Modo filtrado en memoria
      if (_searchText.isNotEmpty || _filterDate != null) {
        final allData = await _dbService.getAllTransactions();
        allData.sort((a, b) => b.date.compareTo(a.date));

        final filtered = _filterTransactionsInPlace(allData);

        _transactions = filtered;
        _groupedTransactions = _groupTransactionsByDate(_transactions);
        _hasMoreData = false;
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Modo paginado
      final newItems = await _dbService.getTransactionsPaginated(
        offset: _currentOffset,
        limit: _limit,
      );

      if (newItems.length < _limit) {
        _hasMoreData = false;
      }
      _transactions.addAll(newItems);
      _groupedTransactions = _groupTransactionsByDate(_transactions);
      _currentOffset += newItems.length;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Filtrado de transacciones segun texto y fecha
  List<TransactionModel> _filterTransactionsInPlace(List<TransactionModel> sortedData) {
    return sortedData.where((tx) {
      final matchesText = _searchText.isEmpty ||
          tx.title.toLowerCase().contains(_searchText) ||
          tx.categoryName.toLowerCase().contains(_searchText);

      bool matchesDate = true;
      if (_filterDate != null) {
        if (_filterMode == 'day') {
          matchesDate = tx.date.year == _filterDate!.year &&
              tx.date.month == _filterDate!.month &&
              tx.date.day == _filterDate!.day;
        } else {
          matchesDate = tx.date.year == _filterDate!.year &&
              tx.date.month == _filterDate!.month;
        }
      }
      return matchesText && matchesDate;
    }).toList();
  }

  // Reiniciar lista y recargar
  void resetAndReload({bool silent = false}) {
    _transactions.clear();
    _groupedTransactions.clear();
    _currentOffset = 0;
    _hasMoreData = !isFiltering;
    if (!silent) _isLoading = true;
    notifyListeners();

    loadMoreData(force: true);
  }

  // Busqueda con debounce
  void setSearchText(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchText = value.toLowerCase();
      resetAndReload();
    });
  }

  // Actualizar fecha de filtro
  void setFilterDate(DateTime? date) {
    _filterDate = date;
    _filterMode = 'month';
    resetAndReload();
  }

  // Actualizar modo de filtro (mes/dia)
  void setFilterMode(String mode) {
    _filterMode = mode;
    resetAndReload();
  }

  // Limpiar todos los filtros
  void clearFilters() {
    _searchText = "";
    _filterDate = null;
    _filterMode = 'month';
    resetAndReload();
  }

  // Remocion sincronizada en memoria y base de datos
  Future<void> deleteTransaction(dynamic key) async {
    _dbSubscription?.pause();

    _transactions.removeWhere((item) => item.key == key);
    _groupedTransactions = _groupTransactionsByDate(_transactions);
    notifyListeners();

    await _dbService.deleteTransaction(key);

    Future.delayed(const Duration(milliseconds: 500), () {
      _dbSubscription?.resume();
    });
  }

  // Obtener todas las transacciones para exportacion
  Future<List<TransactionModel>> getAllTransactions() async {
    return await _dbService.getAllTransactions();
  }

  // Agrupacion cronologica por etiquetas relativas
  List<dynamic> _groupTransactionsByDate(List<TransactionModel> transactions) {
    final List<dynamic> grouped = [];
    String? lastDateLabel;

    for (var tx in transactions) {
      final dateLabel = _getDateLabel(tx.date);
      if (dateLabel != lastDateLabel) {
        grouped.add(dateLabel);
        lastDateLabel = dateLabel;
      }
      grouped.add(tx);
    }
    return grouped;
  }

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);

    if (checkDate == today) return "Hoy";
    if (checkDate == yesterday) return "Ayer";
    if (date.year == now.year) {
      return _dayFormat.format(date);
    } else {
      return _fullDateFormat.format(date);
    }
  }

  @override
  void dispose() {
    _dbSubscription?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }
}

