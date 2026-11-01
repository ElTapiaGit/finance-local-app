# Finance Local 📱💸

![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.0%2B-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Hive](https://img.shields.io/badge/Hive-NoSQL-FF6F00?style=for-the-badge&logo=firebase&logoColor=white)
![Clean Architecture](https://img.shields.io/badge/Architecture-Clean-green?style=for-the-badge)
![Version](https://img.shields.io/badge/Version-1.2.7-brightgreen?style=for-the-badge)
![Android](https://img.shields.io/badge/Android-API%2036-green?style=for-the-badge&logo=android&logoColor=white)

**Finance Local** es una aplicación móvil diseñada para la gestión de finanzas personales bajo la filosofía **"Offline First"**. Desarrollada con Flutter, prioriza la privacidad del usuario, el rendimiento inmediato y la seguridad de los datos sin depender de conexión a internet.

> **Versión:** 1.2.7 (Build 11)
> 🚀 **Estado:** En producción (Google Play Store).
> 🎓 **Proyecto:** Trabajo Freelance / Portafolio Profesional.

---

## Caracteristicas Funcionales

| <img src="assets/screenshots/grafica_caracteristicas.jpg" width="400"/> | 

---

## ✨ Características Principales

* **100% Offline & Privada:** Los datos viven en el dispositivo del usuario, no en la nube. Cero rastreo.
* **Base de Datos NoSQL (Hive):** Implementación de almacenamiento local de alto rendimiento mediante cajas binarias (Boxes), permitiendo lectura/escritura en microsegundos.
* **Gestión de Transacciones:** Algoritmos optimizados para el registro de Ingresos, Gastos y Categorías personalizadas.
* **Reportes Inteligentes:** Gráficos estadísticos y cálculos de balance mensual en tiempo real.
* **Exportación de Reportes:** Generación de balances detallados en formatos PDF y Excel (.xlsx) con arquitectura compatible con Scoped Storage.
* **Matemática Financiera Robusta:** Implementación de lógica de sanitización de decimales (`double` sanitization logic) para evitar errores de punto flotante en cálculos monetarios.
* **UI/UX Adaptativa:** Diseño responsivo con soporte nativo para **Modo Oscuro** y **Modo Claro** mediante esquemas de color Material 3.

---

## 🛠️ Arquitectura e Ingeniería

El proyecto sigue los principios de **Clean Architecture** para garantizar escalabilidad, testabilidad y separación de responsabilidades:

1.  **Domain Layer:** Entidades y Lógica de Negocio pura (independiente de Flutter).
2.  **Data Layer:** Implementación de Repositorios, Modelos (Adapters de Hive) y fuentes de datos locales.
3.  **Presentation Layer:** Gestión de estado (ChangeNotifier / Controllers) y Widgets UI desacoplados.

### Stack Tecnológico

* **Framework:** Flutter & Dart.
* **Base de Datos:** Hive (Key-Value NoSQL database).
* **Gestión de Estado:** ChangeNotifier / State Management nativo.
* **Gráficos:** Fl_chart.
* **Internacionalización:** Soporte configurado para formato de moneda local (Bolivia - Bs).

---

## Registro de Cambios (Changelog)

### Versión 1.2.7 (Build 11)

* **Compatibilidad con Android 16 (API 36) y Soporte Edge-to-Edge:** Actualización de `compileSdk` y `targetSdk` al nivel de API 36 cumpliendo con las directivas de Google Play Store. Integración de visualización borde a borde nativa gestionada directamente por el motor de Flutter.
* **Refactorización de Interfaz y Esquema de Colores Adaptativo:** Implementación completa de `ColorScheme` basado en Material 3, garantizando contraste dinámico, accesibilidad y consistencia visual en Modo Claro y Modo Oscuro.
* **Resolución de Scoped Storage para Exportación en Excel:** Soporte optimizado para las políticas de almacenamiento restringido en Android 10 y versiones superiores, permitiendo la generación, guardado y apertura directa de reportes binarios (.xlsx).
* **Activación de Ofuscación R8 y Optimización DEX:** Habilitación de minificación de código (`isMinifyEnabled`), reducción de recursos no utilizados (`isShrinkResources`) y configuración de reglas ProGuard para máxima protección y reducción de tamaño del paquete final.

---

## 🚀 Instalación y Despliegue

Este proyecto requiere el SDK de Flutter instalado.

1.  **Clonar el repositorio:**
    ```bash
    git clone [https://github.com/ElTapiaGit/finance-local-app.git](https://github.com/ElTapiaGit/finance-local-app.git)
    ```

2.  **Instalar dependencias:**
    ```bash
    flutter pub get
    ```

3.  **Generar adaptadores de Hive (Code Generation):**
    ```bash
    dart run build_runner build
    ```

4.  **Ejecutar la App:**
    ```bash
    flutter run
    ```

---

## 👨‍💻 Autor

**Ing. Jhon Eligio Tapia Vargas**
*Ingeniero de Sistemas & Desarrollador Full Stack*

* 🌍 Bolivia
* 📧 [tapiajhon111@gmail.com]

---
© 2025 Finance Local. Todos los derechos reservados.
