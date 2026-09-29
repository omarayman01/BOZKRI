import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../model/user_profile_model.dart';
import '../../../../view_model/cubit/accounts/accounts_cubit.dart';
import '../../../../view_model/utils/date_utils.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_constants.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/widgets/confirm_dialog.dart';

/// One row in the Accounts tab: name/email, role, active toggle, last login.
class UserRow extends StatelessWidget {
  const UserRow({super.key, required this.user, required this.isSelf});

  final UserProfileModel user;
  final bool isSelf;

  Future<void> _toggleActive(BuildContext context) async {
    if (user.isActive) {
      final bool ok = await ConfirmDialog.show(
        context,
        title: 'تعطيل ${user.displayName}؟',
        message: 'لن يتمكن هذا المستخدم من تسجيل الدخول أو الوصول للبيانات بعد التعطيل.',
        confirmLabel: 'تعطيل',
        isDestructive: true,
      );
      if (!ok) return;
    }
    if (!context.mounted) return;
    await context.read<AccountsCubit>().setActive(user.id, !user.isActive);
  }

  Future<void> _toggleRole(BuildContext context) async {
    final UserRole next = user.role == UserRole.admin ? UserRole.staff : UserRole.admin;
    final bool ok = await ConfirmDialog.show(
      context,
      title: next == UserRole.admin ? 'ترقية إلى مسؤول؟' : 'تنزيل إلى موظف؟',
      message: next == UserRole.admin
          ? 'سيتمكن ${user.displayName} من إدارة كل الحسابات.'
          : 'لن يتمكن ${user.displayName} بعد الآن من إدارة الحسابات.',
    );
    if (!ok || !context.mounted) return;
    await context.read<AccountsCubit>().setRole(user.id, next);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 18,
            backgroundColor: user.isActive
                ? AppColors.successSurface
                : AppColors.dangerSurface,
            child: Icon(
              Icons.person,
              color: user.isActive ? AppColors.success : AppColors.danger,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(user.displayName, style: AppTextStyles.body),
                    if (isSelf) ...<Widget>[
                      const SizedBox(width: 6),
                      Text('(أنت)', style: AppTextStyles.caption),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: AppTextStyles.caption,
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          ),
          if (!user.isActive)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warningSurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('بانتظار الموافقة', style: AppTextStyles.caption),
            ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                'آخر دخول: ${user.lastLoginAt == null ? '—' : AppDateUtils.formatDateTime(user.lastLoginAt!)}',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: isSelf ? null : () => _toggleRole(context),
            child: Text(user.role == UserRole.admin ? 'مسؤول' : 'موظف'),
          ),
          Switch(
            value: user.isActive,
            onChanged: isSelf ? null : (_) => _toggleActive(context),
            activeColor: AppColors.success,
          ),
        ],
      ),
    );
  }
}
