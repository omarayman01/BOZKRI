import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile_model.freezed.dart';

enum UserRole { admin, staff }

UserRole userRoleFromString(String value) =>
    value == 'admin' ? UserRole.admin : UserRole.staff;

@freezed
class UserProfileModel with _$UserProfileModel {
  const factory UserProfileModel({
    required String id,
    required String email,
    required String displayName,
    required UserRole role,
    required bool isActive,
    required DateTime createdAt,
    DateTime? lastLoginAt,
  }) = _UserProfileModel;
}
