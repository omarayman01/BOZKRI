import '../../model/user_profile_model.dart';

/// Wraps Supabase Auth + the `profiles` table (Phase 22). Every method throws
/// a [Failure] subclass on error — see `view_model/errors/failure.dart`.
abstract class AuthRepo {
  /// The signed-in user's profile, or null if no session exists. Does not
  /// hit the network for the session check itself, only for the profile row.
  Future<UserProfileModel?> currentProfile();

  Stream<UserProfileModel?> profileChanges();

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  });

  /// Returns the signed-in profile. Throws [ValidationFailure] if the
  /// account exists but is not yet approved ([UserProfileModel.isActive]
  /// false) — the caller should sign the session back out in that case.
  Future<UserProfileModel> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();
}
