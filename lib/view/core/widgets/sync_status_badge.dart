import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../view_model/cubit/sync/sync_cubit.dart';
import '../../../view_model/cubit/sync/sync_state.dart';
import '../../../view_model/utils/date_utils.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';

/// Shows whether local data is synced to the shared Supabase project, and
/// lets the admin trigger a sync manually (Phase 21).
class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncCubit, SyncCubitState>(
      builder: (BuildContext context, SyncCubitState state) {
        final (Color color, IconData icon, String label) = switch (state.status) {
          SyncStatus.offline => (
              AppColors.warning,
              Icons.cloud_off_outlined,
              'غير متصل بالإنترنت — التغييرات محفوظة محلياً',
            ),
          SyncStatus.syncing => (
              AppColors.secondary,
              Icons.sync,
              'جارِ المزامنة…',
            ),
          SyncStatus.error => (
              AppColors.danger,
              Icons.sync_problem_outlined,
              'خطأ في المزامنة',
            ),
          SyncStatus.synced => (
              AppColors.success,
              Icons.cloud_done_outlined,
              state.lastSyncedAt == null
                  ? 'متصل'
                  : 'آخر مزامنة: ${AppDateUtils.formatDateTime(state.lastSyncedAt!)}',
            ),
        };

        return Tooltip(
          message: state.errorMessage ?? label,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => context.read<SyncCubit>().syncNow(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 15, color: color),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Text(
                      label,
                      style: AppTextStyles.caption.copyWith(color: color),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
