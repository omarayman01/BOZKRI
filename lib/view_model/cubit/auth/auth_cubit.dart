import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../errors/failure.dart';
import '../../provider/current_user_provider.dart';
import '../../repos/auth_repo.dart';
import 'auth_state.dart';

/// Drives the login/register/logout flow and keeps [CurrentUserProvider] in
/// sync with the active Supabase session, so the rest of the app can read
/// "who is logged in" without depending on this cubit directly.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repo, this._currentUser) : super(const AuthState()) {
    _sub = _repo.profileChanges().listen((profile) {
      _currentUser.setProfile(profile);
      if (profile == null) {
        emit(state.copyWith(status: AuthStatus.unauthenticated, clearProfile: true));
      } else {
        emit(state.copyWith(status: AuthStatus.authenticated, profile: profile));
      }
    });
    _bootstrap();
  }

  final AuthRepo _repo;
  final CurrentUserProvider _currentUser;
  late final StreamSubscription<dynamic> _sub;

  Future<void> _bootstrap() async {
    final profile = await _repo.currentProfile();
    _currentUser.setProfile(profile);
    emit(state.copyWith(
      status: profile == null ? AuthStatus.unauthenticated : AuthStatus.authenticated,
      profile: profile,
    ));
  }

  Future<bool> signIn({required String email, required String password}) async {
    emit(state.copyWith(status: AuthStatus.authenticating, clearError: true));
    try {
      final profile = await _repo.signIn(email: email, password: password);
      _currentUser.setProfile(profile);
      emit(state.copyWith(status: AuthStatus.authenticated, profile: profile));
      return true;
    } on Failure catch (failure) {
      emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: failure.message,
      ));
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    emit(state.copyWith(status: AuthStatus.authenticating, clearError: true));
    try {
      await _repo.register(email: email, password: password, displayName: displayName);
      emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        registrationSubmitted: true,
      ));
      return true;
    } on Failure catch (failure) {
      emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: failure.message,
      ));
      return false;
    }
  }

  void acknowledgeRegistration() =>
      emit(state.copyWith(registrationSubmitted: false));

  Future<void> signOut() async {
    await _repo.signOut();
    _currentUser.setProfile(null);
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  void clearError() => emit(state.copyWith(clearError: true));

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
