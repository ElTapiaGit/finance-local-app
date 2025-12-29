import 'package:hive_flutter/hive_flutter.dart';

part 'transaction_model.g.dart';

// Asignamos un typeId unico (0). Esto es el ID de la "clase" dentro de Hive.
@HiveType(typeId: 0)
class TransactionModel extends HiveObject {
  
  @HiveField(0)
  late String title; // Ej: "Cena", "Sueldo"

  @HiveField(1)
  late double amount; // Ej: 150.00

  @HiveField(2)
  late DateTime date; // Fecha seleccionada
  
  // Hive lo maneja con el Adapter.
  @HiveField(3)
  late TransactionType type; // income o expense

  @HiveField(4)
  late String paymentMethod; // Ej: "Efectivo", "Tarjeta"

  // Guardados directamente para facilitar lectura
  @HiveField(5)
  late String categoryName; // ej: "comida"
  
  @HiveField(6)
  late int categoryColor; // guardamos el valor entero del color (Color.value)
  
  @HiveField(7)
  late int categoryIconCode; // guardamos el codigo del icono (IconData.codePoint)
}

// ENUM (TransactionType)
// Asignamos otro typeId único (1).
@HiveType(typeId: 1)
enum TransactionType { 
  // Cada valor del enum también debe tener un @HiveField único,
  // comenzando desde 0.
  @HiveField(0)
  income, 
  
  @HiveField(1)
  expense,
}