import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../model/dashboard_summary_model.dart';
import '../../../../view_model/utils/currency_formatter.dart';
import '../../../constants/app_colors.dart';
import '../../../core/widgets/kpi_card.dart';

/// The dashboard headline figures, all net of refunds.
class KpiRow extends StatelessWidget {
  const KpiRow({super.key, required this.summary});

  final DashboardSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    final List<_Kpi> kpis = <_Kpi>[
      _Kpi(l10n.netRevenue, summary.netRevenue, Icons.trending_up, null),
      _Kpi(l10n.netCost, summary.netCost, Icons.trending_down, null),
      _Kpi(
        l10n.grossProfit,
        summary.grossProfit,
        Icons.savings_outlined,
        summary.grossProfit >= 0 ? AppColors.success : AppColors.danger,
      ),
      _Kpi(l10n.totalExpenses, summary.totalExpenses,
          Icons.receipt_outlined, AppColors.warning),
      _Kpi(
        l10n.netProfit,
        summary.netProfit,
        Icons.account_balance_outlined,
        summary.netProfit >= 0 ? AppColors.success : AppColors.danger,
      ),
      _Kpi(l10n.outstandingReceivables, summary.outstandingReceivables,
          Icons.call_received, AppColors.primary),
      _Kpi(l10n.outstandingPayables, summary.outstandingPayables,
          Icons.call_made, AppColors.danger),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const int columns = 4;
        final double width =
            (constraints.maxWidth - (columns - 1) * 16) / columns;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: <Widget>[
            for (final _Kpi kpi in kpis)
              SizedBox(
                width: width < 200 ? constraints.maxWidth : width,
                child: KpiCard(
                  label: kpi.label,
                  value: CurrencyFormatter.format(kpi.value),
                  icon: kpi.icon,
                  valueColor: kpi.color,
                  accent: kpi.color,
                ),
              ),
            SizedBox(
              width: width < 200 ? constraints.maxWidth : width,
              child: KpiCard(
                label: l10n.dealsCount,
                value: CurrencyFormatter.number(summary.dealCount),
                icon: Icons.receipt_long_outlined,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Kpi {
  const _Kpi(this.label, this.value, this.icon, this.color);

  final String label;
  final double value;
  final IconData icon;
  final Color? color;
}
