import 'package:freezed_annotation/freezed_annotation.dart';

part 'daily_point_model.freezed.dart';

/// One day on the dashboard revenue chart, net of refunds.
@freezed
class DailyPointModel with _$DailyPointModel {
  const DailyPointModel._();

  const factory DailyPointModel({
    required DateTime date,
    @Default(0) double revenue,
    @Default(0) double cost,
  }) = _DailyPointModel;

  double get profit => revenue - cost;
}
