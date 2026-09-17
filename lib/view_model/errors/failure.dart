import 'package:equatable/equatable.dart';

/// Base type for every recoverable error surfaced to the UI layer.
///
/// Repositories throw subclasses of [Failure]; cubits catch them and emit a
/// failure state carrying [message] for display.
abstract class Failure extends Equatable implements Exception {
  const Failure(this.message, {this.cause});

  /// Human-readable, already-safe to display.
  final String message;

  /// The underlying exception, kept for logging only.
  final Object? cause;

  @override
  List<Object?> get props => <Object?>[message, runtimeType];

  @override
  String toString() => '$runtimeType: $message';
}

/// Input did not satisfy a business rule before it reached the database.
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.cause});
}

/// A requested row does not exist.
class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message, {super.cause});
}

/// Backup / restore file I/O failed.
class FileFailure extends Failure {
  const FileFailure(super.message, {super.cause});
}

/// Anything unclassified.
class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message, {super.cause});
}
