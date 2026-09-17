import 'failure.dart';

/// Any error originating from the local SQLite database.
class DbFailure extends Failure {
  const DbFailure(super.message, {super.cause});
}

/// A single-use item was already consumed by another deal.
///
/// Thrown from inside the commit / edit Drift transaction after the
/// availability re-check fails, which rolls the whole transaction back.
class ItemUnavailableFailure extends Failure {
  const ItemUnavailableFailure(
    super.message, {
    required this.itemId,
    this.itemLabel,
    super.cause,
  });

  final int itemId;
  final String? itemLabel;

  @override
  List<Object?> get props => <Object?>[message, itemId, itemLabel];
}

/// A row could not be inserted or updated because it violates a constraint
/// (unique name, foreign key, non-null).
class ConstraintFailure extends DbFailure {
  const ConstraintFailure(super.message, {super.cause});
}
