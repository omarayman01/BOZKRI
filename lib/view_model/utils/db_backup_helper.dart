import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../view/constants/app_constants.dart';
import '../database/local/app_database.dart';
import '../errors/failure.dart';

/// File-level backup and restore of the SQLite database, to an
/// admin-chosen destination — a folder picked via [pickBackupDestinationFolder]
/// or a typed/pasted absolute path.
///
/// The live connection is always checkpointed and closed first, so the file
/// on disk is never copied in a WAL-inconsistent state.
class DbBackupHelper {
  const DbBackupHelper._();

  /// File name for a `.sqlite` backup, shared with the matching `.xlsx`
  /// report so the two files are easy to pair up.
  static String backupFileName(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    final String stamp =
        '${at.year}-${two(at.month)}-${two(at.day)}_${two(at.hour)}${two(at.minute)}';
    return 'bozkri_$stamp.${AppConstants.backupFileExtension}';
  }

  /// Opens a folder-picker dialog and returns the chosen directory, or null
  /// if cancelled. Used when the admin chooses "browse" instead of typing a
  /// path for Backup.
  static Future<String?> pickBackupDestinationFolder() {
    return FilePicker.platform.getDirectoryPath(
      dialogTitle: 'اختر مجلداً لحفظ النسخة الاحتياطية',
    );
  }

  /// Opens a file-picker dialog accepting `.sqlite` or `.xlsx`, returning
  /// the chosen path or null if cancelled. Used by Restore.
  static Future<String?> pickRestoreSourceFile() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: 'اختر ملف الاستعادة',
      type: FileType.custom,
      allowedExtensions: <String>['sqlite', 'xlsx'],
    );
    return result?.files.single.path;
  }

  /// Resolves [typedPath] (or, if null, whatever the admin already picked
  /// via a folder dialog) into a usable destination directory: creates it
  /// if missing, then verifies it is writable. Throws a clear Arabic
  /// [FileFailure] if the path cannot be used.
  static Future<Directory> resolveDestination(String path) async {
    final Directory dir = Directory(path);
    if (!dir.existsSync()) {
      try {
        dir.createSync(recursive: true);
      } catch (error) {
        throw FileFailure(
          'تعذر إنشاء المجلد: $path',
          cause: error,
        );
      }
    }
    await _assertWritable(dir);
    return dir;
  }

  /// Retries [op] on `FileSystemException` — Windows does not always
  /// release a just-closed native SQLite handle's OS-level file lock in the
  /// same tick `close()` returns (antivirus scanning and delayed handle
  /// teardown are common additional causes), so a transient lock error
  /// right after `checkpointAndClose()` is a realistic failure mode here.
  /// Any other exception is rethrown immediately, unretried.
  static Future<T> _withRetry<T>(
    Future<T> Function() op, {
    int attempts = 5,
    Duration delay = const Duration(milliseconds: 150),
  }) async {
    for (int attempt = 1; ; attempt++) {
      try {
        return await op();
      } on FileSystemException {
        if (attempt >= attempts) rethrow;
        await Future<void>.delayed(delay);
      }
    }
  }

  static Future<void> _assertWritable(Directory dir) async {
    final File probe =
        File(p.join(dir.path, '.bozkri_write_test_${DateTime.now().microsecondsSinceEpoch}'));
    try {
      probe.writeAsStringSync('ok');
      probe.deleteSync();
    } catch (error) {
      throw FileFailure(
        'المجلد غير قابل للكتابة: ${dir.path}',
        cause: error,
      );
    }
  }

  /// Checkpoints and closes the live database, then copies it into
  /// [destination]. Returns the written path.
  static Future<String> backupTo({
    required AppDatabase database,
    required Directory destination,
    required DateTime at,
  }) async {
    try {
      final File source = await AppDatabase.databaseFile();
      if (!source.existsSync()) {
        throw const FileFailure('لا توجد قاعدة بيانات لعمل نسخة احتياطية منها بعد.');
      }

      // Fold the WAL into the main file, then release the connection.
      await database.checkpointAndClose();

      final File destinationFile =
          File(p.join(destination.path, backupFileName(at)));
      await _withRetry(() => source.copy(destinationFile.path));
      return destinationFile.path;
    } on Failure {
      rethrow;
    } catch (error) {
      throw FileFailure('فشل إنشاء النسخة الاحتياطية: $error', cause: error);
    }
  }

  /// Replaces the live database with the `.sqlite` file at [sourcePath]
  /// after validating it.
  ///
  /// A timestamped safety copy of the current file is kept alongside it, so
  /// a bad restore is always recoverable and repeated restores never
  /// clobber an earlier safety copy. The live database is never touched
  /// until validation passes.
  static Future<void> restoreFromSqlite({
    required AppDatabase database,
    required String sourcePath,
  }) async {
    try {
      final File source = File(sourcePath);
      if (!source.existsSync()) {
        throw const FileFailure('الملف المختار غير موجود.');
      }
      if (!AppDatabase.isValidBackup(source)) {
        throw const FileFailure(
          'هذا الملف ليس نسخة احتياطية صالحة لنظام إدارة الوكالة.',
        );
      }

      final File target = await AppDatabase.databaseFile();

      await database.checkpointAndClose();

      if (target.existsSync()) {
        final String stamp = backupFileName(DateTime.now());
        final String safety = '${target.path}.pre-restore-$stamp';
        await _withRetry(() => target.copy(safety));
      }

      // Remove stale WAL / SHM siblings so the restored file is authoritative.
      for (final String suffix in <String>['-wal', '-shm']) {
        final File sibling = File('${target.path}$suffix');
        if (sibling.existsSync()) {
          await _withRetry(() => sibling.delete());
        }
      }

      await _withRetry(() => source.copy(target.path));
    } on Failure {
      rethrow;
    } catch (error) {
      throw FileFailure('فشلت عملية الاستعادة: $error', cause: error);
    }
  }
}
