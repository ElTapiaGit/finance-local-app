// ignore_for_file: deprecated_member_use

import 'dart:math';
import 'package:finance_local/main.dart';
import 'package:flutter/material.dart';
import '../services/database_service.dart';

class DataSeeder {
  final DatabaseService _db = DatabaseService();
  final Random _rng = Random();

  // COLORES Y CATEGORIAS
  final List<Map<String, dynamic>> _categories = [
    {'name': 'Comida', 'icon': Icons.restaurant_rounded.codePoint, 'color': Colors.orange.value},
    {'name': 'Transporte', 'icon': Icons.directions_bus_rounded.codePoint, 'color': Colors.blue.value},
    {'name': 'Vivienda', 'icon': Icons.home_rounded.codePoint, 'color': Colors.redAccent.value},
    {'name': 'Servicios', 'icon': Icons.bolt_rounded.codePoint, 'color': Colors.yellow.shade700.value},
    {'name': 'Ropa', 'icon': Icons.checkroom_rounded.codePoint, 'color': Colors.deepOrange.value},
    {'name': 'Cuidado P.', 'icon': Icons.spa_rounded.codePoint, 'color': Colors.pink.shade300.value},
    {'name': 'Mascotas', 'icon': Icons.pets_rounded.codePoint, 'color': Colors.brown.value},
    {'name': 'Educación', 'icon': Icons.school_rounded.codePoint, 'color': Colors.indigo.value},
    {'name': 'Entretenimiento', 'icon': Icons.movie_rounded.codePoint, 'color': Colors.purple.value},
    {'name': 'Salud', 'icon': Icons.medical_services_rounded.codePoint, 'color': Colors.teal.value},
    {'name': 'Regalos', 'icon': Icons.card_giftcard_rounded.codePoint, 'color': const Color(0xFFE91E63).value},
    {'name': 'Otros', 'icon': Icons.more_horiz_rounded.codePoint, 'color': Colors.grey.value},
  ];

  // HELPER PARA GENERAR CENTAVOS (Ej: 0.50, 0.99)
  double _addCents(double amount) {
    // 70% de probabilidad de tener centavos
    if (_rng.nextDouble() < 0.7) {
       // Genera centavos entre 0.01 y 0.99 nextInt(100) genera de 0 a 99.
       double cents = _rng.nextInt(100) / 100.0;
       return amount + cents;
    }
    return amount;
  }
  // HELPER DE SEGURIDAD PARA REDONDEO
  double _sanitizeDouble(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  Future<void> seedData() async {
    debugPrint("🌱 INICIANDO SEMBRADO DE DATOS CON CENTAVOS...");
    
    // Ajusta de fechas spara mas o menos historia
    DateTime currentDate = DateTime(2024, 7, 1);
    DateTime endDate = DateTime.now(); //fecha limite 
    int totalTx = 0;

    // Métodos de pago disponibles
    final paymentMethods = ['Efectivo', 'Tarjeta de Débito', 'Tarjeta de Crédito', 'QR / Transferencia'];

    while (currentDate.isBefore(endDate)) {
      
      // DIA 1: SUELDO Y FIJOS
      if (currentDate.day == 1) {
        await _db.saveTransaction(
          title: "Sueldo Mensual",
          amount: 3600.00, // Sueldos
          isExpense: false,
          paymentMethod: "QR / Transferencia",
          date: currentDate.add(const Duration(hours: 8)), // 8:00 AM
          categoryName: "Ingreso",
          categoryColor: AppColors.primary.value,
          categoryIcon: Icons.attach_money.codePoint,
        );

        await _db.saveTransaction(
          title: "Alquiler Depto",
          amount: 1500.00, // Alquiler 
          isExpense: true,
          paymentMethod: "Efectivo",
          date: currentDate.add(const Duration(hours: 9)),
          categoryName: "Vivienda",
          categoryColor: Colors.redAccent.value,
          categoryIcon: Icons.home_rounded.codePoint,
        );
        
        // Facturas casi siempre tienen centavos
        await _db.saveTransaction(
          title: "Internet y Luz",
          amount: _sanitizeDouble(_addCents(180.0)), // Usamos el sanitizador Ej: 180.50
          isExpense: true,
          paymentMethod: "QR / Transferencia",
          date: currentDate.add(const Duration(hours: 10)),
          categoryName: "Servicios",
          categoryColor: Colors.yellow.shade700.value,
          categoryIcon: Icons.bolt_rounded.codePoint,
        );
      }

      // GASTOS DIARIOS ALEATORIOS
      if (_rng.nextDouble() < 0.7) { 
        final cat = _categories[_rng.nextInt(_categories.length)];
        double rawAmount = 0;
        String title = "";
        
        // Generamos titulos y montos realistas segun categoria
        switch (cat['name']) {
          case 'Comida':
            rawAmount = _addCents(15.0 + _rng.nextInt(40)); 
            title = ["Almuerzo", "Cena", "Snack", "Supermercado", "Pollo Broaster", "Salteñas"][_rng.nextInt(6)];
            break;
          case 'Transporte':
            rawAmount = 2.0 + _rng.nextInt(15); 
            title = ["Taxi", "Trufi", "Micro", "Gasolina", "Uber"][_rng.nextInt(5)];
            break;
          case 'Servicios': 
            rawAmount = _addCents(10.0 + _rng.nextInt(50));
            title = "Recarga Celular";
            break;
          case 'Entretenimiento':
            rawAmount = _addCents(30.0 + _rng.nextInt(60));
            title = ["Cine", "Salida amigos", "Suscripción", "Juegos Steam"][_rng.nextInt(4)];
            break;
          case 'Ropa':
            rawAmount = _addCents(50.0 + _rng.nextInt(150));
            title = ["Polera", "Pantalón", "Zapatillas", "Accesorios"][_rng.nextInt(4)];
            break;
          case 'Mascotas':
            rawAmount = _addCents(20.0 + _rng.nextInt(100));
            title = ["Comida perro", "Veterinario", "Juguete", "Sobrecitos"][_rng.nextInt(4)];
            break;
          case 'Salud':
            rawAmount = _addCents(20.0 + _rng.nextInt(80));
            title = ["Farmacia", "Consulta", "Vitaminas"][_rng.nextInt(3)];
            break;
           case 'Regalos':
            rawAmount = _addCents(50.0 + _rng.nextInt(100));
            title = "Cumpleaños";
            break;
          default:
            rawAmount = _addCents(10.0 + _rng.nextInt(80));
            title = "Gasto Varios";
        }

        await _db.saveTransaction(
          title: title,
          amount: _sanitizeDouble(rawAmount),
          isExpense: true,
          paymentMethod: paymentMethods[_rng.nextInt(paymentMethods.length)],
          // Hora aleatoria entre 9am y 9pm
          date: currentDate.add(Duration(hours: 9 + _rng.nextInt(12), minutes: _rng.nextInt(59))),
          categoryName: cat['name'],
          categoryColor: cat['color'],
          categoryIcon: cat['icon'],
        );
        totalTx++;
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }
    debugPrint("✅ FINALIZADO: $totalTx transacciones con centavos generadas.");
  }
}