import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../view_model/cubit/auth/auth_cubit.dart';
import '../../../view_model/cubit/auth/auth_state.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/primary_button.dart';

/// Self-registration creates an inactive account — an admin must approve it
/// from the Accounts tab before it can be used (Phase 22).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final bool ok = await context.read<AuthCubit>().register(
          email: _email.text.trim(),
          password: _password.text,
          displayName: _name.text.trim(),
        );
    if (ok && mounted) {
      context.read<AuthCubit>().acknowledgeRegistration();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم إنشاء الحساب — بانتظار موافقة المسؤول'),
      ));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('إنشاء حساب جديد')),
      body: Center(
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
                final bool loading = state.status == AuthStatus.authenticating;
                return Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'سيحتاج حسابك إلى موافقة المسؤول قبل تسجيل الدخول',
                        style: AppTextStyles.caption,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      AppTextField(
                        label: 'الاسم',
                        controller: _name,
                        validator: (String? v) =>
                            (v == null || v.trim().isEmpty) ? 'أدخل الاسم' : null,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'البريد الإلكتروني',
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        validator: (String? v) => (v == null || v.trim().isEmpty)
                            ? 'أدخل البريد الإلكتروني'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'كلمة المرور',
                        controller: _password,
                        obscureText: true,
                        textDirection: TextDirection.ltr,
                        helper: '6 أحرف على الأقل',
                        validator: (String? v) => (v == null || v.length < 6)
                            ? 'كلمة المرور قصيرة جداً'
                            : null,
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: 'إنشاء حساب',
                        isLoading: loading,
                        expand: true,
                        onPressed: loading ? null : _submit,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
