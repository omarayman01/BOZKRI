import 'package:freezed_annotation/freezed_annotation.dart';

part 'expense_model.freezed.dart';

@freezed
class ExpenseModel with _$ExpenseModel {
  const factory ExpenseModel({
    required int id,
    required String title,
    required double amount,
    int? categoryId,
    int? transactionId,
    required DateTime dateTime,
    String? note,
    String? categoryName,
  }) = _ExpenseModel;
}
