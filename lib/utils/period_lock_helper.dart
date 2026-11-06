/// Helper para la validacion de politicas de cierre de periodos financieros.
class PeriodLockHelper {
  static bool isPeriodLocked(DateTime transactionDate) {
    final now = DateTime.now();
    final minEditableDate = DateTime(now.year, now.month - 1, 1);
    final txDateOnly = DateTime(
      transactionDate.year,
      transactionDate.month,
      transactionDate.day,
    );
    return txDateOnly.isBefore(minEditableDate);
  }
}
