import 'package:hive_flutter/hive_flutter.dart';

part 'reminder_model.g.dart';

// Asignamos el typeId 2, ya que 0 y 1 se usaron en TransactionModel y TransactionType.
@HiveType(typeId: 2)
class ReminderModel extends HiveObject {

  @HiveField(0)
  late String title; // Ej: "Netflix"

  @HiveField(1)
  late double amount; // Ej: 50.00

  @HiveField(2)
  late int dayOfMonth; // Ej: 6 (Se repite cada día 6)
  
  @HiveField(3)
  late bool isActive; // True = Se sigue cobrando. False = Cancelaste la suscripción.

  // Datos visuales
  @HiveField(4)
  late int colorValue; 

  @HiveField(5)
  late int iconCode; 

  @HiveField(6)
  DateTime createdAt = DateTime.now();
}