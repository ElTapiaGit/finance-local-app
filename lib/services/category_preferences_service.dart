import 'package:shared_preferences/shared_preferences.dart';
import '../models/category_model.dart';

/// Servicio encargado de la persistencia y ordenamiento de preferencias de categorias.
class CategoryPreferencesService {
  static const String _keyCategoryOrder = 'category_order';
  static const String _keyHiddenCategories = 'hidden_categories';

  /// Obtiene la lista ordenada de nombres de categorias almacenada en SharedPreferences.
  Future<List<String>> getCategoryOrder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyCategoryOrder) ?? [];
  }

  /// Guarda la lista ordenada de nombres de categorias en SharedPreferences.
  Future<void> saveCategoryOrder(List<String> order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyCategoryOrder, order);
  }

  /// Obtiene la lista de nombres de categorias ocultas en SharedPreferences.
  Future<List<String>> getHiddenCategories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyHiddenCategories) ?? [];
  }

  /// Guarda la lista de nombres de categorias ocultas en SharedPreferences.
  Future<void> saveHiddenCategories(List<String> hidden) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyHiddenCategories, hidden);
  }

  /// Aplica el orden guardado a la lista de categorias.
  /// Cualquier categoria presente en Hive que no figure en currentOrder
  /// se inserta en el indice 0 para garantizar visibilidad prioritaria.
  List<CategoryModel> applyOrder(
    List<CategoryModel> categories,
    List<String> currentOrder,
  ) {
    if (categories.isEmpty) return [];

    bool needsSave = false;
    for (final cat in categories) {
      if (!currentOrder.contains(cat.name)) {
        currentOrder.insert(0, cat.name);
        needsSave = true;
      }
    }

    if (needsSave) {
      saveCategoryOrder(currentOrder);
    }

    final sortedList = List<CategoryModel>.from(categories);
    sortedList.sort((a, b) {
      final indexA = currentOrder.indexOf(a.name);
      final indexB = currentOrder.indexOf(b.name);
      final posA = indexA == -1 ? 999999 : indexA;
      final posB = indexB == -1 ? 999999 : indexB;
      return posA.compareTo(posB);
    });

    return sortedList;
  }

  /// Filtra las categorias visibles considerando si la transaccion es de gasto o ingreso
  /// y excluyendo las que el usuario marco como ocultas.
  List<CategoryModel> filterVisible(
    List<CategoryModel> allCategories, {
    required bool isExpense,
    required List<String> hiddenCategories,
  }) {
    return allCategories.where((cat) {
      if (isExpense) {
        if (cat.name == 'Ingreso') return false;
      } else {
        if (cat.name != 'Ingreso') return false;
      }
      if (cat.name == 'Ingreso' || cat.name == 'Otros') return true;
      return !hiddenCategories.contains(cat.name);
    }).toList();
  }

  static final Map<String, int> _usageCounts = {};

  /// Obtiene la frecuencia de uso de una categoria.
  int getUsageCount(String categoryName) {
    return _usageCounts[categoryName] ?? 0;
  }

  /// Incrementa la frecuencia de uso de una categoria.
  void incrementUsage(String categoryName) {
    _usageCounts[categoryName] = (_usageCounts[categoryName] ?? 0) + 1;
  }
}

