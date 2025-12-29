import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Para fechas
import '../main.dart'; 
import '../services/database_service.dart';
import '../models/transaction_model.dart';
import '../widgets/add_transaction_modal.dart';
import '../utils/currency_format.dart';

class TransactionsScreen extends StatefulWidget {
  final bool isTab;
  const TransactionsScreen({super.key, this.isTab = false});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController(); // DETECTOR DE SCROLL
  //SUBSCRIPCION 
  StreamSubscription<List<TransactionModel>>? _dbSubscription;
  // FORMATEADORES ESTATICOS
  static final DateFormat _dayFormat = DateFormat("d 'de' MMMM", 'es');
  static final DateFormat _fullDateFormat = DateFormat("d 'de' MMMM 'de' yyyy", 'es');
  static final DateFormat _chipDayFormat = DateFormat('dd', 'es');
  static final DateFormat _chipMonthFormat = DateFormat('MMMM', 'es');
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  // ESTADO DE PAGINACION 
  List<TransactionModel> _transactions = []; 
  bool _isLoading = false;
  bool _hasMoreData = true; //vwrifica si aun hay datos en bd
  int _currentOffset = 0;
  final int _limit = 20; 
  //estado para filtros
  String _searchText = "";
  DateTime? _filterDate;
  String _filterMode = 'month';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadMoreData(); 
    
    //ESCUCHA CAMBIOS EN LA BD
    _dbSubscription = _dbService.listenToTransactions().listen((fullList) {
      // Cuando la DB cambia (insert, update, delete), el Stream emite la lista completa
      if (mounted) {
        _resetAndReload(silent: true);
      }
    });
    // Escuchar el scroll para paginacion
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoading && _hasMoreData) {
          _loadMoreData();
        }
      }
    });
  }

  @override
  void dispose() { //cancelamos todo cuando salga de la visa
    _dbSubscription?.cancel();
    _dbSubscription?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // CARGA DE DATOS
  Future<void> _loadMoreData({bool force = false}) async {
    if (_isLoading && !force) return;

    if (!_isLoading) {
      setState(() => _isLoading = true);
    }

    try {
      // MODO FILTRADO 
      if (_searchText.isNotEmpty || _filterDate != null) {
        final allData = await _dbService.getAllTransactions();
        allData.sort((a, b) => b.date.compareTo(a.date));

        final filtered = _filterTransactionsInPlace(allData);

        if (mounted) {
          setState(() {
            _transactions = filtered;
            _hasMoreData = false; 
            _isLoading = false; 
          });
        }
        return;
      }

      // MODO PAGINADO
      List<TransactionModel> newItems = await _dbService.getTransactionsPaginated(
        offset: _currentOffset, 
        limit: _limit
      );
      
      if (mounted) {
        setState(() {
          if (newItems.length < _limit) {
            _hasMoreData = false; 
          }
          _transactions.addAll(newItems);
          _currentOffset += newItems.length;
          _isLoading = false; 
        });
      }
    } catch (e) {
      // Si ocurre un error, evitamos infinite loading
      //debugPrint("Error cargando datos: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

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

  // REINICIAR LISTA (Al aplicar filtros o actualizar)
  void _resetAndReload({bool silent = false}) {
    if (!mounted) return;
    
    setState(() {
      _transactions.clear();
      _currentOffset = 0;
      final bool isFiltering = _searchText.isNotEmpty || _filterDate != null;
      _hasMoreData = !isFiltering;
      if (!silent) _isLoading = true; 
    });
    // Llamamos a loadMoreData. Si hay filtros activos, loadMoreData llama a applyFilters.
    _loadMoreData(force: true);
  }

  Future<void> _handleEdit(TransactionModel tx) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => AddTransactionModal(transactionToEdit: tx),
    );
    // Nota: No necesitamos llamar _resetAndReload() aquí manualmente
    // porque el _dbSubscription detectará el cambio en la BD y recargará solo.
  }

  Future<bool> _handleDelete(TransactionModel tx) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    if (_isPeriodLocked(tx.date)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Periodo cerrado. No puedes eliminar transacciones antiguas."),
          backgroundColor: Colors.orange,
        ),
      );
      return false; 
    }

    final isOld = tx.date.isBefore(DateTime.now().subtract(const Duration(days: 30)));
    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isOld ? "¿Eliminar registro antiguo?" : "¿Eliminar transacción?"),
        content: Text(isOld 
            ? "Esto modificará tu historial y saldos pasados.\n\n¿Continuar?" 
            : "Esta acción no se puede deshacer."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("Cancelar", style: TextStyle(color: isDarkMode ? AppColors.primary : AppColors.primaryLight),)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Eliminar", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirm == true) {
      //TRUCO PARA EVITAR DOBLE SALTO
      _dbSubscription?.pause();

      setState(() {
        _transactions.removeWhere((item) => item.key == tx.key);
      });

      await _dbService.deleteTransaction(tx.key);

      // Reanudamos la escucha despues de un momento
      Future.delayed(const Duration(milliseconds: 500), () {
        _dbSubscription?.resume();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Transacción eliminada"), duration: Duration(seconds: 2))
        );
      }
      return true;
    }
    return false;
  }

  //candado 
  bool _isPeriodLocked(DateTime transactionDate) {
    final now = DateTime.now();
    //si es el mismo mes y año actual, no bloquea
    if (transactionDate.year == now.year && transactionDate.month == now.month) {
      return false;
    }
    //si es de mes pasado verificar dia de gracia 3
    if (now.day >= 4) {
      return true; //bloqueo
    }
    // estar en los dias de gracia
    return false; //permitir editar
  }

  // UI HERPERS
  // funcion para abrir el selector de fecha para el filtro
  Future<void> _selectDate() async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final calendarColor = isDarkMode ? AppColors.primary : AppColors.primaryLight;

    final DateTime? picked = await showDatePicker(
      context: context,
      locale: const Locale('es', 'ES'), 
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: "SELECCIONA FECHA DE FILTRO",
      // Textos manuales por si acaso
      cancelText: "CANCELAR",
      confirmText: "ACEPTAR",
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDarkMode
              ? ColorScheme.dark(
                  primary: AppColors.primary, // Circulo de seleccion
                  onPrimary: Colors.black,    // Texto dentro del circulo
                  surface: AppColors.cardDark, // Fondo del calendario
                  onSurface: Colors.white,    // Texto de los dias
                )
              : ColorScheme.light(
                  primary: calendarColor,    
                  onPrimary: Colors.white,    
                  surface: Colors.white,
                  onSurface: Colors.black,
                ), dialogTheme: DialogThemeData(backgroundColor: isDarkMode ? AppColors.cardDark : Colors.white),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      // Preguntamos al usuario como quiere filtrar (Dia exacto o Mes completo)
      // O simplemente por defecto asumimos Mes, o cambiamos logica. mostrando un selector
      setState(() {
         _filterDate = picked;
         // Por defecto filtramos por MES al seleccionar fecha
         _filterMode = 'month'; 
      });
      _resetAndReload();
    }
  }

  // Limpiar filtros
  void _clearFilters() {
    setState(() {
      _searchText = "";
      _searchController.clear();
      _filterDate = null;
      _filterMode = 'month';
    });
    FocusScope.of(context).unfocus(); // Cerrar teclado
    _resetAndReload(); // Volver a modo paginado
  }

  // LOGICA DE AGRUPACION
  List<dynamic> _groupTransactionsByDate(List<TransactionModel> transactions) {
    final List<dynamic> grouped = [];
    String? lastDateLabel;

    for (var tx in transactions) {
      final dateLabel = _getDateLabel(tx.date);
      // Si la fecha cambia, insertamos una cabecera
      if (dateLabel != lastDateLabel) {
        grouped.add(dateLabel);
        lastDateLabel = dateLabel;
      }
      // Insertamos la transacciOn
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
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final activeCalendarColor = isDarkMode ? AppColors.primary : AppColors.primary.withValues(alpha: 0.4);
    final groupedItems = _groupTransactionsByDate(_transactions);
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: widget.isTab
            ? null // Si es Tab, no mostramos boton de atras
            : IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, 
                  color: isDarkMode ? Colors.white : Colors.black87
                ),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          "Transacciones",
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          // boton para limpiar filtros si hay alguno activo
          if (_searchText.isNotEmpty || _filterDate != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off_rounded, color: Colors.grey),
              onPressed: _clearFilters,
              tooltip: "Limpiar filtros",
            )
        ],
      ),
      body: Column(
        children: [
          // ZONA DE BUSQUEDA / FILTRO 
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Column(
              children: [
                //fila buscar y calendario
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) { //solo recargar al dar Enter o tras escribir
                            if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
                            _debounceTimer = Timer(const Duration(milliseconds: 500), () { 
                              setState(() => _searchText = value.toLowerCase());
                              _resetAndReload(); 
                            });
                          },
                          decoration: InputDecoration(
                            hintText: "Buscar transacción...",
                            prefixIcon: const Icon(Icons.search, color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 15),
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // boton calendario
                    InkWell(
                      onTap: _selectDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: _filterDate != null 
                              ? activeCalendarColor 
                              : (isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(12),
                          border: _filterDate != null 
                              ? Border.all(color: AppColors.primary) 
                              : null
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_month_rounded, 
                              color: _filterDate != null 
                                ? Colors.black 
                                : Colors.grey,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // Si hay fecha seleccionada, mostramos los toggles de MES/DIA
                if (_filterDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Row(
                      children: [
                         // CHIP: MES COMPLETO
                         _buildFilterChip(
                           label: "Mes: ${_chipMonthFormat.format(_filterDate!)}", 
                           isActive: _filterMode == 'month',
                           onTap: () {
                             setState(() => _filterMode = 'month');
                             _resetAndReload();
                           }
                         ),
                         const SizedBox(width: 10),
                         // CHIP: DIA EXACTO
                         _buildFilterChip(
                           label: "Día: ${_chipDayFormat.format(_filterDate!)}", 
                           isActive: _filterMode == 'day',
                           onTap: () {
                             setState(() => _filterMode = 'day');
                             _resetAndReload();
                           }
                         ),
                      ],
                    ),
                  )
              ],
            ),
          ),

          // LISTA DE TRANSACCIONES
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _resetAndReload(),
              child: Builder(
                builder: (context) {
                  // Si no carga y la lista esta vacia -> Empty State
                  if (_transactions.isEmpty && !_isLoading) {
                    return _buildEmptyState();
                  }

                  if (_isLoading && _transactions.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  // Lista con Datos
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    // +1 para el indicador de carga al final
                    itemCount: groupedItems.length + (_hasMoreData ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Si llegamos al final y hay mas datos, mostramos loader
                      if (index == groupedItems.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final item = groupedItems[index];

                      if (item is String) {
                        return _buildDateHeader(context, item);
                      } else if (item is TransactionModel) {
                        return _buildTransactionItem(context, item);
                      }
                      return const SizedBox();
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET CHIP DE FILTRO
  Widget _buildFilterChip({required String label, required bool isActive, required VoidCallback onTap}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDarkMode ? AppColors.primary : AppColors.primary.withValues(alpha: 0.4);
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? activeColor : Colors.grey.shade400
          )
        ),
        child: Text(
          label, 
          style: TextStyle(
            color: isActive ? Colors.black : Colors.grey.shade600,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 12
          )
        ),
      ),
    );
  }

  // WIDGETS cuando no hay transacciones
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: 400,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text("No se encontraron resultados", style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  // Widget para el titulo de la fecha (Header)
  Widget _buildDateHeader(BuildContext context, String date) { 
    final isDarkMode = Theme.of(context).brightness == Brightness.dark; 
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 0, 8),
      child: Text(
        date,
        style: TextStyle(
          color: isDarkMode 
              ? AppColors.primary.withValues(alpha: 0.8) 
              : AppColors.primaryLight,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Widget de Item de Transaccion con Swipe (Dismissible)
  Widget _buildTransactionItem(BuildContext context, TransactionModel tx) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isIncome = tx.type == TransactionType.income;
    final color = Color(tx.categoryColor);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Dismissible(
        key: Key(tx.key.toString()),
        direction: DismissDirection.horizontal, // Permitimos swipe a ambos lados
        // (SWIPE DERECHA -> EDITAR)
        background: Container( //fondo de SWIPE
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.edit, color: Colors.white),
              Text("Editar", style: TextStyle(color: Colors.white, fontSize: 10))
            ],
          ),
        ),
        // SWIPE IZQUIERDA -> ELIMINAR
        secondaryBackground: Container(
          decoration: BoxDecoration(
            color: Colors.red.shade600,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete, color: Colors.white),
              Text("Eliminar", style: TextStyle(color: Colors.white, fontSize: 10))
            ],
          ),
        ),
        // LOGICA DE SWIPE
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            _handleEdit(tx);
            return false; 
          } else {
            return await _handleDelete(tx);
          }
        },
        // CONTENIDO DEL CARD 
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1a3824).withValues(alpha: 0.5) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            // Sombra suave solo en modo claro
            boxShadow: isDarkMode ? [] : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ]
          ),
          child: Row(
            children: [
              // Icono
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(IconData(tx.categoryIconCode, fontFamily: 'MaterialIcons'), color: color, size: 24),
              ),
              const SizedBox(width: 16),
              // Textos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      // mostramos metodo de Pago y Hora
                      "${tx.paymentMethod} • ${_timeFormat.format(tx.date)}",
                      style: TextStyle(
                        color: isDarkMode ? AppColors.textGrayLight : Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Monto
              Text(
                "${isIncome ? '+' : '-'} ${CurrencyFormat.format(tx.amount)}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isIncome 
                    ? (isDarkMode ? AppColors.primary : Colors.green.shade700)
                    : (isDarkMode ? Colors.red.shade400 : Colors.red.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}