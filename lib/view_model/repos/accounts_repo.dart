import '../../model/audit_log_entry_model.dart';
import '../../model/user_profile_model.dart';

/// Admin-only account management + the action audit trail (Phase 22).
/// Every method throws a [Failure] subclass on error.
abstract class AccountsRepo {
  Future<List<UserProfileModel>> listUsers();

  Future<void> setActive(String userId, bool isActive);

  Future<void> setRole(String userId, UserRole role);

  Future<List<AuditLogEntryModel>> listAuditLog({int limit = 200});
}
