import 'package:finance_local/utils/math_utils.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // Para AppColors
import 'transactions_screen.dart'; 
import 'calendar_screen.dart';
import '../widgets/add_transaction_modal.dart';
import '../services/database_service.dart';
import '../models/transaction_model.dart';
import '../widgets/expenses_bar_chart.dart';
import '../screens/monthly_expenses_screen.dart';
import '../utils/currency_format.dart';
//import '../utils/data_seeder.dart'; //granja de datos pruebas

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String userName = "Usuario"; // Valor por defecto
  int _selectedIndex = 0;
  bool _hasVibrated = false; //control de vibracion

  @override
  void initState() {
    super.initState();
    _loadUserName();
    /*/ DESCOMENTAR ESTA LINEA, CORRE LA APP UNA VEZ, Y LUEGO VUELVE A COMENTARLA
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await DataSeeder().seedData();
      if(mounted) setState(() {});// Recarga la UI al terminar
    });*/
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('user_name') ?? "Usuario";
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColorSecondary = isDarkMode ? AppColors.textGrayLight : Colors.grey[500];

    final List<Widget> pages = [
      _buildDashboardView(),                  // Indice 0: Inicio
      const TransactionsScreen(isTab: true),  // Indice 1: Transacciones
      const CalendarScreen(),  // Indice 2: Calendario
    ];

    return Scaffold(
      // BODY DINAMICO
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: pages,
        ),
      ),

      // BOTON FLOTANTE 
      floatingActionButton: _selectedIndex == 0 
        ? SizedBox(
            width: 60, height: 60,
            child: FloatingActionButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true, 
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (context) => const AddTransactionModal(),
                );
              },
              backgroundColor: isDarkMode ? AppColors.primary : AppColors.primaryLight,
              shape: const CircleBorder(),
              elevation: 4,
              child: Icon(Icons.add_rounded, color: isDarkMode ? Colors.black : Colors.white, size: 32),
            ),
          )
        : null, // Ocultar el boton si no esta en home
      
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      // MENU INFERIOR 
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: isDarkMode ? AppColors.cardDark : Colors.white,
          indicatorColor: AppColors.primary.withValues(alpha: 0.15),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)
          ),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return  IconThemeData(color: isDarkMode ? AppColors.primary : AppColors.primaryLight);
            }
            return IconThemeData(color: textColorSecondary);
          }),
        ),
        child: NavigationBar(
          height: 70,
          elevation: 0,
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.swap_horiz_rounded),
              label: 'Transacciones',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_rounded),
              label: 'Calendario',
            ),
          ],
        ),
      ),
    );
  }

  // VISTA DASHBOARD 
  Widget _buildDashboardView() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColorSecondary = isDarkMode ? AppColors.textGrayLight : Colors.grey[500];
    final actionTextColor = isDarkMode ? AppColors.primary : AppColors.primaryLight;
    final dbService = DatabaseService();

    final now = DateTime.now(); // fecha actual
    String currentMonth = DateFormat('MMMM y', 'es').format(now); //mes y año en es
    currentMonth = currentMonth[0].toUpperCase() + currentMonth.substring(1);

    return StreamBuilder<List<TransactionModel>>(
      stream: dbService.listenToTransactions(), // Escuchamos la BD
      builder: (context, snapshot) {
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final transactions = snapshot.data ?? [];

        // CALCULOS MATEMATICOS 
        double totalBalance = 0; //Saldo Total Acumulado 
        //Flujo del Mes Actual
        double monthlyIncome = 0;
        double monthlyExpense = 0;

        for (var tx in transactions) {
          //saldo total historico
          if (tx.type == TransactionType.income) {
            totalBalance += tx.amount;
          } else {
            totalBalance -= tx.amount;
          }

          // Calculo Mensual actual
          if (tx.date.month == now.month && tx.date.year == now.year) {
            if (tx.type == TransactionType.income) {
              monthlyIncome += tx.amount;
            } else {
              monthlyExpense += tx.amount;
            }
          }
        }

        totalBalance = roundAmount(totalBalance);
        final double monthlyNet = monthlyIncome - monthlyExpense;

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20.0), 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Hola, $userName",
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Resumen de $currentMonth",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: textColorSecondary,
                              fontWeight: FontWeight.normal,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // tarjeta saldo y balance
                _buildBalanceCard(
                  context: context, 
                  totalBalance: totalBalance, 
                  monthlyIncome: monthlyIncome, 
                  monthlyExpense: monthlyExpense, 
                  monthlyNet: monthlyNet, 
                  currentMonth: currentMonth,
                  isDarkMode: isDarkMode
                ),
                const SizedBox(height: 16),

                // GRAFICA TOP 5
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Card(
                    elevation: 0,
                    color: isDarkMode ? AppColors.cardDark : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: isDarkMode ? BorderSide.none : BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0), 
                      child: Column(
                        children: [
                          // cabecera
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              //titulo seccion grafico
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Categorías",
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18, 
                                    ),
                                  ),
                                  Text(
                                    "Top 5 mayores gastos", 
                                    style: TextStyle(
                                      fontSize: 12, 
                                      color: Theme.of(context).brightness == Brightness.dark 
                                          ? Colors.grey[400] 
                                          : Colors.grey[600]
                                    ),
                                  ),
                                ],
                              ),
                              //Boton ver todo
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MonthlyExpensesScreen(transactions: transactions,),
                                    ),
                                  );
                                }, 
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  backgroundColor: Theme.of(context).brightness == Brightness.dark 
                                      ? Colors.white.withValues(alpha: 0.05) 
                                      : Colors.grey.shade200,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                child: Row( 
                                  children: [
                                    Text(
                                      "Ver reporte", 
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        color: actionTextColor, 
                                        fontSize: 14
                                      )
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.arrow_forward_ios_rounded, size: 12, color: actionTextColor,)
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // GRAFICO 
                          AspectRatio(
                            aspectRatio: 1.5,
                            child: ExpensesBarChart(transactions: transactions),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // List Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Wrap(
                          children: [
                            Text(
                              "Últimas Transacciones", 
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedIndex = 1; 
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          // Mismo fondo sutil adaptable al tema
                          backgroundColor: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.white.withValues(alpha: 0.05) 
                              : Colors.grey.shade200,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              "Ver todo", 
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                color: actionTextColor, 
                                fontSize: 14
                              )
                            ),
                            const SizedBox(width: 4),
                            // Flecha pequeña para indicar navegacion
                            Icon(
                              Icons.arrow_forward_ios_rounded, 
                              size: 12, 
                              color: actionTextColor,
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),

                if (transactions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(child: Text("No hay movimientos aún")),
                  )
                else 
                  ...transactions.take(5).map((tx) {
                    final isIncome = tx.type == TransactionType.income;
                    return _buildTransactionItem(
                      context, 
                      title: tx.title, 
                      subtitle: tx.categoryName, 
                      amount: "${isIncome ? '+' : '-'} ${CurrencyFormat.format(tx.amount)}", 
                      icon: IconData(tx.categoryIconCode, fontFamily: 'MaterialIcons'), 
                      color: Color(tx.categoryColor), 
                      isIncome: isIncome
                    );
                  }),
              ],
            ),
          ),
        );
      }
    );
  }

  // --- WIDGET PRINCIPAL DE BALANCE (CON VIBRACIÓN) ---
  Widget _buildBalanceCard({
    required BuildContext context, 
    required double totalBalance, 
    required double monthlyIncome,
    required double monthlyExpense,
    required double monthlyNet,
    required String currentMonth,
    required bool isDarkMode
  }) {
    final isNegativeBalance = totalBalance < 0;
    final textColorSecondary = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
    // VIBRACION CONTROLADA 
    if (isNegativeBalance) {
      if (!_hasVibrated) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (await Vibration.hasVibrator()) {
            Vibration.vibrate(duration: 500); 
            // Vibration.vibrate(duration: 500, amplitude: 128); // 128 es intensidad media
          }
          // Marcamos que ya vibramos
          if (mounted) {
            setState(() {
              _hasVibrated = true;
            });
          }
        });
      }
    } else {
      // Reseteamos la bandera si el saldo ya es positivo
      if (_hasVibrated) {
        // postFrame para evitar errores de redibujado
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _hasVibrated = false;
            });
          }
        });
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        elevation: 0,
        color: isDarkMode ? AppColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: isDarkMode ? BorderSide.none : BorderSide(color: Colors.grey.shade200)
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icono y Titulo
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isNegativeBalance 
                          ? Colors.red.withValues(alpha: 0.1) 
                          : (isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade100),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded, 
                      size: 20, 
                      color: isNegativeBalance ? Colors.redAccent : textColorSecondary
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Saldo Total Disponible", 
                    style: TextStyle(
                      color: textColorSecondary, 
                      fontWeight: FontWeight.w600,
                      fontSize: 14
                    )
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // MONTO TOTAL 
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  CurrencyFormat.format(totalBalance),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold, 
                    fontSize: 40,
                    color: isNegativeBalance 
                      ? Colors.redAccent 
                      : Theme.of(context).colorScheme.onSurface,
                    letterSpacing: -1.5,
                  ),
                ),
              ),

              // ALERTA DE DEUDA 
              if (isNegativeBalance) ...[
                 const SizedBox(height: 16),
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                   decoration: BoxDecoration(
                     color: Colors.red.withValues(alpha: 0.08),
                     borderRadius: BorderRadius.circular(12),
                     border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                   ),
                   child: Row(
                     children: [
                       Icon(Icons.live_help_rounded, color: Colors.red.shade400, size: 22),
                       const SizedBox(width: 10),
                       Expanded(
                         child: Text(
                           "¡Cuidado! Estás en números rojos. Recuerda registrar el dinero extra para ajustar tu saldo.",
                           style: TextStyle(
                             color: Colors.red.shade700,
                             fontSize: 12, 
                             height: 1.3,
                             fontWeight: FontWeight.w500
                           ),
                         ),
                       ),
                     ],
                   ),
                 )
              ],

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),

              // DESEMPEÑO DEL MES
              Text(
                "Flujo de $currentMonth", 
                style: TextStyle(color: textColorSecondary, fontSize: 12, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 15),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryItem(
                    context: context, 
                    icon: Icons.arrow_upward_rounded, 
                    iconColor: isDarkMode ? AppColors.primary : AppColors.primaryLight, 
                    label: "Ingresos", 
                    amount: CurrencyFormat.format(monthlyIncome)
                  ),
                  _buildSummaryItem(
                    context: context, 
                    icon: Icons.arrow_downward_rounded, 
                    iconColor: Colors.redAccent, 
                    label: "Gastos", 
                    amount: CurrencyFormat.format(monthlyExpense) 
                  ),
                  _buildSummaryItem(
                    context: context, 
                    icon: Icons.functions_rounded, 
                    iconColor: monthlyNet >= 0 ? Colors.blue : Colors.orange, 
                    label: "Resultado", 
                    amount: "${monthlyNet >= 0 ? '+' : ''}${CurrencyFormat.format(monthlyNet)}"
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widgets Auxiliares RESUMEN (Ingresos/Gastos/Resultado)
  Widget _buildSummaryItem({
    required BuildContext context, 
    required IconData icon, 
    required Color iconColor, 
    required String label, 
    required String amount
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          amount, 
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: 14,
            color: isDarkMode ? Colors.white : Colors.black87
          )
        ),
      ],
    );
  }

  // Item de Transaccion en la lista
  Widget _buildTransactionItem(BuildContext context, {required String title, required String subtitle, required String amount, required IconData icon, required Color color, required bool isIncome}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColorSecondary = isDarkMode ? AppColors.textGrayLight : Colors.grey[500];
    Color amountColor;
    
    if (isIncome) {
      // Si es INGRESO: Verde 
      amountColor = isDarkMode ? AppColors.primary : AppColors.primaryLight;
    } else {
      // Si es GASTO: Rojo
      amountColor = Colors.redAccent;
    }
 
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
          const SizedBox(width: 16),
          //texto titulo y subtitulos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(subtitle, style: TextStyle(color: textColorSecondary, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]
            )
          ),
          Text(amount, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: amountColor)),
        ],
      ),
    );
  }
}