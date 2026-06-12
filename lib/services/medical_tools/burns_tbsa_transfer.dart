/// Repasse opcional de % SCQ entre Regra dos 9 e Regra de Parkland.
abstract final class BurnsTbsaTransfer {
  static double? pendingPercent;

  static void setPercent(double percent) {
    pendingPercent = percent.clamp(0, 100);
  }

  /// Lê e limpa o valor pendente (uso único ao abrir Parkland).
  static double? consumePercent() {
    final value = pendingPercent;
    pendingPercent = null;
    return value;
  }
}
