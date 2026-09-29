import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../model/user_profile_model.dart';
import '../../errors/failure.dart';
import '../../repos/accounts_repo.dart';
import 'accounts_state.dart';

/// Admin-only account management + audit trail (Phase 22 Accounts tab).
class AccountsCubit extends Cubit<AccountsState> {
  AccountsCubit(this._repo) : super(const AccountsState());

  final AccountsRepo _repo;

  Future<void> load() async {
    emit(state.copyWith(status: AccountsStatus.loading, clearError: true));
    try {
      final users = await _repo.listUsers();
      final auditLog = await _repo.listAuditLog();
      emit(state.copyWith(
        status: AccountsStatus.success,
        users: users,
        auditLog: auditLog,
      ));
    } on Failure catch (failure) {
      emit(state.copyWith(
        status: AccountsStatus.failure,
        errorMessage: failure.message,
      ));
    }
  }

  Future<bool> setActive(String userId, bool isActive) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _repo.setActive(userId, isActive);
      final users = await _repo.listUsers();
      emit(state.copyWith(users: users, isSaving: false));
      return true;
    } on Failure catch (failure) {
      emit(state.copyWith(isSaving: false, errorMessage: failure.message));
      return false;
    }
  }

  Future<bool> setRole(String userId, UserRole role) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _repo.setRole(userId, role);
      final users = await _repo.listUsers();
      emit(state.copyWith(users: users, isSaving: false));
      return true;
    } on Failure catch (failure) {
      emit(state.copyWith(isSaving: false, errorMessage: failure.message));
      return false;
    }
  }

  void clearError() => emit(state.copyWith(clearError: true));
}
