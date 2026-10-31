import 'dart:async';
import 'package:finance_local/services/notification_service.dart';
import 'package:flutter/material.dart';
import '../main.dart'; // AppColors
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/reminder_model.dart';
import '../models/transaction_model.dart';
import '../utils/custom_snackbar.dart';
import '../widgets/add_transaction_modal.dart';
import '../widgets/add_reminder_modal.dart';
import '../widgets/shared_transaction_tile.dart'; // boton flotante
import '../utils/currency_format.dart';
import '../utils/period_lock_helper.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final DatabaseService _dbService = DatabaseService();
  // estado del calendario
  DateTime _focusedDay = DateTime.now(); // el mes que estamos viendo
  DateTime _selectedDay = DateTime.now(); // el dia seleccionado (click)

  // Listas completas y suscripciones
  List<TransactionModel> _allTransactions = [];
  List<ReminderModel> _allReminders = [];
  StreamSubscription<List<TransactionModel>>? _txSubscription;
  StreamSubscription<List<ReminderModel>>? _remSubscription;

  // Indices del mes actual
  Map<int, List<TransactionModel>> _monthTransactionsByDay = {};
  Map<int, List<ReminderModel>> _monthRemindersByDay = {};

  @override
  void initState() {
    super.initState();
    _txSubscription = _dbService.listenToTransactions().listen((data) {
      if (mounted) {
        setState(() {
          _allTransactions = data;
          _indexMonthData();
        });
      }
    });
    _remSubscription = _dbService.listenToReminders().listen((data) {
      if (mounted) {
        setState(() {
          _allReminders = data;
          _indexMonthData();
        });
      }
    });
  }

  @override
  void dispose() {
    _txSubscription?.cancel();
    _remSubscription?.cancel();
    super.dispose();
  }

  void _indexMonthData() {
    _monthTransactionsByDay = {};
    _monthRemindersByDay = {};

    for (final tx in _allTransactions) {
      if (tx.date.year == _focusedDay.year && tx.date.month == _focusedDay.month) {
        _monthTransactionsByDay.putIfAbsent(tx.date.day, () => []).add(tx);
      }
    }

    final daysInMonth = _getDaysInMonth(_focusedDay);
    for (final r in _allReminders) {
      if (!r.isActive) continue;
      if (r.dayOfMonth < 1 || r.dayOfMonth > daysInMonth) continue;

      final occurrenceDate = DateTime(_focusedDay.year, _focusedDay.month, r.dayOfMonth);
      final reminderStart = DateTime(r.createdAt.year, r.createdAt.month, r.createdAt.day);

      if (!occurrenceDate.isBefore(reminderStart)) {
        _monthRemindersByDay.putIfAbsent(r.dayOfMonth, () => []).add(r);
      }
    }
  }

  // NAVEGACION DE MESES
  void _previousMonth() {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
      _selectedDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
      _indexMonthData();
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
      _selectedDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
      _indexMonthData();
    });
  }

  // CALCULOS DE FECHAS 
  int _getDaysInMonth(DateTime date) => DateTime(date.year, date.month + 1, 0).day;
  // Obtiene que dia de la semana cae el 1ro del mes (1=Lunes, 7=Domingo)
  int _getFirstWeekdayOfMonth(DateTime date) => DateTime(date.year, date.month, 1).weekday;

  // ACCIONES SOBRE TRANSACCIONES
  Future<void> _handleEdit(TransactionModel tx) async {
    if (PeriodLockHelper.isPeriodLocked(tx.date)) {
      CustomSnackBar.show(
        context: context,
        message: "Periodo cerrado. No puedes editar transacciones antiguas.",
        icon: Icons.lock_rounded,
        backgroundColor: Colors.orange.shade700,
        iconColor: Colors.white,
        durationSeconds: 4,
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => AddTransactionModal(transactionToEdit: tx),
    );
  }

  Future<bool> _handleDelete(TransactionModel tx) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    if (PeriodLockHelper.isPeriodLocked(tx.date)) {
      CustomSnackBar.show(
        context: context,
        message: "Periodo cerrado. No puedes eliminar transacciones antiguas.",
        icon: Icons.lock_rounded,
        backgroundColor: Colors.orange.shade700,
        iconColor: Colors.white,
        durationSeconds: 4,
      );
      return false;
    }

    final isOld = tx.date.isBefore(DateTime.now().subtract(const Duration(days: 30)));
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isOld ? "¿Eliminar registro antiguo?" : "¿Eliminar transacción?"),
        content: Text(
          isOld
              ? "Esto modificará tu historial y saldos pasados.\n\n¿Continuar?"
              : "Esta acción no se puede deshacer.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              "Cancelar",
              style: TextStyle(color: isDarkMode ? AppColors.primary : AppColors.primaryLight),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Eliminar", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _allTransactions.removeWhere((item) => item.key == tx.key);
        _indexMonthData();
      });

      await _dbService.deleteTransaction(tx.key);

      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: "Transacción eliminada",
          icon: Icons.delete_outline_rounded,
        );
      }
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textHeaderColor = isDarkMode ? Colors.white : Colors.grey[900];
    final textSubColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    String monthTitle = DateFormat('MMMM yyyy', 'es').format(_focusedDay);
    monthTitle = monthTitle[0].toUpperCase() + monthTitle.substring(1);

    final selectedDayTxs = (_selectedDay.year == _focusedDay.year && _selectedDay.month == _focusedDay.month)
        ? (_monthTransactionsByDay[_selectedDay.day] ?? [])
        : <TransactionModel>[];
    final selectedDayRems = (_selectedDay.year == _focusedDay.year && _selectedDay.month == _focusedDay.month)
        ? (_monthRemindersByDay[_selectedDay.day] ?? [])
        : <ReminderModel>[];

    return Scaffold(
      // HEADER SUPERIOR 
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        // BOTON DE RETORNO / HOME
        leading: IconButton(
          icon: Icon(
            Navigator.canPop(context) ? Icons.arrow_back_ios_new_rounded : Icons.home_rounded, 
            color: textHeaderColor, 
            size: 24
          ),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/home'); 
            }
          },
          tooltip: "Volver",
        ),
        title: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            showDatePicker(
              context: context,
              initialDate: _focusedDay,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              initialDatePickerMode: DatePickerMode.year,
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: isDarkMode
                        ? const ColorScheme.dark(
                            primary: AppColors.primary,
                            onPrimary: Colors.black,
                            surface: AppColors.cardDark,
                            onSurface: Colors.white,
                          )
                        : ColorScheme.light(
                            primary: AppColors.primaryLight,
                            onPrimary: Colors.white,
                            surface: Colors.white,
                            onSurface: Colors.black,
                          ),
                    dialogTheme: DialogThemeData(
                      backgroundColor: isDarkMode ? AppColors.cardDark : Colors.white,
                    ),
                  ),
                  child: child!,
                );
              },
            ).then((selectedDate) {
              if (selectedDate != null) {
                setState(() {
                  _focusedDay = selectedDate;
                  _selectedDay = selectedDate;
                  _indexMonthData();
                });
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  monthTitle,
                  style: TextStyle(
                    color: textHeaderColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  color: textHeaderColor,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        // NAVEGACION DE MESES 
        actions: [
          IconButton(
            icon: Icon(Icons.chevron_left_rounded, color: textHeaderColor, size: 32),
            onPressed: _previousMonth,
            tooltip: "Mes Anterior",
          ),
          IconButton(
            icon: Icon(Icons.chevron_right_rounded, color: textHeaderColor, size: 32),
            onPressed: _nextMonth,
            tooltip: "Mes Siguiente",
          ),
        ],
      ),

      body: Column(
        children: [
          // CONTENIDO SCROLLABLE (Calendario + Lista) 
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  // DIAS DE LA SEMANA (L M M J V S D)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ["L", "M", "M", "J", "V", "S", "D"].map((day) {
                      return SizedBox(
                        width: 40, height: 40,
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              color: textSubColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  // GRILLA DEL CALENDARIO
                  _buildCalendarGrid(isDarkMode),

                  const SizedBox(height: 20),
                  // SECCION DE EVENTOS DEL DIA SELECCIONADO
                  Divider(color: isDarkMode ? Colors.white10 : Colors.grey[200]),
                  const SizedBox(height: 16),
              
                  Text(
                    "Eventos del ${DateFormat("d 'de' MMMM", 'es').format(_selectedDay)}",
                    style: TextStyle(
                      color: textHeaderColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // LISTA DE EVENTOS
                  _buildCombinedList(selectedDayTxs, selectedDayRems, isDarkMode),

                ],
              ),
            ),
          ),
        ],
      ),

      floatingActionButton: SizedBox(
        width: 56, height: 56,
        child: FloatingActionButton(
          onPressed: () => _showAddOptions(context),
          backgroundColor: isDarkMode ? AppColors.primary : AppColors.primaryLight,
          child: Icon(Icons.add_rounded, color: isDarkMode ? Colors.black : Colors.white, size: 36),
        ),
      ),
    );
  }

  // CONSTRUCCION DE LA GRILLA 
  Widget _buildCalendarGrid(bool isDarkMode) {
    final daysInMonth = _getDaysInMonth(_focusedDay);
    final firstWeekday = _getFirstWeekdayOfMonth(_focusedDay); // 1 (Lun) a 7 (Dom)
    final totalCells = daysInMonth + (firstWeekday - 1);

    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 0) {
          _previousMonth();
        } else if (velocity < 0) {
          _nextMonth();
        }
      },
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: totalCells,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemBuilder: (context, index) {
          // Dias vacios del mes anterior
          if (index < firstWeekday - 1) {
            return const SizedBox();
          }

          final dayNumber = index - (firstWeekday - 1) + 1;
          final currentDate = DateTime(_focusedDay.year, _focusedDay.month, dayNumber);
          
          // Verificar seleccion
          final isSelected = currentDate.year == _selectedDay.year &&
                             currentDate.month == _selectedDay.month &&
                             currentDate.day == _selectedDay.day;

          // Verificar si es HOY (para el fondo opaco)
          final isToday = currentDate.year == todayDateOnly.year &&
                          currentDate.month == todayDateOnly.month &&
                          currentDate.day == todayDateOnly.day;
          
          // Obtener datos del dia en O(1) desde los indices memoizados
          final dayTxs = _monthTransactionsByDay[dayNumber] ?? [];
          final dayRems = _monthRemindersByDay[dayNumber] ?? [];
          
          final hasIncome = dayTxs.any((tx) => tx.type == TransactionType.income);
          final hasExpense = dayTxs.any((tx) => tx.type == TransactionType.expense);
          final hasPendingReminder = dayRems.any((rem) =>
              !dayTxs.any((tx) => tx.title.toLowerCase().contains(rem.title.toLowerCase())));
          final hasPaidReminder = dayRems.any((rem) =>
              dayTxs.any((tx) => tx.title.toLowerCase().contains(rem.title.toLowerCase())));
          
          final selectionColor = isDarkMode ? AppColors.primary : AppColors.primaryLight;
          final selectionTextColor = isDarkMode ? Colors.black : Colors.white;
          final todayBackgroundColor = isDarkMode ? selectionColor.withOpacity(0.15) : Colors.grey.shade400;
          // Determinar el Color de Fondo
          Color? containerColor;
          if (isSelected) {
            // Si esta seleccionado, siempre usa el color primario fuerte (prioridad 1)
            containerColor = selectionColor;
          } else if (isToday) {
            // Si es hoy, pero no esta seleccionado, usa el color opaco (prioridad 2)
            containerColor = todayBackgroundColor;
          } else {
            // Ningun estilo
            containerColor = Colors.transparent;
          }
          // Determinar el Color del Texto
          Color? textColor;
          if (isSelected) {
            // Texto blanco/negro para el seleccionado
            textColor = selectionTextColor;
          } else if (isToday) {
            // Texto primario o negro para el dia de hoy
            textColor = isDarkMode ? AppColors.primary : Colors.black; 
          } else {
            // Texto normal
            textColor = isDarkMode ? Colors.white : Colors.black87;
          }

          return Material(
            color: containerColor,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(25),
              onTap: () => setState(() => _selectedDay = currentDate),
              child: Stack(
                alignment: Alignment.center,
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Text(
                      "$dayNumber",
                      style: TextStyle(
                        color: textColor,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  // INDICADORES SEMANTICOS (DOTS)
                  Positioned(
                    bottom: 6,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Punto Verde si hay ingresos
                        if (hasIncome)
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        // Punto Rojo si hay gastos
                        if (hasExpense)
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        // Punto Azul si hay recordatorio pendiente
                        if (hasPendingReminder)
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Colors.blueAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        // Punto Gris/Verde tenue si solo hay recordatorios ya pagados
                        if (!hasPendingReminder && hasPaidReminder)
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // LISTA DE EVENTOS FILTRADA 
  Widget _buildCombinedList(List<TransactionModel> dayTxs, List<ReminderModel> dayReminders, bool isDarkMode) {
    if (dayTxs.isEmpty && dayReminders.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text("Sin eventos para este día", style: TextStyle(color: Colors.grey.shade500))));
    }
    
    return Column(
      children: [
        // PRIMERO: Los Recordatorios con logica Smart Match
        ...dayReminders.map((rem) {
          //si existe alguna transaccion dia select del calendario con el nombre del recordatorio
          final isPaid = dayTxs.any((tx) => 
            tx.title.toLowerCase().contains(rem.title.toLowerCase())
          );
          return _buildReminderItem(rem, isDarkMode, isPaid);
        }),
        
        // SEGUNDO: Las Transacciones (Historial de transacciones normales interactivo)
        ...dayTxs.map(
          (tx) => SharedTransactionTile(
            transaction: tx,
            onEdit: () => _handleEdit(tx),
            onDelete: (direction) => _handleDelete(tx),
          ),
        ),
      ],
    );
  }

  //RECORDATORIO INTELIGENTE
  Widget _buildReminderItem(ReminderModel rem, bool isDarkMode, bool isPaid) {
    // Colores segun estado
    final bgColor = isPaid 
        ? (isDarkMode ? Colors.green.withValues(alpha: 0.1) : Colors.green.shade50)
        : (isDarkMode ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.shade50);

    final accentColor = isPaid ? Colors.green : Colors.blueAccent;
    final icon = isPaid ? Icons.check_circle_rounded : IconData(rem.iconCode, fontFamily: 'MaterialIcons');
    // CAMBIO DE COLORES DEL BOTON
    final buttonColor = isDarkMode ? AppColors.primary : AppColors.primaryLight;
    final buttonTextColor = isDarkMode ? Colors.black : Colors.white;

    // Se asegura de ponerle un '0' a la izquierda si es un solo digito (ej: 9 -> 09)
    final timeText = "${rem.hour.toString().padLeft(2, '0')}:${rem.minute.toString().padLeft(2, '0')}";
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3))
      ),
      child: Column(
        children: [
          Row(
            children: [
              //icono
              Icon(icon, color: accentColor, size: 24),
              const SizedBox(width: 16),
              //texto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rem.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDarkMode ? Colors.white : Colors.black87)),
                    Text(
                      isPaid ? "Pagado hoy" : "Suscripción Mensual• $timeText", 
                      style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
              ),
              //Monto
              Text(CurrencyFormat.format(rem.amount), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: accentColor)),
            ],
          ),
          // BOTONES DE ACCION (Solo si NO esta pagado)
          if (!isPaid) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Boton Dar de Baja (Discreto)
                TextButton.icon(
                  onPressed: () => _confirmCancelSubscription(rem),
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                  label: const Text("Dar de baja", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                ),

                // Boton PAGAR (con confirmacion flexible para pagos anticipados)
                ElevatedButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final selectedDateOnly = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);

                    // Si la fecha seleccionada es posterior a hoy, advertimos pero permitimos confirmar
                    if (selectedDateOnly.isAfter(today)) {
                      final bool? proceed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Row(
                            children: [
                              Icon(Icons.schedule_send_rounded, color: Colors.orange),
                              SizedBox(width: 10),
                              Text("Pago Anticipado"),
                            ],
                          ),
                          content: const Text(
                            "Estás a punto de registrar un pago para una fecha futura.\n\n¿Deseas continuar y registrar el movimiento?",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(
                                "Cancelar",
                                style: TextStyle(color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(
                                "Sí, continuar",
                                style: TextStyle(
                                  color: isDarkMode ? AppColors.primary : AppColors.primaryLight,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (proceed != true) return;
                    }

                    if (!mounted) return;

                    // ABRIR MODAL PRE-LLENADO
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                      builder: (context) {
                        return AddTransactionModal(
                          initialTitle: rem.title,
                          initialAmount: rem.amount,
                          initialCategoryIcon: rem.iconCode, 
                          initialDate: _selectedDay,
                        );
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: buttonTextColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                  ),
                  icon: const Icon(Icons.payments_rounded, size: 16),
                  label: const Text("Registrar Pago"),
                )
              ],
            )
          ]
        ],
      ),
    );
  }

  // DIALOGO PARA DAR DE BAJA
  void _confirmCancelSubscription(ReminderModel rem) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Dar de baja?"),
        content: Text("¿Quieres eliminar la suscripción de '${rem.title}'? \n\nDejarás de recibir recordatorios mensuales."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("No", style: TextStyle(color: isDarkMode ? AppColors.primary : AppColors.primaryLight),)),
          TextButton(
            onPressed: () async {
              await _dbService.toggleReminderStatus(rem.key, false);
              await NotificationService().cancelNotification(rem.key);
              if (mounted) {
                // ignore: use_build_context_synchronously
                Navigator.pop(ctx);
                CustomSnackBar.show(
                  context: context,
                  message: "Suscripción cancelada",
                  icon: Icons.notifications_off_rounded,
                  // Puedes dejar que tome los colores por defecto o forzar los grises
                  backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade600,
                  iconColor: Colors.white,
                );
              }
            }, 
            child: const Text("Sí, Eliminar", style: TextStyle(color: Colors.red))
          ),
        ],
      )
    );
  }

  // MENU FLOTANTE
  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final cardColor = Theme.of(context).colorScheme.surfaceContainerHighest;
        final textColor = isDarkMode ? Colors.white : Colors.black87;
        final subtextColor = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;

        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle (pildora gris centrada)
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Opcion 1: Nueva Transaccion
                Card(
                  elevation: 0,
                  color: cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => const AddTransactionModal(),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: Colors.green,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Nueva Transacción",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Anotar un ingreso o gasto realizado",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: subtextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: subtextColor,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Opcion 2: Nuevo Recordatorio
                Card(
                  elevation: 0,
                  color: cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => AddReminderModal(initialDay: _selectedDay.day),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.alarm_add_rounded,
                              color: Colors.blueAccent,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Nuevo Recordatorio",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Crear alerta para pagos futuros",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: subtextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: subtextColor,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }
}
