import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/expense_model.dart';
import '../../../view_model/cubit/dashboard/dashboard_cubit.dart';
import '../../../view_model/cubit/expenses/expenses_cubit.dart';
import '../../../view_model/cubit/expenses/expenses_state.dart';
import '../../../view_model/utils/currency_formatter.dart';
import '../../../view_model/utils/date_utils.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../core/widgets/app_data_table.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/date_range_picker_field.dart';
import '../../core/widgets/error_state_widget.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/primary_button.dart';
import 'add_edit_expense_screen.dart';
import 'widgets/expense_row.dart';
import 'widgets/supplier_payments_section.dart';

/// Dense list of every expense in the selected range, with full admin
/// create/edit/delete — the same list-screen shape Deals/Clients establish.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<ExpensesCubit>().load(range: AppDateUtils.currentMonth()));
  }

  Future<void> _openForm(BuildContext context, [ExpenseModel? expense]) async {
    final ExpensesCubit cubit = context.read<ExpensesCubit>();
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext _) => BlocProvider<ExpensesCubit>.value(
        value: cubit,
        child: AddEditExpenseDialog(expense: expense),
      ),
    );
    if (saved == true && context.mounted) {
      await context.read<DashboardCubit>().refresh();
    }
  }

  Future<void> _delete(BuildContext context, ExpenseModel expense) async {
    final bool ok = await ConfirmDialog.show(
      context,
      title: 'حذف هذا المصروف؟',
      message: 'سيتم حذف "${expense.title}" نهائياً.',
      confirmLabel: 'حذف',
      isDestructive: true,
    );
    if (!ok || !context.mounted) return;

    await context.read<ExpensesCubit>().deleteExpense(expense.id);
    if (context.mounted) await context.read<DashboardCubit>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return BlocBuilder<ExpensesCubit, ExpensesState>(
      builder: (BuildContext context, ExpensesState state) {
        final AppDateRange range = state.range ?? AppDateUtils.currentMonth();

        return Padding(
          padding: const EdgeInsets.all(AppConstants.contentPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(l10n.period, style: AppTextStyles.label),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DateRangePickerField(
                      range: range,
                      onChanged: (AppDateRange r) =>
                          context.read<ExpensesCubit>().setRange(r),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    CurrencyFormatter.format(state.total),
                    style:
                        AppTextStyles.money.copyWith(color: AppColors.warning),
                    textDirection: TextDirection.ltr,
                  ),
                  const SizedBox(width: 16),
                  PrimaryButton(
                    label: l10n.newExpense,
                    icon: Icons.add,
                    onPressed: () => _openForm(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (state.isLoading)
                const Expanded(child: LoadingWidget())
              else if (state.isFailure)
                Expanded(
                  child: ErrorStateWidget(
                    message: state.errorMessage ?? l10n.errorGeneric,
                    onRetry: () => context.read<ExpensesCubit>().load(),
                  ),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SizedBox(
                          height: 380,
                          child: AppDataTable(
                            emptyTitle: l10n.expensesEmptyTitle,
                            emptyMessage: l10n.expensesEmptyMessage,
                            emptyIcon: Icons.receipt_outlined,
                            emptyActionLabel: l10n.newExpense,
                            onEmptyAction: () => _openForm(context),
                            columns: const <DataColumn>[
                              DataColumn(label: Text('التاريخ')),
                              DataColumn(label: Text('البيان')),
                              DataColumn(label: Text('الفئة')),
                              DataColumn(label: Text('المبلغ')),
                              DataColumn(label: Text('ملاحظات')),
                              DataColumn(label: Text('')),
                            ],
                            rows: state.expenses
                                .map((ExpenseModel e) => ExpenseRow.build(
                                      e,
                                      onEdit: () => _openForm(context, e),
                                      onDelete: () => _delete(context, e),
                                    ))
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _CashOutSummaryCard(state: state),
                        const SizedBox(height: 24),
                        SupplierPaymentsSection(
                            payments: state.supplierPayments),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A cash-flow total (expenses + supplier payments), visually and textually
/// distinct from any net-profit figure elsewhere in the app.
class _CashOutSummaryCard extends StatelessWidget {
  const _CashOutSummaryCard({required this.state});

  final ExpensesState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l10n.totalCashOut, style: AppTextStyles.label),
                Text(l10n.cashFlowCaption, style: AppTextStyles.caption),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.format(state.totalCashOut),
            style: AppTextStyles.money.copyWith(color: AppColors.textPrimary),
            textDirection: TextDirection.ltr,
          ),
        ],
      ),
    );
  }
}
