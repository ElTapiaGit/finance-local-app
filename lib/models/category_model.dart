import 'package:hive_flutter/hive_flutter.dart';

part 'category_model.g.dart';

@HiveType(typeId: 3)
class CategoryModel extends HiveObject {
  @HiveField(0)
  late String name;

  @HiveField(1)
  late int iconCode;

  @HiveField(2)
  late int colorValue;

  @HiveField(3)
  bool isCustom = false;

  CategoryModel({
    this.name = '',
    this.iconCode = 0,
    this.colorValue = 0,
    this.isCustom = false,
  });
}
