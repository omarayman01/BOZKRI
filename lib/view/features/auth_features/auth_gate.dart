import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../view_model/cubit/auth/auth_cubit.dart';
import '../../../view_model/cubit/auth/auth_state.dart';
import '../../core/navigation/main_shell.dart';
import 'login_screen.dart';

/// Root gate: shows the login flow until there is an authenticated, approved
/// session, then mounts the real app. No screen behind this is reachable
/// otherwise (Phase 22 acceptance criteria).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (BuildContext context, AuthState state) {
        switch (state.status) {
          case AuthStatus.unknown:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          case AuthStatus.authenticated:
            return const MainShell();
          case AuthStatus.unauthenticated:
          case AuthStatus.authenticating:
            return const LoginScreen();
        }
      },
    );
  }
}
