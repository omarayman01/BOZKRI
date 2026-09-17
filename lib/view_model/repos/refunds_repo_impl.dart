import '../../model/refund_model.dart';
import '../database/local/daos/refunds_dao.dart';
import '../errors/error_handler.dart';
import 'refunds_repo.dart';

class RefundsRepoImpl implements RefundsRepo {
  const RefundsRepoImpl(this._dao);

  final RefundsDao _dao;

  @override
  Future<List<RefundModel>> getForTransaction(int transactionId) =>
      guard(() => _dao.getForTransaction(transactionId));

  @override
  Future<Map<int, int>> refundedQtyByLine(int transactionId) =>
      guard(() => _dao.refundedQtyByLine(transactionId));

  @override
  Future<int> commitRefund({
    required int transactionId,
    required List<RefundLineInput> lines,
    String? reason,
    DateTime? dateTime,
  }) =>
      guard(() => _dao.commitRefund(
            transactionId: transactionId,
            lines: lines,
            reason: reason?.trim(),
            dateTime: dateTime,
          ));

  @override
  Future<void> deleteRefund(int refundId) =>
      guard(() => _dao.deleteRefund(refundId));
}
