import 'package:flutter/material.dart';
import '../main.dart'; 

class CategoryData {
  // LA LISTA MAESTRA
  static final List<Map<String, dynamic>> allCategories = [
    {'name': 'Comida', 'icon': Icons.restaurant_rounded, 'color': Colors.orange, 'desc': 'Supermercado, restaurantes, delivery, snacks, bebidas...', 'example': 'Almuerzo'},
    {'name': 'Transporte', 'icon': Icons.directions_bus_rounded, 'color': Colors.blue, 'desc': 'Pasajes, gasolina, mecánico, lavado, repuestos, parqueo...', 'example': 'Pasajes'},
    {'name': 'Vivienda', 'icon': Icons.home_rounded, 'color': Colors.redAccent, 'desc': 'Alquiler, mantenimiento hogar, muebles, limpieza, decoración...', 'example': 'Alquiler mes'},
    {'name': 'Servicios', 'icon': Icons.bolt_rounded, 'color': Colors.yellow.shade700, 'desc': 'Luz, agua, internet, plan de celular, suscripciones (Netflix)...', 'example': 'Factura de luz'},
    {'name': 'Ropa', 'icon': Icons.checkroom_rounded, 'color': Colors.deepOrange, 'desc': 'Vestimenta, calzado, accesorios, lavandería...', 'example': 'Zapatos nuevos'},
    {'name': 'Cuidado P.', 'icon': Icons.spa_rounded, 'color': Colors.pink.shade300, 'desc': 'Barbería, salón, cosméticos, gimnasio, higiene personal...', 'example': 'Corte de pelo'},
    {'name': 'Mascotas', 'icon': Icons.pets_rounded, 'color': Colors.brown, 'desc': 'Comida, veterinario, juguetes, estética...', 'example': 'Croquetas'},
    {'name': 'Educación', 'icon': Icons.school_rounded, 'color': Colors.indigo, 'desc': 'Universidad, cursos, libros, útiles escolares...', 'example': 'Cuadernos'},
    {'name': 'Entretenimiento', 'icon': Icons.movie_rounded, 'color': Colors.purple, 'desc': 'Cine, salidas, hobbies, juegos, streaming...', 'example': 'Entradas al cine'},
    {'name': 'Salud', 'icon': Icons.medical_services_rounded, 'color': Colors.teal, 'desc': 'Médicos, farmacia, dentista, estudios clínicos...', 'example': 'Pastillas'},
    {'name': 'Regalos', 'icon': Icons.card_giftcard_rounded, 'color': const Color(0xFFE91E63), 'desc': 'Obsequios, donaciones, ayudas a terceros...', 'example': 'Regalo mamá'},
    {'name': 'Ingreso', 'icon': Icons.attach_money_rounded, 'color': AppColors.primary, 'desc': 'Sueldos, ventas, trabajos extra, ahorros...', 'example': 'Sueldo'},
    {'name': 'Otros', 'icon': Icons.more_horiz_rounded, 'color': Colors.grey, 'desc': 'Cualquier otro gasto que no encaje en las anteriores.', 'example': 'Gasto imprevisto'},
  ];

  // LISTA DE NOMBRES PERMITIDOS PARA RECORDATORIOS
  static const List<String> reminderAllowedNames = [
    'Servicios',
    'Vivienda',
    'Educación',
    'Entretenimiento',
    'Salud',
    'Mascotas',
    'Transporte',
    'Otros',
  ];

  // GETTER INTELIGENTE PARA RECORDATORIOS
  static List<Map<String, dynamic>> get reminderCategories {
    return allCategories
        .where((cat) => reminderAllowedNames.contains(cat['name']))
        .toList();
  }
}