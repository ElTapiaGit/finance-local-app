import 'package:hive_flutter/hive_flutter.dart';

part 'category_model.g.dart'; 

// Asignamos el typeId 3, ya que 0, 1 y 2 se usaron anteriormente.
@HiveType(typeId: 3)
class CategoryModel extends HiveObject {

  @HiveField(0)
  late String name; // Ej: "Comida", "Transporte"

  @HiveField(1)
  late String iconName; // Ej: "utensils", "bus" (FontAwesome)

  @HiveField(2)
  late String colorHex; // Ej: "FF5733"
  
  // Hive soporta campos con valor por defecto
  @HiveField(3)
  bool isCustom = false; // false = por defecto, true = creada por usuario
}