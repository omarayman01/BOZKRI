import '../../model/refund_model.dart';
import '../database/local/daos/refunds_dao.dart';

abstract class RefundsRepo {
  Future<List<RefundModel>> getForTransaction(int transactionId);

  /// Already-refunded quantity per deal line.
  Future<Map<int, int>> refundedQtyByLine(int transactionId);

  /// Atomic: refund + snapshot-copied lines + status update +
  /// single-use release.
  Future<int> commitRefund({
    required int transactionId,
    required List<RefundLineInput> lines,
    String? reason,
    DateTime? dateTime,
  });

  Future<void> deleteRefund(int refundId);
}
