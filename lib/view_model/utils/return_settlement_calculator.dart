/// Pure computation for a car (or any per-day line) return settlement — no
/// database access, so the UI can preview it before the admin confirms.
class ReturnSettlementResult {
  const ReturnSettlementResult({
    required this.usedKm,
    required this.allowedTotal,
    required this.extraKm,
    required this.extraKmCharge,
    required this.finalLineTotal,
    required this.finalReceivable,
  });

  final double usedKm;
  final double allowedTotal;
  final double extraKm;
  final double extraKmCharge;
  final double finalLineTotal;
  final double finalReceivable;
}

class ReturnSettlementCalculator {
  const ReturnSettlementCalculator._();

  /// `days` is the line's *billed* days (Phase 3's possibly-overridden
  /// value) — the free-km budget intentionally uses the same number that
  /// pricing uses, so a manual days override also shifts the km allowance.
  static ReturnSettlementResult compute({
    required double pickupKilometer,
    required double returnKilometer,
    required double allowedKmPerDay,
    required int days,
    required double extraKmRate,
    required double pricePerDay,
    required double alreadyPaid,
  }) {
    final double usedKm = returnKilometer - pickupKilometer;
    final double allowedTotal = allowedKmPerDay * days;
    final double extraKm = usedKm > allowedTotal ? usedKm - allowedTotal : 0;
    final double extraKmCharge = extraKm * extraKmRate;
    final double finalLineTotal = (pricePerDay * days) + extraKmCharge;

    return ReturnSettlementResult(
      usedKm: usedKm,
      allowedTotal: allowedTotal,
      extraKm: extraKm,
      extraKmCharge: extraKmCharge,
      finalLineTotal: finalLineTotal,
      finalReceivable: finalLineTotal - alreadyPaid,
    );
  }
}
