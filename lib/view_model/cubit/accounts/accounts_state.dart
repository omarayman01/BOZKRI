import 'package:equatable/equatable.dart';

import '../../../model/audit_log_entry_model.dart';
import '../../../model/user_profile_model.dart';

enum AccountsStatus { initial, loading, success, failure }

class AccountsState extends Equatable {
  const AccountsState({
    this.status = AccountsStatus.initial,
    this.users = const <UserProfileModel>[],
    this.auditLog = const <AuditLogEntryModel>[],
    this.errorMessage,
    this.isSaving = false,
  });

  final AccountsStatus status;
  final List<UserProfileModel> users;
  final List<AuditLogEntryModel> auditLog;
  final String? errorMessage;
  final bool isSaving;

  bool get isLoading => status == AccountsStatus.loading;
  bool get isFailure => status == AccountsStatus.failure;

  AccountsState copyWith({
    AccountsStatus? status,
    List<UserProfileModel>? users,
    List<AuditLogEntryModel>? auditLog,
    String? errorMessage,
    bool? isSaving,
    bool clearError = false,
  }) {
    return AccountsState(
      status: status ?? this.status,
      users: users ?? this.users,
      auditLog: auditLog ?? this.auditLog,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSaving: isSaving ?? this.isSaving,
    );
  }

  @override
  List<Object?> get props =>
      <Object?>[status, users, auditLog, errorMessage, isSaving];
}
