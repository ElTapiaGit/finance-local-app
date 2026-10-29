import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction_model.dart';
import '../models/reminder_model.dart';
import '../models/category_model.dart';
import '../utils/categories_data.dart';
import '../utils/math_utils.dart';

class DatabaseService {
  // Patron Singleton
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Box<TransactionModel> get transactionBox => Hive.box<TransactionModel>('transactions');
  Box<ReminderModel> get reminderBox => Hive.box<ReminderModel>('reminders');
  Box<CategoryModel> get categoryBox => Hive.box<CategoryModel>('categories');

  // Inicializacion: registra adaptadores, abre las cajas y realiza el sembrado inicial
  Future<void> init() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TransactionModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TransactionTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ReminderModelAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(CategoryModelAdapter());
    }

    if (!Hive.isBoxOpen('transactions')) {
      await Hive.openBox<TransactionModel>('transactions');
    }
    if (!Hive.isBoxOpen('categories')) {
      await Hive.openBox<CategoryModel>('categories');
    }
    if (!Hive.isBoxOpen('reminders')) {
      await Hive.openBox<ReminderModel>('reminders');
    }

    await seedCategoriesIfEmpty();
  }

  // Sembrado de categorias maestras si la caja esta vacia
  Future<void> seedCategoriesIfEmpty() async {
    if (categoryBox.isEmpty) {
      for (final cat in CategoryData.allCategories) {
        final color = (cat['color'] as Color).value;
        final icon = (cat['icon'] as IconData).codePoint;
        final newCategory = CategoryModel(
          name: cat['name'] as String,
          iconCode: icon,
          colorValue: color,
          isCustom: false,
        );
        await categoryBox.add(newCategory);
      }
    }
  }

  // Metodos para Categorias
  Stream<List<CategoryModel>> listenToCategories() {
    final controller = StreamController<List<CategoryModel>>();

    void updateListener() {
      final list = categoryBox.values.toList();
      controller.add(list);
    }

    updateListener();

    categoryBox.listenable().addListener(updateListener);

    controller.onCancel = () {
      categoryBox.listenable().removeListener(updateListener);
      controller.close();
    };

    return controller.stream.asBroadcastStream();
  }

  Future<List<CategoryModel>> getAllCategories() async {
    return categoryBox.values.toList();
  }

  Future<void> saveCategory({
    required String name,
    required int iconCode,
    required int colorValue,
    bool isCustom = true,
  }) async {
    final category = CategoryModel(
      name: name,
      iconCode: iconCode,
      colorValue: colorValue,
      isCustom: isCustom,
    );
    await categoryBox.add(category);
  }

  // Metodos para Transacciones
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

  Stream<List<TransactionModel>> listenToTransactions() {
    final controller = StreamController<List<TransactionModel>>();

    void updateListener() {
      final list = transactionBox.values.toList();
      list.sort((a, b) => b.date.compareTo(a.date));

      controller.add(list);
    }
    
    updateListener(); 

    transactionBox.listenable().addListener(updateListener);

    controller.onCancel = () {
      transactionBox.listenable().removeListener(updateListener);
      controller.close();
    };

    return controller.stream.asBroadcastStream();
  }

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

  Future<List<TransactionModel>> getTransactionsPaginated({required int offset, int limit = 20}) async {
    final allTransactions = transactionBox.values.toList();
    
    allTransactions.sort((a, b) => b.date.compareTo(a.date));

    final end = (offset + limit) > allTransactions.length 
        ? allTransactions.length 
        : (offset + limit);
        
    if (offset >= allTransactions.length) {
      return [];
    }

    return allTransactions.sublist(offset, end);
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    final list = transactionBox.values.toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> deleteTransaction(int key) async {
    await transactionBox.delete(key); 
  }

  // Metodos para Recordatorios
  Future<int> saveReminderAndReturnId({
    required String title,
    required double amount,
    required int dayOfMonth,
    required int color,
    required int icon,
    required int hour,  
    required int minute,
  }) async {
    final reminder = ReminderModel()
      ..title = title
      ..amount = amount
      ..dayOfMonth = dayOfMonth
      ..isActive = true
      ..colorValue = color
      ..iconCode = icon
      ..hour = hour    
      ..minute = minute;

    return await reminderBox.add(reminder); 
  }
  
  Future<List<ReminderModel>> getActiveReminders() async {
    return reminderBox.values
        .where((r) => r.isActive == true)
        .toList();
  }

  Future<void> toggleReminderStatus(int key, bool status) async {
    final reminder = reminderBox.get(key);
    if (reminder != null) {
      reminder.isActive = status;
      await reminder.save(); 
    }
  }
  
  Stream<List<ReminderModel>> listenToReminders() {
    final controller = StreamController<List<ReminderModel>>();
    void emitReminders() {
      final reminders = reminderBox.values.toList();
      controller.add(reminders);
    }
    
    emitReminders();

    final subscription = reminderBox.watch().listen((event) {
      emitReminders();
    });

    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };

    return controller.stream;
  }

  Future<void> deleteReminder(int key) async {
    await reminderBox.delete(key);
  }
}
