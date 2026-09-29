import 'package:supabase_flutter/supabase_flutter.dart';

import '../../model/audit_log_entry_model.dart';
import '../../model/user_profile_model.dart';
import '../errors/failure.dart';
import 'accounts_repo.dart';

class AccountsRepoImpl implements AccountsRepo {
  AccountsRepoImpl(this._client);

  final SupabaseClient _client;

  UserProfileModel _mapProfile(Map<String, dynamic> row) {
    return UserProfileModel(
      id: row['id'] as String,
      email: row['email'] as String? ?? '',
      displayName: row['display_name'] as String? ?? '',
      role: userRoleFromString(row['role'] as String? ?? 'staff'),
      isActive: row['is_active'] as bool? ?? false,
      createdAt: DateTime.parse(row['created_at'] as String),
      lastLoginAt: row['last_login_at'] == null
          ? null
          : DateTime.parse(row['last_login_at'] as String),
    );
  }

  @override
  Future<List<UserProfileModel>> listUsers() async {
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('profiles')
          .select()
          .order('created_at', ascending: true);
      return rows.map(_mapProfile).toList();
    } on PostgrestException catch (e) {
      throw UnexpectedFailure('تعذر تحميل قائمة المستخدمين', cause: e);
    }
  }

  @override
  Future<void> setActive(String userId, bool isActive) async {
    try {
      await _client
          .from('profiles')
          .update(<String, dynamic>{'is_active': isActive})
          .eq('id', userId);
    } on PostgrestException catch (e) {
      throw UnexpectedFailure('تعذر تحديث حالة المستخدم', cause: e);
    }
  }

  @override
  Future<void> setRole(String userId, UserRole role) async {
    try {
      await _client
          .from('profiles')
          .update(<String, dynamic>{
            'role': role == UserRole.admin ? 'admin' : 'staff',
          })
          .eq('id', userId);
    } on PostgrestException catch (e) {
      throw UnexpectedFailure('تعذر تحديث صلاحية المستخدم', cause: e);
    }
  }

  @override
  Future<List<AuditLogEntryModel>> listAuditLog({int limit = 200}) async {
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('audit_log')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      if (rows.isEmpty) return <AuditLogEntryModel>[];

      final Set<String> userIds = rows
          .map((Map<String, dynamic> r) => r['user_id'] as String?)
          .whereType<String>()
          .toSet();
      final Map<String, String> namesByUserId = <String, String>{};
      if (userIds.isNotEmpty) {
        final List<Map<String, dynamic>> profileRows = await _client
            .from('profiles')
            .select('id, display_name')
            .inFilter('id', userIds.toList());
        for (final Map<String, dynamic> p in profileRows) {
          namesByUserId[p['id'] as String] = p['display_name'] as String? ?? '';
        }
      }

      return rows
          .map((Map<String, dynamic> r) => AuditLogEntryModel(
                id: r['id'] as String,
                userId: r['user_id'] as String?,
                userDisplayName: namesByUserId[r['user_id']],
                action: r['action'] as String,
                entityType: r['entity_type'] as String,
                entityId: r['entity_id'] as String?,
                summary: r['summary'] as String,
                createdAt: DateTime.parse(r['created_at'] as String),
              ))
          .toList();
    } on PostgrestException catch (e) {
      throw UnexpectedFailure('تعذر تحميل سجل النشاط', cause: e);
    }
  }
}
