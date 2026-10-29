# Análisis y Plan de Refactorización Modular: `AddTransactionModal`

**Archivo analizado:** `lib/widgets/add_transaction_modal.dart`  
**Extensión actual:** 1099 líneas de código  
**Objetivo:** Diseñar un plan de desacoplamiento modular seguro para transformar un archivo monolítico en componentes altamente cohesionados, testeables y reutilizables, sin alterar la reactividad ni la persistencia existente.

---

## 1. Desacoplamiento Visual (Widgets Independientes)

El archivo `add_transaction_modal.dart` actualmente concentra múltiples responsabilidades de interfaz que exceden el rol de un formulario de captura. Se han identificado cuatro subsistemas visuales de alta complejidad candidatos para extracción:

### 1.1. Diálogo de Configuración y Gestión de Categorías
* **Ubicación actual:** Líneas 168 a 384 (~217 líneas).
* **Responsabilidad:** Renderiza el `AlertDialog` con el `ReorderableListView.builder`, el `proxyDecorator`, el reordenamiento por arrastre con `Icons.drag_indicator`, la conmutación de visibilidad con `Switch` y la eliminación por deslizamiento condicional (`Dismissible`) con su respectivo diálogo de confirmación.
* **Propuesta:** Extraer a `lib/widgets/category_config_dialog.dart`.
* **Mejora adicional integrada:** Permitirá refinar el contenedor rojo del gesto `Dismissible` aplicando un `ClipRRect` con radio de `12px` idéntico al del `ListTile`, evitando que el fondo rojo desborde en esquinas rectangulares durante la animación de descarte.

### 1.2. Selector de Tipo de Movimiento (Gasto / Ingreso)
* **Ubicación actual:** Líneas 555 a 564 y 1036 a 1065 (~40 líneas).
* **Responsabilidad:** Botonera superior tipo *pill* con estados activos/inactivos, transiciones de color y actualización del tipo de transacción.
* **Propuesta:** Extraer a `lib/widgets/transaction_type_selector.dart`.

### 1.3. Fila de Selección de Fecha y Método de Pago
* **Ubicación actual:** Líneas 626 a 687 (~62 líneas).
* **Responsabilidad:** Fila simétrica (`Row`) que coordina el disparador modal de `showDatePicker` y el componente Material 3 `DropdownMenu<String>` con su `LayoutBuilder` y `menuStyle`.
* **Propuesta:** Extraer a `lib/widgets/date_payment_selector_row.dart`.

### 1.4. Selector Horizontal de Categorías y Banner Informativo
* **Ubicación actual:** Líneas 689 a 810 (~122 líneas).
* **Responsabilidad:** Renderiza la cabecera ("Categoría" + botón de engranaje), la lista horizontal con el botón circular de añadir (+) en el índice 0, los círculos de categoría en los índices 1 a N, y el banner animado (`AnimatedSwitcher`) con la descripción contextual de la categoría activa.
* **Propuesta:** Extraer a `lib/widgets/category_horizontal_selector.dart`.

### 1.5. Pintor de Borde Punteado (`DottedCircleBorderPainter`)
* **Ubicación actual:** Líneas 1066 a 1099 (~34 líneas).
* **Responsabilidad:** Algoritmo trigonométrico de dibujo de arcos discontinuos para el botón de creación rápida.
* **Propuesta:** Extraer a `lib/widgets/painters/dotted_circle_border_painter.dart`.

---

## 2. Mapa de Dependencias y Estado

Para garantizar que los nuevos componentes mantengan una reactividad bidireccional limpia con el modal principal, se define el siguiente contrato de parámetros e interfaces:

### 2.1. `CategoryConfigDialog`
```dart
class CategoryConfigDialog extends StatefulWidget {
  final List<String> hiddenCategories;
  final List<String> categoryOrder;
  final ValueChanged<List<String>> onHiddenCategoriesChanged;
  final ValueChanged<List<String>> onCategoryOrderChanged;
  final ValueChanged<String>? onCategoryDeleted;

  const CategoryConfigDialog({
    super.key,
    required this.hiddenCategories,
    required this.categoryOrder,
    required this.onHiddenCategoriesChanged,
    required this.onCategoryOrderChanged,
    this.onCategoryDeleted,
  });
}
```
* **Estado inyectado:**
  * `hiddenCategories` (`List<String>`): Lista activa de categorías ocultas.
  * `categoryOrder` (`List<String>`): Lista de orden secuencial.
* **Eventos salientes (Callbacks):**
  * `onHiddenCategoriesChanged`: Emite la nueva lista tras encender/apagar switches.
  * `onCategoryOrderChanged`: Emite el nuevo orden tras soltar un elemento arrastrado.
  * `onCategoryDeleted`: Notifica si la categoría eliminada coincide con la seleccionada en el formulario para reasignar el valor por defecto.

### 2.2. `TransactionTypeSelector`
```dart
class TransactionTypeSelector extends StatelessWidget {
  final bool isExpense;
  final ValueChanged<bool> onTypeChanged;

  const TransactionTypeSelector({
    super.key,
    required this.isExpense,
    required this.onTypeChanged,
  });
}
```
* **Estado inyectado:** Booleano `isExpense`.
* **Eventos salientes:** `onTypeChanged(bool isExpense)` que el modal padre procesa para reasignar categorías compatibles.

### 2.3. `DatePaymentSelectorRow`
```dart
class DatePaymentSelectorRow extends StatelessWidget {
  final DateTime selectedDate;
  final String selectedPaymentMethod;
  final List<String> paymentMethods;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<String> onPaymentMethodChanged;

  const DatePaymentSelectorRow({
    super.key,
    required this.selectedDate,
    required this.selectedPaymentMethod,
    required this.paymentMethods,
    required this.onDateChanged,
    required this.onPaymentMethodChanged,
  });
}
```
* **Estado inyectado:** Fecha seleccionada, método actual y catálogo de métodos.
* **Eventos salientes:** `onDateChanged(DateTime)` y `onPaymentMethodChanged(String)`.

### 2.4. `CategoryHorizontalSelector`
```dart
class CategoryHorizontalSelector extends StatelessWidget {
  final List<CategoryModel> categories;
  final String selectedCategoryName;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onOpenConfigDialog;
  final ValueChanged<CategoryModel>? onCategoryCreated;

  const CategoryHorizontalSelector({
    super.key,
    required this.categories,
    required this.selectedCategoryName,
    required this.onCategorySelected,
    required this.onOpenConfigDialog,
    this.onCategoryCreated,
  });
}
```
* **Estado inyectado:** Lista ya ordenada y filtrada de `CategoryModel`, y nombre seleccionado.
* **Eventos salientes:** Selección de categoría, solicitud de apertura del diálogo de configuración y retorno de nueva categoría creada mediante el botón (+).

---

## 3. Separación de Lógica de Negocio

Existen métodos de cálculo, validación y acceso a disco que actualmente residen en el cuerpo del widget y deben desacoplarse hacia utilidades independientes:

### 3.1. Validador de Bloqueo de Período Financiero (`PeriodLockHelper`)
* **Diagnóstico:** El método `_isPeriodLocked(DateTime transactionDate)` reside en `add_transaction_modal.dart` (líneas 386 a 395) y se encuentra **duplicado con código idéntico** en `lib/screens/transactions_screen.dart` (líneas 272 a 284).
* **Solución:** Crear `lib/utils/period_lock_helper.dart` con un método estático reutilizable:
  ```dart
  class PeriodLockHelper {
    static bool isPeriodLocked(DateTime transactionDate) {
      final now = DateTime.now();
      if (transactionDate.year == now.year && transactionDate.month == now.month) {
        return false;
      }
      return now.day >= 4;
    }
  }
  ```
* **Impacto:** Cumple el principio DRY (Don't Repeat Yourself) y centraliza la política financiera de días de gracia (día 4 de cada mes).

### 3.2. Servicio de Preferencias de Categorías (`CategoryPreferencesService`)
* **Diagnóstico:** La manipulación de `category_order` y `hidden_categories` mediante instancias ad-hoc de `SharedPreferences` se repite a lo largo del modal.
* **Solución:** Crear un servicio auxiliar en `lib/services/category_preferences_service.dart` que encapsule:
  * `getCategoryOrder()` y `saveCategoryOrder(List<String>)`.
  * `getHiddenCategories()` y `saveHiddenCategories(List<String>)`.
  * `applyOrder(List<CategoryModel> categories, List<String> order)`: Ordena y gestiona la auto-inserción en índice 0 de elementos recién agregados.
  * `filterVisible(List<CategoryModel> categories, {required bool isExpense, required List<String> hiddenCategories})`.

### 3.3. Metadatos Contextuales en `CategoryData`
* **Diagnóstico:** Los métodos auxiliares `_getCategoryDescription` y `_getCategoryExample` (líneas 150 a 166) resuelven textos buscando en la lista estática.
* **Solución:** Mover estos dos métodos como utilidades estáticas dentro de `lib/utils/categories_data.dart`:
  * `CategoryData.getDescription(String name)`
  * `CategoryData.getExample(String name)`

---

## 4. Propuesta de Estructura de Archivos

Una vez implementada la refactorización, el ecosistema de componentes quedará organizado de la siguiente manera:

```text
lib/
├── utils/
│   ├── categories_data.dart              # Incluye getDescription() y getExample()
│   └── period_lock_helper.dart           # Regla unica y centralizada de periodo cerrado
├── services/
│   ├── database_service.dart
│   └── category_preferences_service.dart # Lectura, escritura y ordenamiento en SharedPreferences
└── widgets/
    ├── painters/
    │   └── dotted_circle_border_painter.dart # CustomPainter extraido y reutilizable
    ├── add_transaction_modal.dart            # Modal principal reducido de 1099 a ~230 lineas
    ├── category_config_dialog.dart           # Dialogo ReorderableListView + Dismissible refinado
    ├── category_horizontal_selector.dart     # Carrusel horizontal + Banner explicativo
    ├── date_payment_selector_row.dart        # Selector de Fecha + DropdownMenu M3
    └── transaction_type_selector.dart        # Botones conmutadores Gasto/Ingreso
```

---

## 5. Estimación de Reducción y Beneficios Técnicos

1. **Reducción de Líneas:** `add_transaction_modal.dart` pasará de **1099 líneas** a aproximadamente **220 - 250 líneas**, limitándose a su propósito fundamental: orquestar el estado general, validar entradas y persistir transacciones.
2. **Mantenibilidad y Lectura:** Cada componente visual se aísla en su propio archivo con responsabilidades únicas y dependencias tipadas explícitamente.
3. **Paridad de Plataforma y UI:** El diálogo de configuración podrá recibir mejoras visuales aisladas (como el redondeo del fondo rojo del `Dismissible`) sin riesgo de introducir efectos colaterales en el formulario de transacciones.
4. **Compilación Segura:** Al basarse en contratos de tipos estrictos (`ValueChanged<T>`, `List<CategoryModel>`), toda la refactorización es validable estáticamente en tiempo de compilación.

