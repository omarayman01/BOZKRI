import 'package:equatable/equatable.dart';

import '../../../model/user_profile_model.dart';

enum AuthStatus {
  /// Still checking for an existing session at app start.
  unknown,
  unauthenticated,
  authenticating,
  authenticated,
}

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.profile,
    this.errorMessage,
    this.registrationSubmitted = false,
  });

  final AuthStatus status;
  final UserProfileModel? profile;
  final String? errorMessage;

  /// True right after a successful register call, before the user has
  /// logged in for the first time — drives the "pending approval" screen.
  final bool registrationSubmitted;

  AuthState copyWith({
    AuthStatus? status,
    UserProfileModel? profile,
    String? errorMessage,
    bool? registrationSubmitted,
    bool clearError = false,
    bool clearProfile = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      profile: clearProfile ? null : (profile ?? this.profile),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      registrationSubmitted:
          registrationSubmitted ?? this.registrationSubmitted,
    );
  }

  @override
  List<Object?> get props =>
      <Object?>[status, profile, errorMessage, registrationSubmitted];
}
