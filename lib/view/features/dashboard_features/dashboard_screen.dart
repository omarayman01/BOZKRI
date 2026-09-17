import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/daily_point_model.dart';
import '../../../model/expense_model.dart';
import '../../../model/top_party_model.dart';
import '../../../view_model/cubit/dashboard/dashboard_cubit.dart';
import '../../../view_model/cubit/dashboard/dashboard_state.dart';
import '../../../view_model/utils/date_utils.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_text_styles.dart';
import '../../core/widgets/date_range_picker_field.dart';
import '../../core/widgets/error_state_widget.dart';
import '../../core/widgets/loading_widget.dart';
import 'widgets/expenses_breakdown_card.dart';
import 'widgets/expiry_panel.dart';
import 'widgets/kpi_row.dart';
import 'widgets/revenue_chart.dart';
import 'widgets/top_clients_list.dart';
import 'widgets/top_suppliers_list.dart';

/// Date-range analytics plus the expenses section. Every figure is aggregated
/// in SQL from the stored snapshots, net of refunds.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load([AppDateRange? range]) async {
    final AppDateRange effective = range ?? AppDateUtils.currentMonth();
    await context.read<DashboardCubit>().load(range: effective);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (BuildContext context, DashboardState state) {
        if (state.isLoading && state.summary == null) {
          return LoadingWidget(message: l10n.loading);
        }

        if (state.isFailure) {
          return ErrorStateWidget(
            message: state.errorMessage ?? l10n.errorGeneric,
            onRetry: _load,
          );
        }

        final AppDateRange range = state.range ?? AppDateUtils.currentMonth();

        return SingleChildScrollView(
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
                      onChanged: _load,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (state.summary != null) KpiRow(summary: state.summary!),
              const SizedBox(height: 24),
              Text(l10n.revenueChart, style: AppTextStyles.title),
              const SizedBox(height: 12),
              RevenueChart(
                points: state.summary?.daily ?? const <DailyPointModel>[],
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool wide = constraints.maxWidth > 900;
                  final double width =
                      wide ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth;

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: <Widget>[
                      SizedBox(
                        width: width,
                        child: TopClientsList(
                          clients:
                              state.summary?.topClients ?? const <TopPartyModel>[],
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: TopSuppliersList(
                          suppliers: state.summary?.topSuppliers ??
                              const <TopPartyModel>[],
                        ),
                      ),
                      SizedBox(width: width, child: const ExpiryPanel()),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              ExpensesBreakdownCard(
                expenses: state.summary?.expenses ?? const <ExpenseModel>[],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
