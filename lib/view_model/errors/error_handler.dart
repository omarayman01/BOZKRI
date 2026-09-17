import 'package:drift/drift.dart';
import 'package:sqlite3/common.dart';

import 'db_failure.dart';
import 'failure.dart';

/// Maps raw exceptions from the data layer onto typed [Failure]s.
///
/// Repository implementations wrap every DAO call in [guard] so that the
/// cubits above only ever have to catch [Failure].
class ErrorHandler {
  const ErrorHandler._();

  static Failure map(Object error, [StackTrace? stackTrace]) {
    if (error is Failure) return error;

    if (error is SqliteException) {
      final String msg = error.message.toLowerCase();
      if (msg.contains('unique')) {
        return ConstraintFailure(
          'A record with these details already exists.',
          cause: error,
        );
      }
      if (msg.contains('foreign key')) {
        return ConstraintFailure(
          'This record is still referenced by other data.',
          cause: error,
        );
      }
      if (msg.contains('not null')) {
        return const ConstraintFailure('A required value is missing.');
      }
      return DbFailure('Database error: ${error.message}', cause: error);
    }

    if (error is DriftWrappedException) {
      final Object? cause = error.cause;
      if (cause != null) return map(cause, stackTrace);
      return DbFailure(error.message, cause: error);
    }

    if (error is InvalidDataException) {
      return ConstraintFailure(error.message, cause: error);
    }

    if (error is CouldNotRollBackException) {
      return DbFailure(
        'The operation failed and could not be rolled back cleanly.',
        cause: error,
      );
    }

    if (error is StateError) {
      return NotFoundFailure(error.message, cause: error);
    }

    return UnexpectedFailure(
      'Something went wrong. Please try again.',
      cause: error,
    );
  }
}

/// Runs [action], converting any thrown object into a [Failure].
Future<T> guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (error, stackTrace) {
    throw ErrorHandler.map(error, stackTrace);
  }
}
