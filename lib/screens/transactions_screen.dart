import 'package:flutter/material.dart';
import '../controllers/transactions_controller.dart';
import '../models/transaction_model.dart';
import '../utils/custom_snackbar.dart';
import '../utils/period_lock_helper.dart';
import '../widgets/add_transaction_modal.dart';
import '../widgets/export_bottom_sheet.dart';
import '../widgets/shared_transaction_tile.dart';
import '../widgets/transaction_filter_bar.dart';

class TransactionsScreen extends StatefulWidget {
  final bool isTab;
  const TransactionsScreen({super.key, this.isTab = false});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TransactionsController _controller = TransactionsController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.init();

    // Escucha el scroll para paginacion reactiva
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!_controller.isLoading && _controller.hasMoreData) {
          _controller.loadMoreData();
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Prepara y abre el modal para exportar
  Future<void> _openExportModal() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final allData = await _controller.getAllTransactions();

      if (mounted) {
        Navigator.pop(context);

        showModalBottomSheet(
          context: context,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (context) => ExportBottomSheet(allTransactions: allData),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        CustomSnackBar.show(
          context: context,
          message: "Error al preparar la exportación",
          icon: Icons.error_outline_rounded,
          backgroundColor: Colors.red.shade700,
          iconColor: Colors.white,
        );
      }
    }
  }

  Future<void> _handleEdit(TransactionModel tx) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => AddTransactionModal(transactionToEdit: tx),
    );
  }

  Future<bool> _handleDelete(TransactionModel tx) async {
    final colorScheme = Theme.of(context).colorScheme;
    if (PeriodLockHelper.isPeriodLocked(tx.date)) {
      CustomSnackBar.show(
        context: context,
        message: "Periodo cerrado. No puedes eliminar transacciones antiguas.",
        icon: Icons.lock_rounded,
        backgroundColor: Colors.orange.shade700,
        iconColor: Colors.white,
        durationSeconds: 4,
      );
      return false;
    }

    final isOld = tx.date.isBefore(DateTime.now().subtract(const Duration(days: 30)));
    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isOld ? "¿Eliminar registro antiguo?" : "¿Eliminar transacción?"),
        content: Text(isOld
            ? "Esto modificará tu historial y saldos pasados.\n\n¿Continuar?"
            : "Esta acción no se puede deshacer."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onSurfaceVariant,
            ),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Eliminar", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _controller.deleteTransaction(tx.key);

      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: "Transacción eliminada",
          icon: Icons.delete_outline_rounded,
        );
      }
      return true;
    }
    return false;
  }

  // Selector de fecha para el filtro
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      locale: const Locale('es', 'ES'),
      initialDate: _controller.filterDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: "SELECCIONA FECHA DE FILTRO",
      cancelText: "CANCELAR",
      confirmText: "ACEPTAR",
    );
    if (picked != null) {
      _controller.setFilterDate(picked);
    }
  }

  // Limpiar filtros
  void _clearFilters() {
    _searchController.clear();
    _controller.clearFilters();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: widget.isTab
                ? null
                : IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: colorScheme.onSurface,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
            title: Text(
              "Transacciones",
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(Icons.download_rounded, color: colorScheme.onSurfaceVariant),
                tooltip: "Exportar a Excel",
                onPressed: _openExportModal,
              ),
              if (_controller.isFiltering)
                IconButton(
                  icon: Icon(Icons.filter_alt_off_rounded, color: colorScheme.onSurfaceVariant),
                  onPressed: _clearFilters,
                  tooltip: "Limpiar filtros",
                ),
            ],
          ),
          body: Column(
            children: [
              // Componente independiente para busqueda y filtros
              TransactionFilterBar(
                searchController: _searchController,
                filterDate: _controller.filterDate,
                filterMode: _controller.filterMode,
                onSearchChanged: (value) => _controller.setSearchText(value),
                onSelectDate: _selectDate,
                onFilterModeChanged: (mode) => _controller.setFilterMode(mode),
                onClearFilters: _clearFilters,
              ),

              // Lista reactiva de transacciones
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => _controller.resetAndReload(),
                  child: Builder(
                    builder: (context) {
                      if (_controller.transactions.isEmpty && !_controller.isLoading) {
                        return _buildEmptyState();
                      }

                      if (_controller.isLoading && _controller.transactions.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          widget.isTab
                              ? 16
                              : 16 + MediaQuery.paddingOf(context).bottom,
                        ),
                        itemCount: _controller.groupedTransactions.length +
                            (_controller.hasMoreData ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _controller.groupedTransactions.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final item = _controller.groupedTransactions[index];

                          if (item is String) {
                            return _buildDateHeader(context, item);
                          } else if (item is TransactionModel) {
                            return SharedTransactionTile(
                              transaction: item,
                              onEdit: () => _handleEdit(item),
                              onDelete: (direction) => _handleDelete(item),
                            );
                          }
                          return const SizedBox();
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Widget cuando no hay transacciones
  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: 400,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded, size: 64, color: colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              "No se encontraron resultados",
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  // Widget para el titulo de la fecha (Header)
  Widget _buildDateHeader(BuildContext context, String date) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 0, 8),
      child: Text(
        date,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
