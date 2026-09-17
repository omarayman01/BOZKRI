import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../model/daily_point_model.dart';
import '../../../../view_model/utils/currency_formatter.dart';
import '../../../../view_model/utils/date_utils.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_constants.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/widgets/empty_state_widget.dart';

/// Daily net revenue and cost. Axis labels are forced LTR so figures read the
/// same way in the Arabic UI.
class RevenueChart extends StatelessWidget {
  const RevenueChart({super.key, required this.points});

  final List<DailyPointModel> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(
        height: 260,
        child: EmptyStateWidget(
          title: 'لا توجد إيرادات في هذه الفترة',
          message: 'Deals committed inside the selected range appear here.',
          icon: Icons.show_chart,
        ),
      );
    }

    final double maxY = points
        .map((DailyPointModel p) => p.revenue > p.cost ? p.revenue : p.cost)
        .fold<double>(0, (double a, double b) => a > b ? a : b);

    return Container(
      height: 300,
      padding: const EdgeInsets.fromLTRB(12, 24, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY <= 0 ? 1 : maxY * 1.15,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (double _) =>
                  const FlLine(color: AppColors.divider, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 64,
                  getTitlesWidget: (double value, TitleMeta meta) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      CurrencyFormatter.compact(value),
                      style: AppTextStyles.caption,
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: (points.length / 6).ceilToDouble().clamp(1, 999),
                  getTitlesWidget: (double value, TitleMeta meta) {
                    final int index = value.round();
                    if (index < 0 || index >= points.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        AppDateUtils.formatShort(points[index].date),
                        style: AppTextStyles.caption,
                        textDirection: TextDirection.ltr,
                      ),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (List<LineBarSpot> spots) =>
                    spots.map((LineBarSpot spot) {
                  return LineTooltipItem(
                    CurrencyFormatter.format(spot.y),
                    AppTextStyles.caption.copyWith(color: AppColors.white),
                  );
                }).toList(),
              ),
            ),
            lineBarsData: <LineChartBarData>[
              _bar(
                points
                    .asMap()
                    .entries
                    .map((MapEntry<int, DailyPointModel> e) =>
                        FlSpot(e.key.toDouble(), e.value.revenue))
                    .toList(),
                AppColors.primary,
                fill: true,
              ),
              _bar(
                points
                    .asMap()
                    .entries
                    .map((MapEntry<int, DailyPointModel> e) =>
                        FlSpot(e.key.toDouble(), e.value.cost))
                    .toList(),
                AppColors.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  LineChartBarData _bar(List<FlSpot> spots, Color color,
          {bool fill = false}) =>
      LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.25,
        color: color,
        barWidth: 2.4,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: fill,
          color: color.withValues(alpha: 0.10),
        ),
      );
}
