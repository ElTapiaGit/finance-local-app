import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../utils/currency_format.dart';

class SharedTransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onEdit;
  final Future<bool?> Function(DismissDirection)? onDelete;
  final EdgeInsetsGeometry margin;

  static final DateFormat _timeFormat = DateFormat('HH:mm');

  const SharedTransactionTile({
    super.key,
    required this.transaction,
    this.onEdit,
    this.onDelete,
    this.margin = const EdgeInsets.only(bottom: 12.0),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isIncome = transaction.type == TransactionType.income;
    final categoryColor = Color(transaction.categoryColor);

    final cardContent = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              // Icono de la categoria
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  IconData(
                    transaction.categoryIconCode,
                    fontFamily: 'MaterialIcons',
                  ),
                  color: categoryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Titulo y detalle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${transaction.paymentMethod} • ${_timeFormat.format(transaction.date)}",
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Monto con color semantico
              Text(
                "${isIncome ? '+' : '-'} ${CurrencyFormat.format(transaction.amount)}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isIncome
                      ? colorScheme.primary
                      : Colors.redAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (onDelete != null) {
      return Padding(
        padding: margin,
        child: Dismissible(
          key: Key(transaction.key.toString()),
          direction: DismissDirection.horizontal,
          background: Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit, color: Colors.white, size: 20),
                SizedBox(height: 2),
                Text(
                  "Editar",
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ],
            ),
          ),
          secondaryBackground: Container(
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete, color: Colors.white, size: 20),
                SizedBox(height: 2),
                Text(
                  "Eliminar",
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ],
            ),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              onEdit?.call();
              return false;
            } else {
              return await onDelete!(direction);
            }
          },
          child: cardContent,
        ),
      );
    }

    return Padding(
      padding: margin,
      child: cardContent,
    );
  }
}

