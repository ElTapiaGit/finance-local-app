/// Helper para la validacion de politicas de cierre de periodos financieros.
class PeriodLockHelper {
  /// Determina si un periodo contable se encuentra cerrado para edicion o eliminacion.
  /// Si la fecha de la transaccion corresponde al mes y año actual, el periodo esta abierto.
  /// Para transacciones de meses anteriores, el periodo se bloquea a partir del dia 4 del mes corriente.
  static bool isPeriodLocked(DateTime transactionDate) {
    final now = DateTime.now();
    if (transactionDate.year == now.year && transactionDate.month == now.month) {
      return false;
    }
    if (now.day >= 4) {
      return true;
    }
    return false;
  }
}

