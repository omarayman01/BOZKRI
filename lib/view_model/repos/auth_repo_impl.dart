import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../model/user_profile_model.dart';
import '../errors/failure.dart';
import 'auth_repo.dart';

class AuthRepoImpl implements AuthRepo {
  AuthRepoImpl(this._client);

  final SupabaseClient _client;

  UserProfileModel _mapRow(User authUser, Map<String, dynamic> row) {
    return UserProfileModel(
      id: authUser.id,
      email: authUser.email ?? '',
      displayName: row['display_name'] as String? ?? authUser.email ?? '',
      role: userRoleFromString(row['role'] as String? ?? 'staff'),
      isActive: row['is_active'] as bool? ?? false,
      createdAt: DateTime.parse(row['created_at'] as String),
      lastLoginAt: row['last_login_at'] == null
          ? null
          : DateTime.parse(row['last_login_at'] as String),
    );
  }

  Future<UserProfileModel?> _fetchProfile(User authUser) async {
    try {
      final Map<String, dynamic>? row = await _client
          .from('profiles')
          .select()
          .eq('id', authUser.id)
          .maybeSingle();
      if (row == null) return null;
      return _mapRow(authUser, row);
    } on PostgrestException catch (e) {
      throw UnexpectedFailure('تعذر جلب بيانات الحساب', cause: e);
    }
  }

  @override
  Future<UserProfileModel?> currentProfile() async {
    final User? authUser = _client.auth.currentUser;
    if (authUser == null) return null;
    return _fetchProfile(authUser);
  }

  @override
  Stream<UserProfileModel?> profileChanges() {
    return _client.auth.onAuthStateChange.asyncMap((AuthState state) async {
      final User? authUser = state.session?.user;
      if (authUser == null) return null;
      return _fetchProfile(authUser);
    });
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      await _client.auth.signUp(
        email: email,
        password: password,
        data: <String, dynamic>{'display_name': displayName},
      );
    } on AuthException catch (e) {
      throw ValidationFailure(_mapAuthError(e), cause: e);
    }
  }

  @override
  Future<UserProfileModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final AuthResponse res = await _client.auth
          .signInWithPassword(email: email, password: password);
      final User? authUser = res.user;
      if (authUser == null) {
        throw const ValidationFailure('تعذر تسجيل الدخول');
      }
      final UserProfileModel? profile = await _fetchProfile(authUser);
      if (profile == null) {
        throw const UnexpectedFailure('لم يتم العثور على بيانات الحساب');
      }
      if (!profile.isActive) {
        await _client.auth.signOut();
        throw const ValidationFailure(
          'الحساب بانتظار موافقة المسؤول ولا يمكن استخدامه بعد',
        );
      }
      await _client
          .from('profiles')
          .update(<String, dynamic>{
            'last_login_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', authUser.id);
      return profile;
    } on AuthException catch (e) {
      throw ValidationFailure(_mapAuthError(e), cause: e);
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  String _mapAuthError(AuthException e) {
    switch (e.message) {
      case 'Invalid login credentials':
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      default:
        if (e.message.toLowerCase().contains('already registered')) {
          return 'هذا البريد الإلكتروني مسجل بالفعل';
        }
        if (e.message.toLowerCase().contains('password')) {
          return 'كلمة المرور ضعيفة جداً — يجب ألا تقل عن 6 أحرف';
        }
        return 'حدث خطأ أثناء الاتصال بالخادم';
    }
  }
}
