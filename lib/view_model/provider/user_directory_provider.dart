import 'package:flutter/foundation.dart';

import '../../model/user_profile_model.dart';
import '../repos/accounts_repo.dart';

/// Resolves a Supabase profile id (as stored in every synced row's
/// `updatedBy`) to a human-readable name, so "آخر تحديث بواسطة" can show a
/// name instead of a uuid. Loaded once at bootstrap and refreshed alongside
/// every other cache on each completed sync (see MainShell._refreshCubits),
/// so a newly added teammate's name resolves without a restart.
class UserDirectoryProvider extends ChangeNotifier {
  UserDirectoryProvider(this._repo);

  final AccountsRepo _repo;
  final Map<String, String> _namesById = <String, String>{};

  Future<void> load() async {
    try {
      final List<UserProfileModel> users = await _repo.listUsers();
      _namesById
        ..clear()
        ..addEntries(users.map(
          (UserProfileModel u) => MapEntry<String, String>(u.id, u.displayName),
        ));
      notifyListeners();
    } catch (_) {
      // Best-effort: a stale or empty directory just falls back to showing
      // the raw id — never blocks sync or the rest of bootstrap over this.
    }
  }

  /// The display name for a stamped `updatedBy` uuid, or null if unresolved
  /// (directory not loaded yet, or the user was since removed).
  String? nameFor(String? userId) =>
      userId == null ? null : _namesById[userId];
}
