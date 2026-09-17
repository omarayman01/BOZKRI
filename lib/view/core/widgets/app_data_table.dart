import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import 'empty_state_widget.dart';

/// Dense, scrollable table wrapper used by every list screen. Handles the
/// empty case itself so callers never render a bare header row.
class AppDataTable extends StatelessWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.minWidth = 720,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final String emptyTitle;
  final String? emptyMessage;
  final IconData emptyIcon;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final int? sortColumnIndex;
  final bool sortAscending;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return EmptyStateWidget(
        title: emptyTitle,
        message: emptyMessage,
        icon: emptyIcon,
        actionLabel: emptyActionLabel,
        onAction: onEmptyAction,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: minWidth),
              child: DataTable(
                columns: columns,
                rows: rows,
                sortColumnIndex: sortColumnIndex,
                sortAscending: sortAscending,
                showCheckboxColumn: false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
