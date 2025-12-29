import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction_model.dart';
import '../models/reminder_model.dart';
import '../utils/math_utils.dart';

class DatabaseService {
  // PATRON SINGLETON
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Box<TransactionModel> get transactionBox => Hive.box<TransactionModel>('transactions');
  Box<ReminderModel> get reminderBox => Hive.box<ReminderModel>('reminders');

  // INICIALIZACION: solo registra adaptadores y abre las cajas
  Future<void> init() async {
    if (Hive.isBoxOpen('transactions')) {
      return;
    }

    // Registrar Adaptadores generados por build_runner
    Hive.registerAdapter(TransactionModelAdapter());
    Hive.registerAdapter(TransactionTypeAdapter()); 
    Hive.registerAdapter(ReminderModelAdapter());

    // Abrir todas las cajas (Boxes)
    await Hive.openBox<TransactionModel>('transactions');
    await Hive.openBox<ReminderModel>('reminders');
  }

  // METODOS PARA TRANSACCIONES 

  // FUNCION PARA GUARDAR TRANSACCION
  Future<void> saveTransaction({
    required String title,
    required double amount,
    required bool isExpense,
    required String paymentMethod,
    required DateTime date,
    required String categoryName,
    required int categoryColor,
    required int categoryIcon,
  }) async {
    final cleanAmount = roundAmount(amount);
    final newTx = TransactionModel()
      ..title = title
      ..amount = cleanAmount
      ..type = isExpense ? TransactionType.expense : TransactionType.income
      ..paymentMethod = paymentMethod
      ..date = date
      ..categoryName = categoryName
      ..categoryColor = categoryColor
      ..categoryIconCode = categoryIcon;


    await transactionBox.add(newTx); 
  }

  // FUNCION PARA ESCUCHAR TODAS LAS TRANSACCIONES (Para el Home)
  Stream<List<TransactionModel>> listenToTransactions() {
    // Creamos un ValueListenable, que Hive proporciona para escuchar cambios.
    final controller = StreamController<List<TransactionModel>>();

    void updateListener() {
      // Logica de obtencion y ordenacion de la lista
      final list = transactionBox.values.toList();
      list.sort((a, b) => b.date.compareTo(a.date));

      controller.add(list);
    }
    
    updateListener(); 

    // ESCUCHA DE CAMBIOS
    transactionBox.listenable().addListener(updateListener);

    // para evitar fugas de memoria
    controller.onCancel = () {
      transactionBox.listenable().removeListener(updateListener);
      controller.close();
    };

    return controller.stream.asBroadcastStream();

  }

  // CALCULAR SALDO TOTAL HISTORICO
  Future<double> getTotalBalance() async {
    final transactions = transactionBox.values.toList();
    
    final totalIncome = transactions
        .where((tx) => tx.type == TransactionType.income)
        .fold(0.0, (sum, tx) => sum + tx.amount);

    final totalExpense = transactions
      .where((tx) => tx.type == TransactionType.expense)
      .fold(0.0, (sum, tx) => sum + tx.amount);

    return totalIncome - totalExpense;
  }

  // PARA LISTA DE TRANSACCIONES con paginacion de 20
  Future<List<TransactionModel>> getTransactionsPaginated({required int offset, int limit = 20}) async {
    final allTransactions = transactionBox.values.toList();
    
    // Ordenar primero (descendente)
    allTransactions.sort((a, b) => b.date.compareTo(a.date));

    // Aplicar paginación manualmente
    final end = (offset + limit) > allTransactions.length 
        ? allTransactions.length 
        : (offset + limit);
        
    if (offset >= allTransactions.length) {
      return [];
    }

    return allTransactions.sublist(offset, end);
  }

  // Obtener todo el historial de una (Para filtros y busquedas)
  Future<List<TransactionModel>> getAllTransactions() async {
    final list = transactionBox.values.toList();
    // Ordenar por fecha descendente 
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  // ELIMINAR TRANSACCION (Usando el ID/Key de Hive)
  Future<void> deleteTransaction(int key) async {
    await transactionBox.delete(key); 
  }

  // METODOS PARA RECORDATORIOS 
  Future<int> saveReminderAndReturnId({
    required String title,
    required double amount,
    required int dayOfMonth,
    required int color,
    required int icon,
  }) async {
    final reminder = ReminderModel()
      ..title = title
      ..amount = amount
      ..dayOfMonth = dayOfMonth
      ..isActive = true
      ..colorValue = color
      ..iconCode = icon;

    return await reminderBox.add(reminder); 
  }
  
  // Obtener todos los recordatorios activos
  Future<List<ReminderModel>> getActiveReminders() async {
    return reminderBox.values
        .where((r) => r.isActive == true)
        .toList();
  }

  // Cancelar suscripcion (Borrar o desactivar)
  Future<void> toggleReminderStatus(int key, bool status) async {
    final reminder = reminderBox.get(key); // Usamos la key como ID
    if (reminder != null) {
      reminder.isActive = status;
      await reminder.save(); 
    }
  }
  
  // Escuchar cambios en recordatorios
  Stream<List<ReminderModel>> listenToReminders() {
    final controller = StreamController<List<ReminderModel>>();
    void emitReminders() {
      // Obtenemos todos los datos y los mandamos al Stream
      final reminders = reminderBox.values.toList();
      controller.add(reminders);
    }
    
    emitReminders();

    // Escuchar cambios futuros en la caja
    final subscription = reminderBox.watch().listen((event) {
      emitReminders();
    });

    // Limpiar recursos al cerrar
    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };

    return controller.stream;
  }

  // METODOS AUXILIARES 
  Future<void> deleteReminder(int key) async {
    await reminderBox.delete(key);
  }
}