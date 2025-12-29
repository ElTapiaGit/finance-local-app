import 'package:finance_local/services/notification_service.dart';
import 'package:flutter/material.dart';
import '../main.dart'; // AppColors
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/reminder_model.dart';
import '../models/transaction_model.dart';
import '../widgets/add_transaction_modal.dart';
import '../widgets/add_reminder_modal.dart'; // boton flotante
import '../utils/currency_format.dart';

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

  // NAVEGACION DE MESES
  void _previousMonth() => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1));
  void _nextMonth() => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1));

  // CALCULOS DE FECHAS 
  int _getDaysInMonth(DateTime date) => DateTime(date.year, date.month + 1, 0).day;
  // Obtiene que dia de la semana cae el 1ro del mes (1=Lunes, 7=Domingo)
  int _getFirstWeekdayOfMonth(DateTime date) => DateTime(date.year, date.month, 1).weekday;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textHeaderColor = isDarkMode ? Colors.white : Colors.grey[900];
    final textSubColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    String monthTitle = DateFormat('MMMM yyyy', 'es').format(_focusedDay);
    monthTitle = monthTitle[0].toUpperCase() + monthTitle.substring(1);

    return StreamBuilder<List<TransactionModel>>(
      stream: _dbService.listenToTransactions(),
      builder: (context, snapshotTx) {
        final transactions = snapshotTx.data ?? [];
        return StreamBuilder<List<ReminderModel>>(
          stream: _dbService.listenToReminders(),
          builder: (context, snapshotRem) {
            final reminders = snapshotRem.data ?? [];
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
                title: Text(
                  monthTitle,
                  style: TextStyle(
                    color: textHeaderColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
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
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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

                          //GRILLA DEL CALENDARIO
                          _buildCalendarGrid(transactions, reminders, isDarkMode),

                          const SizedBox(height: 20),
                          //SECCION DE EVENTOS DEL DIA SELECCIONADO
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
                          _buildCombinedList(transactions, reminders, isDarkMode),
                          const SizedBox(height: 80),
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
        );
      }
    );
  }

  // CONSTRUCCION DE LA GRILLA 
  Widget _buildCalendarGrid(List<TransactionModel> txs, List<ReminderModel> reminders, bool isDarkMode) {
    final daysInMonth = _getDaysInMonth(_focusedDay);
    final firstWeekday = _getFirstWeekdayOfMonth(_focusedDay); // 1 (Lun) a 7 (Dom)
    final totalCells = daysInMonth + (firstWeekday - 1);

    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);

    return GridView.builder(
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
        
        // verificar si hay transacciones en este dia para poner puntitos
        bool hasTx = txs.any((tx) => tx.date.year == currentDate.year && tx.date.month == currentDate.month && tx.date.day == currentDate.day);
        // Verificar recordatorios, PERO SOLO SI LA FECHA ACTUAL ES POSTERIOR A LA CREACIÓN
        bool hasReminder = reminders.any((r) {
          bool matchDay = r.dayOfMonth == dayNumber && r.isActive;
          if (!matchDay) return false;

          // Normalizamos fechas para comparar sin horas
          final reminderStart = DateTime(r.createdAt.year, r.createdAt.month, r.createdAt.day);
          
          // La celda actual no debe ser anterior a la fecha de creacion del recordatorio
          return !currentDate.isBefore(reminderStart);
        });
        
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

        return GestureDetector(
          onTap: () => setState(() => _selectedDay = currentDate),
          child: Container(
            decoration: BoxDecoration(
              color: containerColor, 
              shape: BoxShape.circle
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text("$dayNumber", style: TextStyle(color: textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                // INDICADORES (DOTS)
                Positioned(
                  bottom: 6,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Punto Verde/Rojo si hay transacciones (Historial)
                      if (hasTx) Container(margin: const EdgeInsets.symmetric(horizontal: 1), width: 5, height: 5, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                      // Punto AZUL si hay un recordatorio (Futuro/Recurrente)
                      if (hasReminder) Container(margin: const EdgeInsets.symmetric(horizontal: 1), width: 5, height: 5, decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle)),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // LISTA DE EVENTOS FILTRADA 
  Widget _buildCombinedList(List<TransactionModel> txs, List<ReminderModel> reminders, bool isDarkMode) {
    // Filtrar solo las del dia seleccionado
    final dayTxs = txs.where((tx) =>
      tx.date.year == _selectedDay.year && 
      tx.date.month == _selectedDay.month && 
      tx.date.day == _selectedDay.day
    ).toList();
    // Filtrar Recordatorios que caen en este dia
    final dayReminders = reminders.where((r) {
      // Coincide el dia
      bool matchDay = r.dayOfMonth == _selectedDay.day && r.isActive;
      if (!matchDay) return false;
      //validar
      final reminderStart = DateTime(r.createdAt.year, r.createdAt.month, r.createdAt.day);
      final viewDate = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);

      // Solo mostrar si la fecha que veo es igual o posterior a la creacion
      return !viewDate.isBefore(reminderStart);
    }).toList();

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
        
        // SEGUNDO: Las Transacciones (Historial de transacciones normales)
        ...dayTxs.map((tx) => _buildTransactionItem(tx, isDarkMode)),
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
                      isPaid ? "Pagado hoy" : "Suscripción Mensual", 
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

                // Boton PAGAR 
                ElevatedButton.icon(
                  onPressed: () {
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final selectedDateOnly = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
                    // Si la fecha seleccionada es DESPUES de hoy, bloqueamos.
                    if (selectedDateOnly.isAfter(today)) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Row(children: [Icon(Icons.history_toggle_off, color: Colors.orange), SizedBox(width: 10), Text("¡Espera!")]),
                          content: const Text("No puedes registrar un pago de una fecha futura.\n\nEspera a que llegue el día para realizar el pago."),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Entendido", style: TextStyle(color: isDarkMode ? AppColors.primary : AppColors.primaryLight),))
                          ],
                        ),
                      );
                      return; //Detenemos la funcion
                    }
                    // ABRIR MODAL PRE-LLENADO
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                      builder: (context) {
                       //Pasaremos un "template" al modal
                        return AddTransactionModal(
                          initialTitle: rem.title,
                          initialAmount: rem.amount,
                          initialCategoryIcon: rem.iconCode, 
                          initialDate: _selectedDay,
                        );
                      } 
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
    final snackBarColor = isDarkMode ? AppColors.primary : AppColors.primaryLight.withValues(alpha: 0.9);
    final snackBarTextColor = isDarkMode ? const Color(0xFF141212) : Colors.white;
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Suscripción cancelada", style: TextStyle(color: snackBarTextColor, fontWeight: FontWeight.bold)),
                    backgroundColor: snackBarColor, behavior: SnackBarBehavior.floating,
                  )
                );
              }
            }, 
            child: const Text("Sí, Eliminar", style: TextStyle(color: Colors.red))
          ),
        ],
      )
    );
  }

  Widget _buildTransactionItem(TransactionModel tx, bool isDarkMode) {
    final isIncome = tx.type == TransactionType.income;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),

      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12)
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: Color(tx.categoryColor).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
            child: Icon(IconData(tx.categoryIconCode, fontFamily: 'MaterialIcons'), color: Color(tx.categoryColor), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDarkMode ? Colors.white : Colors.black87)),
                Text(DateFormat('HH:mm').format(tx.date), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          Text("${isIncome ? '+' : '-'} ${CurrencyFormat.format(tx.amount)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isIncome ? Colors.green : Colors.red.shade400)),
        ],
      ),
    );
  }

  // MENU FLOTANTE
  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 200,
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha:  0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.receipt_long, color: Colors.green),
                ),
                title: const Text("Registrar Movimiento", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Anotar un ingreso o gasto realizado"),
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const AddTransactionModal());
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha:  0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.alarm_add_rounded, color: Colors.blueAccent),
                ),
                title: const Text("Programar Recordatorio", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Crear alerta para pagos futuros"),
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => AddReminderModal(initialDay: _selectedDay.day));
                },
              ),
            ],
          ),
        );
      }
    );
  }
}