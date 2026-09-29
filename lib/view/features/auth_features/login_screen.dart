import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../view_model/cubit/auth/auth_cubit.dart';
import '../../../view_model/cubit/auth/auth_state.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/offline_banner.dart';
import '../../core/widgets/primary_button.dart';
import 'register_screen.dart';

/// Shown whenever there is no active, approved session. The rest of the app
/// (deals, cars, expenses…) only mounts past this screen.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await context.read<AuthCubit>().signIn(
          email: _email.text.trim(),
          password: _password.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: <Widget>[
          const OfflineBanner(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: BlocConsumer<AuthCubit, AuthState>(
                    listener: (BuildContext context, AuthState state) {
                      if (state.errorMessage != null) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(
                            content: Text(state.errorMessage!),
                            backgroundColor: AppColors.danger,
                          ));
                        context.read<AuthCubit>().clearError();
                      }
                    },
                    builder: (BuildContext context, AuthState state) {
                      final bool loading =
                          state.status == AuthStatus.authenticating;
                      return Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const Center(child: AppLogo(height: 56)),
                            const SizedBox(height: 24),
                            Text(
                              'تسجيل الدخول',
                              style: AppTextStyles.title,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 28),
                            AppTextField(
                              label: 'البريد الإلكتروني',
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              textDirection: TextDirection.ltr,
                              validator: (String? v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'أدخل البريد الإلكتروني'
                                      : null,
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              label: 'كلمة المرور',
                              controller: _password,
                              obscureText: true,
                              textDirection: TextDirection.ltr,
                              validator: (String? v) => (v == null || v.isEmpty)
                                  ? 'أدخل كلمة المرور'
                                  : null,
                            ),
                            const SizedBox(height: 24),
                            PrimaryButton(
                              label: 'دخول',
                              isLoading: loading,
                              expand: true,
                              onPressed: loading ? null : _submit,
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: loading
                                  ? null
                                  : () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const RegisterScreen(),
                                        ),
                                      ),
                              child:
                                  const Text('ليس لديك حساب؟ إنشاء حساب جديد'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
