import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../provider/connectivity_provider.dart';
import '../../sync/sync_engine.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_state.dart';
import 'sync_state.dart';

/// Drives the offline/sync badge: reacts to connectivity changes, runs a
/// periodic background sync while online, and exposes a manual trigger.
///
/// Sync never runs before the user is actually authenticated — every
/// Supabase table requires an authenticated session (RLS denies anonymous
/// access outright), so attempting a sync beforehand always failed and left
/// the badge stuck on "خطأ في المزامنة" the moment the login screen (or the
/// app itself) first appeared, even before anyone had logged in. Instead,
/// this cubit watches [AuthCubit] and fires an immediate full sync the
/// moment login succeeds, so the local database is refreshed from Supabase
/// right away rather than waiting for the next periodic tick.
class SyncCubit extends Cubit<SyncCubitState> {
  SyncCubit(this._engine, this._connectivity, this._auth)
      : super(const SyncCubitState()) {
    _applyConnectivity();
    _connectivity.addListener(_applyConnectivity);
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => syncNow());

    _authSub = _auth.stream.listen((AuthState authState) {
      if (authState.status == AuthStatus.authenticated) {
        syncNow();
      }
    });
    if (_auth.state.status == AuthStatus.authenticated) syncNow();
  }

  final SyncEngine _engine;
  final ConnectivityProvider _connectivity;
  final AuthCubit _auth;
  late final Timer _timer;
  late final StreamSubscription<AuthState> _authSub;

  void _applyConnectivity() {
    if (!_connectivity.isOnline) {
      emit(state.copyWith(status: SyncStatus.offline));
    } else if (state.status == SyncStatus.offline) {
      syncNow();
    }
  }

  Future<void> syncNow() async {
    if (_auth.state.status != AuthStatus.authenticated) return;
    if (!_connectivity.isOnline) {
      emit(state.copyWith(status: SyncStatus.offline));
      return;
    }
    emit(state.copyWith(status: SyncStatus.syncing, clearError: true));
    try {
      final SyncResult result = await _engine.syncAll();
      if (result.hasError) {
        emit(state.copyWith(
          status: SyncStatus.error,
          errorMessage: result.errors.first,
        ));
      } else {
        emit(state.copyWith(
          status: SyncStatus.synced,
          lastSyncedAt: DateTime.now(),
          lastPulled: result.pulled,
          syncVersion: state.syncVersion + 1,
        ));
      }
    } catch (e) {
      emit(state.copyWith(status: SyncStatus.error, errorMessage: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _timer.cancel();
    _connectivity.removeListener(_applyConnectivity);
    _authSub.cancel();
    return super.close();
  }
}
