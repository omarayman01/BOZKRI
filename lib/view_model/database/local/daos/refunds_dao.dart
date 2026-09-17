import 'package:drift/drift.dart';

import '../../../../model/refund_item_model.dart';
import '../../../../model/refund_model.dart';
import '../../../../model/transaction_model.dart';
import '../../../errors/db_failure.dart';
import '../app_database.dart';
import '../mappers.dart';
import '../tables.dart';

part 'refunds_dao.g.dart';

/// One requested refund line: how many units of a deal line to give back.
class RefundLineInput {
  const RefundLineInput({required this.transactionItemId, required this.qty});

  final int transactionItemId;
  final int qty;
}

@DriftAccessor(tables: <Type>[
  Refunds,
  RefundItems,
  Transactions,
  TransactionItems,
  Items,
])
class RefundsDao extends DatabaseAccessor<AppDatabase> with _$RefundsDaoMixin {
  RefundsDao(super.db);

  Future<List<RefundModel>> getForTransaction(int transactionId) async {
    final List<RefundRow> rows = await (select(refunds)
          ..where(($RefundsTable t) => t.transactionId.equals(transactionId))
          ..orderBy(<OrderClauseGenerator<$RefundsTable>>[
            (($RefundsTable t) => OrderingTerm.desc(t.occurredAt)),
          ]))
        .get();
    if (rows.isEmpty) return <RefundModel>[];

    final List<int> ids = rows.map((RefundRow r) => r.id).toList();
    final String placeholders = List<String>.filled(ids.length, '?').join(',');
    final List<QueryRow> itemRows = await customSelect(
      '''
      SELECT ri.*, i.label AS item_label
      FROM refund_items ri
      JOIN items i ON i.id = ri.item_id
      WHERE ri.refund_id IN ($placeholders)
      ''',
      variables: ids.map((int e) => Variable<int>(e)).toList(),
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{
        refundItems,
        items,
      },
    ).get();

    final Map<int, List<RefundItemModel>> byRefund =
        <int, List<RefundItemModel>>{};
    for (final QueryRow r in itemRows) {
      final RefundItemModel m = refundItems
          .map(r.data, tablePrefix: null)
          .toModel(itemLabel: r.read<String>('item_label'));
      byRefund.putIfAbsent(m.refundId, () => <RefundItemModel>[]).add(m);
    }

    return rows
        .map((RefundRow r) =>
            r.toModel(items: byRefund[r.id] ?? const <RefundItemModel>[]))
        .toList();
  }

  /// Already-refunded quantity per deal line, used to cap the refundable qty.
  Future<Map<int, int>> refundedQtyByLine(int transactionId) async {
    final List<QueryRow> rows = await customSelect(
      '''
      SELECT ri.transaction_item_id AS line_id, SUM(ri.qty) AS q
      FROM refund_items ri
      JOIN transaction_items ti ON ti.id = ri.transaction_item_id
      WHERE ti.transaction_id = ?
      GROUP BY ri.transaction_item_id
      ''',
      variables: <Variable<Object>>[Variable<int>(transactionId)],
      readsFrom: <ResultSetImplementation<HasResultSet, Object>>{
        refundItems,
        transactionItems,
      },
    ).get();

    return <int, int>{
      for (final QueryRow r in rows) r.read<int>('line_id'): r.read<int>('q'),
    };
  }

  /// Inserts the refund, its snapshot-copied lines, updates the deal status
  /// and releases fully-refunded single-use items — all atomically.
  Future<int> commitRefund({
    required int transactionId,
    required List<RefundLineInput> lines,
    String? reason,
    DateTime? dateTime,
  }) {
    return transaction(() async {
      final List<RefundLineInput> requested = lines
          .where((RefundLineInput l) => l.qty > 0)
          .toList();
      if (requested.isEmpty) {
        throw const ConstraintFailure('Select at least one line to refund.');
      }

      final List<TransactionItemRow> dealLines = await (select(transactionItems)
            ..where(($TransactionItemsTable t) =>
                t.transactionId.equals(transactionId)))
          .get();
      final Map<int, TransactionItemRow> byId = <int, TransactionItemRow>{
        for (final TransactionItemRow l in dealLines) l.id: l,
      };
      final Map<int, int> alreadyRefunded =
          await refundedQtyByLine(transactionId);

      double totalRefunded = 0;
      double totalCostRefunded = 0;

      for (final RefundLineInput input in requested) {
        final TransactionItemRow? line = byId[input.transactionItemId];
        if (line == null) {
          throw const ConstraintFailure(
              'A selected line does not belong to this deal.');
        }
        final int remaining =
            line.qty - (alreadyRefunded[line.id] ?? 0);
        if (input.qty > remaining) {
          throw ConstraintFailure(
            'Cannot refund ${input.qty} of a line with only $remaining left.',
          );
        }
        // Snapshots are copied from the original line, never re-read from the
        // live item.
        totalRefunded += line.unitPrice * input.qty;
        totalCostRefunded += line.unitCost * input.qty;
      }

      final int refundId = await into(refunds).insert(
        RefundsCompanion.insert(
          transactionId: transactionId,
          occurredAt: dateTime ?? DateTime.now(),
          totalRefunded: totalRefunded,
          totalCostRefunded: totalCostRefunded,
          reason: Value<String?>(reason),
        ),
      );

      await batch((Batch b) {
        b.insertAll(
          refundItems,
          requested.map((RefundLineInput input) {
            final TransactionItemRow line = byId[input.transactionItemId]!;
            return RefundItemsCompanion.insert(
              refundId: refundId,
              transactionItemId: line.id,
              itemId: line.itemId,
              qty: input.qty,
              unitCost: line.unitCost,
              unitPrice: line.unitPrice,
            );
          }).toList(),
        );
      });

      // Release single-use items whose line is now fully refunded.
      final Map<int, int> afterRefund = await refundedQtyByLine(transactionId);
      for (final TransactionItemRow line in dealLines) {
        final int refunded = afterRefund[line.id] ?? 0;
        if (refunded >= line.qty) {
          await (update(items)
                ..where(($ItemsTable t) =>
                    t.id.equals(line.itemId) & t.isSingleUse.equals(true)))
              .write(const ItemsCompanion(isAvailable: Value<bool>(true)));
        }
      }

      await _refreshStatus(transactionId, dealLines, afterRefund);
      return refundId;
    });
  }

  Future<void> _refreshStatus(
    int transactionId,
    List<TransactionItemRow> dealLines,
    Map<int, int> refundedByLine,
  ) async {
    final int totalQty = dealLines.fold<int>(
        0, (int sum, TransactionItemRow l) => sum + l.qty);
    final int refundedQty = dealLines.fold<int>(
        0, (int sum, TransactionItemRow l) => sum + (refundedByLine[l.id] ?? 0));

    final TransactionStatus status = refundedQty <= 0
        ? TransactionStatus.active
        : refundedQty >= totalQty
            ? TransactionStatus.fullyRefunded
            : TransactionStatus.partiallyRefunded;

    await (update(transactions)
          ..where(($TransactionsTable t) => t.id.equals(transactionId)))
        .write(TransactionsCompanion(status: Value<String>(status.name)));
  }

  /// Reverses a refund: removes it, restores the deal status and re-consumes
  /// single-use items that had been released.
  Future<void> deleteRefund(int refundId) {
    return transaction(() async {
      final RefundRow? refund = await (select(refunds)
            ..where(($RefundsTable t) => t.id.equals(refundId)))
          .getSingleOrNull();
      if (refund == null) {
        throw const ConstraintFailure('This refund no longer exists.');
      }

      await (delete(refunds)..where(($RefundsTable t) => t.id.equals(refundId)))
          .go();

      final List<TransactionItemRow> dealLines = await (select(transactionItems)
            ..where(($TransactionItemsTable t) =>
                t.transactionId.equals(refund.transactionId)))
          .get();
      final Map<int, int> refunded =
          await refundedQtyByLine(refund.transactionId);

      for (final TransactionItemRow line in dealLines) {
        if ((refunded[line.id] ?? 0) < line.qty) {
          await (update(items)
                ..where(($ItemsTable t) =>
                    t.id.equals(line.itemId) & t.isSingleUse.equals(true)))
              .write(const ItemsCompanion(isAvailable: Value<bool>(false)));
        }
      }

      await _refreshStatus(refund.transactionId, dealLines, refunded);
    });
  }
}
