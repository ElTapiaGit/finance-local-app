/// Helper para la validacion de politicas de cierre de periodos financieros.
class PeriodLockHelper {
  static bool isPeriodLocked(DateTime transactionDate) {
    final now = DateTime.now();
    // 1. Bloqueo estricto por antigüedad > 31 días
    if (now.difference(transactionDate).inDays > 31) return true;

    // 2. Mes actual siempre abierto
    if (transactionDate.year == now.year && transactionDate.month == now.month) return false;

    // 3. Mes anterior abierto SOLO si estamos en los días 1, 2 o 3, pero SIEMPRE que la transacción NO supere los 31 días de antigüedad.
    final previousMonth = DateTime(now.year, now.month - 1, 1);
    if (transactionDate.year == previousMonth.year && transactionDate.month == previousMonth.month) {
      if (now.day < 4 && now.difference(transactionDate).inDays <= 31) return false;
    }

    return true; // Todo lo demás queda bloqueado
  }
}
