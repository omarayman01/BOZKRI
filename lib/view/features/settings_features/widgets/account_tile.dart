import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../../view_model/cubit/auth/auth_cubit.dart';
import '../../../../view_model/provider/current_user_provider.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';

/// Shows the signed-in account and a logout action (Phase 22).
class AccountTile extends StatelessWidget {
  const AccountTile({super.key});

  /// Settings is pushed as a route on top of the AuthGate/shell — signing
  /// out changes AuthCubit's state, but that alone doesn't pop this screen
  /// off the navigation stack, so the admin would otherwise stay stuck on
  /// Settings after logging out. Pop back to the root route first, so the
  /// now-rebuilt AuthGate (showing the login screen) is what's visible.
  Future<void> _signOut(BuildContext context) async {
    final AuthCubit auth = context.read<AuthCubit>();
    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
    await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<CurrentUserProvider>().profile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('الحساب', style: AppTextStyles.label),
        const SizedBox(height: 10),
        if (profile != null) ...<Widget>[
          Text(profile.displayName, style: AppTextStyles.body),
          const SizedBox(height: 2),
          Text(
            profile.email,
            style: AppTextStyles.caption.copyWith(color: AppColors.secondary),
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: 16),
        ],
        PrimaryButton(
          label: 'تسجيل الخروج',
          isDestructive: true,
          onPressed: () => _signOut(context),
        ),
      ],
    );
  }
}
