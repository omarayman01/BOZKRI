import 'package:equatable/equatable.dart';

enum SyncStatus { offline, syncing, synced, error }

class SyncCubitState extends Equatable {
  const SyncCubitState({
    this.status = SyncStatus.synced,
    this.lastSyncedAt,
    this.errorMessage,
    this.lastPulled = 0,
    this.syncVersion = 0,
  });

  final SyncStatus status;
  final DateTime? lastSyncedAt;
  final String? errorMessage;

  /// How many rows the most recently completed sync pulled from Supabase.
  final int lastPulled;

  /// Bumped on every completed sync (whether or not anything was pulled), so
  /// listeners can tell one "synced" state apart from the next even when
  /// [lastPulled] is repeatedly 0.
  final int syncVersion;

  SyncCubitState copyWith({
    SyncStatus? status,
    DateTime? lastSyncedAt,
    String? errorMessage,
    bool clearError = false,
    int? lastPulled,
    int? syncVersion,
  }) {
    return SyncCubitState(
      status: status ?? this.status,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastPulled: lastPulled ?? this.lastPulled,
      syncVersion: syncVersion ?? this.syncVersion,
    );
  }

  @override
  List<Object?> get props =>
      <Object?>[status, lastSyncedAt, errorMessage, lastPulled, syncVersion];
}
