import '../../../model/category_model.dart';
import '../../../model/client_model.dart';
import '../../../model/expense_model.dart';
import '../../../model/item_field_value_model.dart';
import '../../../model/item_model.dart';
import '../../../model/item_type_field_model.dart';
import '../../../model/item_type_model.dart';
import '../../../model/payment_model.dart';
import '../../../model/refund_item_model.dart';
import '../../../model/refund_model.dart';
import '../../../model/supplier_model.dart';
import '../../../model/transaction_item_model.dart';
import '../../../model/transaction_model.dart';
import 'app_database.dart';

/// Row -> model conversions shared by every DAO.
extension ClientRowMapper on ClientRow {
  ClientModel toModel() => ClientModel(
        id: id,
        name: name,
        phone: phone,
        notes: notes,
        isActive: isActive,
        createdAt: createdAt,
        passportId: passportId,
        nationalId: nationalId,
      );
}

extension SupplierRowMapper on SupplierRow {
  SupplierModel toModel() => SupplierModel(
        id: id,
        name: name,
        phone: phone,
        notes: notes,
        isActive: isActive,
        createdAt: createdAt,
        isSystemSupplier: isSystemSupplier,
      );
}

extension ItemTypeRowMapper on ItemTypeRow {
  ItemTypeModel toModel({List<ItemTypeFieldModel> fields = const <ItemTypeFieldModel>[]}) =>
      ItemTypeModel(id: id, name: name, createdAt: createdAt, fields: fields);
}

extension ItemTypeFieldRowMapper on ItemTypeFieldRow {
  ItemTypeFieldModel toModel() => ItemTypeFieldModel(
        id: id,
        itemTypeId: itemTypeId,
        fieldName: fieldName,
        fieldType: FieldType.fromName(fieldType),
        isRequired: isRequired,
        sortOrder: sortOrder,
      );
}

extension ItemFieldValueRowMapper on ItemFieldValueRow {
  ItemFieldValueModel toModel() => ItemFieldValueModel(
        id: id,
        itemId: itemId,
        fieldId: fieldId,
        value: value,
      );
}

extension ItemRowMapper on ItemRow {
  ItemModel toModel({
    List<ItemFieldValueModel> fieldValues = const <ItemFieldValueModel>[],
    String? itemTypeName,
    String? supplierName,
  }) =>
      ItemModel(
        id: id,
        itemTypeId: itemTypeId,
        supplierId: supplierId,
        label: label,
        defaultCost: defaultCost,
        defaultPrice: defaultPrice,
        expiryDate: expiryDate,
        isSingleUse: isSingleUse,
        isAvailable: isAvailable,
        notes: notes,
        isActive: isActive,
        createdAt: createdAt,
        fieldValues: fieldValues,
        itemTypeName: itemTypeName,
        supplierName: supplierName,
      );
}

extension TransactionRowMapper on TransactionRow {
  TransactionModel toModel({String? clientName, String? clientPhone}) => TransactionModel(
        id: id,
        clientId: clientId,
        dateTime: occurredAt,
        dealType: DealType.fromName(dealType),
        subtotal: subtotal,
        discount: discount,
        total: total,
        totalCost: totalCost,
        status: TransactionStatus.fromName(status),
        notes: notes,
        clientName: clientName,
        clientPhone: clientPhone,
        commissionName: commissionName,
        commissionAmount: commissionAmount,
        paymentStatusOverride: paymentStatusOverride == null
            ? null
            : PaymentStatus.fromName(paymentStatusOverride!),
      );
}

extension TransactionItemRowMapper on TransactionItemRow {
  TransactionItemModel toModel({
    String? itemLabel,
    String? supplierName,
    String? supplierPhone,
    bool isSingleUse = false,
    int refundedQty = 0,
  }) =>
      TransactionItemModel(
        id: id,
        transactionId: transactionId,
        itemId: itemId,
        supplierId: supplierId,
        dealType: DealType.fromName(dealType),
        qty: qty,
        unitCost: unitCost,
        unitPrice: unitPrice,
        lineTotal: lineTotal,
        rentStart: rentStart,
        rentEnd: rentEnd,
        expiryDate: expiryDate,
        notes: notes,
        itemLabel: itemLabel,
        supplierName: supplierName,
        supplierPhone: supplierPhone,
        isSingleUse: isSingleUse,
        refundedQty: refundedQty,
        pricePerDay: pricePerDay,
        costPerDay: costPerDay,
        days: days,
        allowedKmPerDay: allowedKmPerDay,
        extraKmRate: extraKmRate,
        pickupKilometer: pickupKilometer,
        returnKilometer: returnKilometer,
        extraKmCharge: extraKmCharge,
        lineStatus: LineStatus.fromName(lineStatus),
      );
}

extension PaymentRowMapper on PaymentRow {
  PaymentModel toModel({String? supplierName, String? clientName}) =>
      PaymentModel(
        id: id,
        transactionId: transactionId,
        party: PaymentParty.fromName(party),
        supplierId: supplierId,
        method: PaymentMethod.fromName(method),
        amount: amount,
        dateTime: occurredAt,
        notes: notes,
        supplierName: supplierName,
        clientName: clientName,
        transactionItemId: transactionItemId,
        rentalDayDate: rentalDayDate,
        voided: voided,
      );
}

extension RefundRowMapper on RefundRow {
  RefundModel toModel({List<RefundItemModel> items = const <RefundItemModel>[]}) =>
      RefundModel(
        id: id,
        transactionId: transactionId,
        dateTime: occurredAt,
        totalRefunded: totalRefunded,
        totalCostRefunded: totalCostRefunded,
        reason: reason,
        items: items,
      );
}

extension RefundItemRowMapper on RefundItemRow {
  RefundItemModel toModel({String? itemLabel}) => RefundItemModel(
        id: id,
        refundId: refundId,
        transactionItemId: transactionItemId,
        itemId: itemId,
        qty: qty,
        unitCost: unitCost,
        unitPrice: unitPrice,
        itemLabel: itemLabel,
      );
}

extension ExpenseCategoryRowMapper on ExpenseCategoryRow {
  CategoryModel toModel() => CategoryModel(id: id, name: name);
}

extension ExpenseRowMapper on ExpenseRow {
  ExpenseModel toModel({String? categoryName}) => ExpenseModel(
        id: id,
        title: title,
        amount: amount,
        categoryId: categoryId,
        transactionId: transactionId,
        dateTime: occurredAt,
        note: note,
        categoryName: categoryName,
      );
}
