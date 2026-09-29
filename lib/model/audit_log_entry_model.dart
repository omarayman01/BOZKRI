import 'package:freezed_annotation/freezed_annotation.dart';

part 'audit_log_entry_model.freezed.dart';

@freezed
class AuditLogEntryModel with _$AuditLogEntryModel {
  const factory AuditLogEntryModel({
    required String id,
    String? userId,
    String? userDisplayName,
    required String action,
    required String entityType,
    String? entityId,
    required String summary,
    required DateTime createdAt,
  }) = _AuditLogEntryModel;
}
