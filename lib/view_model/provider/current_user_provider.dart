import 'package:flutter/foundation.dart';

import '../../model/user_profile_model.dart';

/// The signed-in user's profile, available app-wide without depending on
/// [AuthCubit] directly — every write path that needs to stamp "who did
/// this" (Phase 21's `updatedByUserId`, Phase 22's audit log) reads this.
class CurrentUserProvider extends ChangeNotifier {
  UserProfileModel? _profile;

  UserProfileModel? get profile => _profile;
  String? get userId => _profile?.id;
  bool get isAdmin => _profile?.role == UserRole.admin;

  void setProfile(UserProfileModel? profile) {
    _profile = profile;
    notifyListeners();
  }
}
