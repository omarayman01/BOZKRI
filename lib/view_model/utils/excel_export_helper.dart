import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:path/path.dart' as p;

import '../../model/client_model.dart';
import '../../model/expense_model.dart';
import '../../model/item_field_value_model.dart';
import '../../model/item_model.dart';
import '../../model/item_type_field_model.dart';
import '../../model/item_type_model.dart';
import '../../model/payment_model.dart';
import '../../model/supplier_model.dart';
import '../../model/transaction_item_model.dart';
import '../../model/transaction_model.dart';
import '../../model/transaction_with_items_model.dart';
import '../../view/constants/app_constants.dart';
import '../errors/failure.dart';
import '../repos/clients_repo.dart';
import '../repos/expenses_repo.dart';
import '../repos/item_types_repo.dart';
import '../repos/items_repo.dart';
import '../repos/suppliers_repo.dart';
import '../repos/transactions_repo.dart';
import 'item_category.dart';

/// Builds the human-readable, multi-sheet End-of-Day Excel report.
///
/// This is export-only: the file is never read back in as a restore source.
/// Apartments / flights / cars item types get the agency's real workbook
/// columns; any other admin-defined item type falls back to a generic sheet
/// built from its dynamic fields. Plus fixed sheets for clients, suppliers,
/// payments, expenses, and one sheet per supplier.
class ExcelExportHelper {
  const ExcelExportHelper._();

  /// Shares its base name with `DbBackupHelper.backupFileName` (differing
  /// only in extension) so the `.sqlite` and `.xlsx` written by one Backup
  /// run are easy to pair up.
  static String suggestedFileName(DateTime at) =>
      'bozkri_${_stampDate(at)}.xlsx';

  static Future<String> exportEndOfDayWorkbook({
    required String destinationFolder,
    required DateTime at,
    required TransactionsRepo transactionsRepo,
    required ItemsRepo itemsRepo,
    required ItemTypesRepo itemTypesRepo,
    required ClientsRepo clientsRepo,
    required SuppliersRepo suppliersRepo,
    required ExpensesRepo expensesRepo,
  }) async {
    try {
      final List<TransactionWithItemsModel> deals =
          await transactionsRepo.getDeals();
      final List<ItemModel> items = await itemsRepo.getItems();
      final Map<int, ItemModel> itemById = <int, ItemModel>{
        for (final ItemModel item in items) item.id: item,
      };
      final List<ItemTypeModel> itemTypes = await itemTypesRepo.getTypes();
      final List<ClientModel> clients = await clientsRepo.getClients();
      final Map<int, ClientModel> clientById = <int, ClientModel>{
        for (final ClientModel c in clients) c.id: c,
      };
      final List<SupplierModel> suppliers = await suppliersRepo.getSuppliers();
      final List<ExpenseModel> expenses = await expensesRepo.getExpenses();

      final xls.Excel workbook = xls.Excel.createExcel();

      for (final ItemTypeModel itemType in itemTypes) {
        switch (categoryOf(itemType)) {
          case ItemCategory.apartment:
            _writeApartmentsSheet(workbook, itemType, deals, itemById, clientById);
          case ItemCategory.flight:
            _writeFlightsSheet(workbook, itemType, deals, itemById, clientById);
          case ItemCategory.car:
            _writeCarsSheet(workbook, itemType, deals, itemById, clientById);
          case ItemCategory.other:
            _writeItemTypeSheet(workbook, itemType, deals, itemById);
        }
      }
      _writeItemTypesSheet(workbook, itemTypes);
      _writeClientsSheet(workbook, clients);
      _writeSuppliersSheet(workbook, suppliers);
      _writeItemsSheet(workbook, items);
      for (final SupplierModel supplier in suppliers) {
        _writeSupplierDetailSheet(workbook, supplier, deals);
      }
      _writePaymentsSheet(workbook, deals);
      _writeExpensesSheet(workbook, expenses);

      // `Excel.createExcel()` always seeds a default "Sheet1"; drop it once
      // real sheets exist so the workbook only shows meaningful tabs.
      if (workbook.sheets.length > 1 &&
          workbook.sheets.containsKey('Sheet1')) {
        workbook.delete('Sheet1');
      }

      final List<int>? bytes = workbook.encode();
      if (bytes == null) {
        throw const FileFailure('Failed to encode the Excel workbook.');
      }

      final Directory folder = Directory(destinationFolder);
      if (!folder.existsSync()) {
        folder.createSync(recursive: true);
      }
      final String path = p.join(folder.path, suggestedFileName(at));
      await File(path).writeAsBytes(Uint8List.fromList(bytes), flush: true);
      return path;
    } on Failure {
      rethrow;
    } catch (error) {
      throw FileFailure('Excel export failed: $error', cause: error);
    }
  }

  // ---------------------------------------------------------------------
  // Apartments (ايجار الشقق)
  // ---------------------------------------------------------------------

  static void _writeApartmentsSheet(
    xls.Excel workbook,
    ItemTypeModel itemType,
    List<TransactionWithItemsModel> deals,
    Map<int, ItemModel> itemById,
    Map<int, ClientModel> clientById,
  ) {
    final xls.Sheet sheet = workbook[_safeSheetName(itemType.name)];
    _writeBrandHeader(sheet);
    _appendRow(sheet, <String>[
      'رقم الشقه',
      'اسم المستأجر',
      'رقم الموبايل',
      'اسم العقار',
      'المده',
      'تاريخ البدء',
      'تاريخ الانتهاء',
      'قيمة الايجار',
      'التامين',
      'المبلغ المدفوع',
      'طريقة الدفع',
      'المتبقي',
      'سعر المعرض',
      'سعر المكتب',
      'صافي الربح',
      'حالة الدفع',
      'حالة العقد',
      'ملاحظات',
    ]);

    for (final TransactionWithItemsModel deal in deals) {
      for (final TransactionItemModel line in deal.items) {
        final ItemModel? item = itemById[line.itemId];
        if (item == null || item.itemTypeId != itemType.id) continue;
        final Map<String, String> fv = fieldValuesByName(item, itemType);
        final ClientModel? client = clientById[deal.transaction.clientId];

        _appendRow(sheet, <Object?>[
          pickFieldValue(fv, <String>['رقم الشقه', 'رقم الشقة', 'وحدة', 'unit']),
          deal.transaction.clientName ?? '',
          client?.phone ?? '',
          pickFieldValue(fv, <String>['العقار', 'property']),
          _rentDaysLabel(line),
          _formatNullableDate(line.rentStart),
          _formatNullableDate(line.rentEnd),
          line.unitPrice,
          pickFieldValue(fv, <String>['التامين', 'تأمين', 'deposit', 'insurance']),
          deal.clientPaid,
          _lastPaymentMethodLabel(deal),
          deal.clientOutstanding,
          line.unitCost,
          line.unitPrice,
          line.lineProfit,
          _statusLabel(deal.displayedClientStatus.name),
          _contractStatusLabel(deal.transaction.status),
          line.notes ?? deal.transaction.notes ?? '',
        ]);
      }
    }
  }

  // ---------------------------------------------------------------------
  // Flights (تذاكر الطيران)
  // ---------------------------------------------------------------------

  static void _writeFlightsSheet(
    xls.Excel workbook,
    ItemTypeModel itemType,
    List<TransactionWithItemsModel> deals,
    Map<int, ItemModel> itemById,
    Map<int, ClientModel> clientById,
  ) {
    final xls.Sheet sheet = workbook[_safeSheetName(itemType.name)];
    _writeBrandHeader(sheet);
    _appendRow(sheet, <String>[
      'رقم الرحلة',
      'اسم المسافر',
      'رقم الموبايل',
      'تاريخ الرحلة',
      'من',
      'الي',
      'سعر التذاكر من شركة الطيران',
      'سعر التذاكر للعميل',
      'صافي الربح',
      'المبلغ المدفوع',
      'طريقة الدفع',
      'المتبقي',
      'حالة الدفع',
      'حالة الرحلة',
      'ملاحظات',
    ]);

    for (final TransactionWithItemsModel deal in deals) {
      for (final TransactionItemModel line in deal.items) {
        final ItemModel? item = itemById[line.itemId];
        if (item == null || item.itemTypeId != itemType.id) continue;
        final Map<String, String> fv = fieldValuesByName(item, itemType);
        final ClientModel? client = clientById[deal.transaction.clientId];

        _appendRow(sheet, <Object?>[
          pickFieldValue(fv, <String>['رقم الرحلة', 'flight']),
          deal.transaction.clientName ?? '',
          client?.phone ?? '',
          _formatNullableDate(line.rentStart ?? deal.transaction.dateTime),
          pickFieldValue(fv, <String>['من', 'from']),
          pickFieldValue(fv, <String>['الي', 'إلى', 'to']),
          line.unitCost,
          line.unitPrice,
          line.lineProfit,
          deal.clientPaid,
          _lastPaymentMethodLabel(deal),
          deal.clientOutstanding,
          _statusLabel(deal.displayedClientStatus.name),
          _contractStatusLabel(deal.transaction.status),
          line.notes ?? deal.transaction.notes ?? '',
        ]);
      }
    }
  }

  // ---------------------------------------------------------------------
  // Cars (ايجار السيارات)
  // ---------------------------------------------------------------------

  static void _writeCarsSheet(
    xls.Excel workbook,
    ItemTypeModel itemType,
    List<TransactionWithItemsModel> deals,
    Map<int, ItemModel> itemById,
    Map<int, ClientModel> clientById,
  ) {
    final xls.Sheet sheet = workbook[_safeSheetName(itemType.name)];
    _writeBrandHeader(sheet);
    _appendRow(sheet, <String>[
      'م',
      'التاريخ',
      'اسم العميل',
      'رقم الموبايل',
      'ماركة/موديل',
      'مواصفات',
      'رقم اللوحة',
      'تاريخ البدء',
      'الوقت',
      'الكيلومتر',
      'تاريخ الانتهاء',
      'المده باليوم',
      'السعر اليوم',
      'الاجمالي',
      'المبلغ المدفوع',
      'المتبقي',
      'سعر المعرض',
      'سعر المكتب',
      'صافي الربح باليوم',
      'اجمالي صافي الربح',
      'حالة الدفع',
      'العمولة',
      'حالة العقد',
      'ملاحظات',
    ]);

    int index = 0;
    for (final TransactionWithItemsModel deal in deals) {
      for (final TransactionItemModel line in deal.items) {
        final ItemModel? item = itemById[line.itemId];
        if (item == null || item.itemTypeId != itemType.id) continue;
        index++;
        final Map<String, String> fv = fieldValuesByName(item, itemType);
        final ClientModel? client = clientById[deal.transaction.clientId];

        final double paidOnLine = deal.payments
            .where((PaymentModel p) =>
                p.transactionItemId == line.id && !p.voided)
            .fold<double>(0, (double sum, PaymentModel p) => sum + p.amount);
        final double lineReceivable = deal.lineReceivableFor(line);
        final double profitPerDay =
            (line.pricePerDay ?? 0) - (line.costPerDay ?? 0);
        final double totalProfit = line.lineProfit + (line.extraKmCharge ?? 0);

        _appendRow(sheet, <Object?>[
          index,
          _formatNullableDate(deal.transaction.dateTime),
          deal.transaction.clientName ?? '',
          client?.phone ?? '',
          pickFieldValue(fv, <String>['ماركة', 'موديل', 'brand', 'model']),
          pickFieldValue(fv, <String>['مواصفات', 'specs']),
          pickFieldValue(fv, <String>['رقم اللوحة', 'لوحة', 'plate']),
          _formatNullableDate(line.rentStart),
          line.rentStart == null ? '' : _formatTime(line.rentStart!),
          line.pickupKilometer ?? '',
          _formatNullableDate(line.rentEnd),
          line.days ?? '',
          line.pricePerDay ?? '',
          line.finalLineTotal,
          paidOnLine,
          lineReceivable,
          line.costPerDay ?? '',
          line.pricePerDay ?? '',
          profitPerDay,
          totalProfit,
          _statusLabel(_lineStatusName(line.finalLineTotal, paidOnLine)),
          deal.transaction.commissionAmount ?? '',
          line.isReturned ? 'مغلق' : 'ساري',
          line.notes ?? '',
        ]);
      }
    }
  }

  static String _lineStatusName(double owed, double paid) {
    if (owed <= 0.005) return 'paid';
    if (paid <= 0.005) return 'unpaid';
    if (paid >= owed - 0.005) return 'paid';
    return 'partial';
  }

  // ---------------------------------------------------------------------
  // Generic fallback for any other admin-defined item type
  // ---------------------------------------------------------------------

  static void _writeItemTypeSheet(
    xls.Excel workbook,
    ItemTypeModel itemType,
    List<TransactionWithItemsModel> deals,
    Map<int, ItemModel> itemById,
  ) {
    final List<ItemTypeFieldModel> fields = List<ItemTypeFieldModel>.from(
      itemType.fields,
    )..sort((ItemTypeFieldModel a, ItemTypeFieldModel b) =>
        a.sortOrder.compareTo(b.sortOrder));

    final xls.Sheet sheet = workbook[_safeSheetName(itemType.name)];
    _writeBrandHeader(sheet);
    _appendRow(sheet, <String>[
      'رقم العملية',
      'التاريخ',
      'العميل',
      'الصنف',
      'المورد',
      ...fields.map((ItemTypeFieldModel f) => f.fieldName),
      'الكمية',
      'سعر المعرض',
      'سعر المكتب',
      'الاجمالي',
      'صافي الربح',
      'حالة الدفع',
      'ملاحظات',
    ]);

    for (final TransactionWithItemsModel deal in deals) {
      for (final TransactionItemModel line in deal.items) {
        final ItemModel? item = itemById[line.itemId];
        if (item == null || item.itemTypeId != itemType.id) continue;

        final Map<int, String> valueByFieldId = <int, String>{
          for (final ItemFieldValueModel v in item.fieldValues)
            v.fieldId: v.value,
        };

        _appendRow(sheet, <Object?>[
          deal.id,
          _formatNullableDate(deal.transaction.dateTime),
          deal.transaction.clientName ?? '',
          item.label,
          line.supplierName ?? '',
          ...fields.map((ItemTypeFieldModel f) => valueByFieldId[f.id] ?? ''),
          line.qty,
          line.unitCost,
          line.unitPrice,
          line.lineTotal,
          line.lineProfit,
          _statusLabel(deal.displayedClientStatus.name),
          line.notes ?? deal.transaction.notes ?? '',
        ]);
      }
    }
  }

  static void _writeClientsSheet(xls.Excel workbook, List<ClientModel> clients) {
    final xls.Sheet sheet = workbook['Clients'];
    _writeBrandHeader(sheet);
    _appendRow(sheet, <String>[
      'الاسم',
      'الموبايل',
      'ملاحظات',
      'نشط',
      'تاريخ الاضافة',
    ]);
    for (final ClientModel client in clients) {
      _appendRow(sheet, <Object?>[
        client.name,
        client.phone ?? '',
        client.notes ?? '',
        client.isActive ? 'نعم' : 'لا',
        _formatNullableDate(client.createdAt),
      ]);
    }
  }

  /// One row per (item type, field) pair — the master-data counterpart
  /// `excel_import_helper.dart` reads back on an `.xlsx` restore (Phase 20)
  /// to recreate item types and their dynamic field schemas before the
  /// Items sheet's rows are placed against them. An item type with no
  /// fields still gets exactly one row (اسم الحقل blank) so it is never
  /// silently dropped from the sheet.
  static void _writeItemTypesSheet(
    xls.Excel workbook,
    List<ItemTypeModel> itemTypes,
  ) {
    final xls.Sheet sheet = workbook['ItemTypes'];
    _writeBrandHeader(sheet);
    _appendRow(sheet, <String>[
      'النوع',
      'اسم الحقل',
      'نوع الحقل',
      'إلزامي',
      'الترتيب',
    ]);
    for (final ItemTypeModel type in itemTypes) {
      if (type.fields.isEmpty) {
        _appendRow(sheet, <Object?>[type.name, '', '', '', '']);
        continue;
      }
      for (final ItemTypeFieldModel field in type.fields) {
        _appendRow(sheet, <Object?>[
          type.name,
          field.fieldName,
          field.fieldType.name,
          field.isRequired ? 'نعم' : 'لا',
          field.sortOrder,
        ]);
      }
    }
  }

  /// A flat sheet of every item/car in the system — the master-data
  /// counterpart `excel_import_helper.dart` reads back on an `.xlsx`
  /// restore (Phase 11). Column order matches what that importer expects.
  static void _writeItemsSheet(xls.Excel workbook, List<ItemModel> items) {
    final xls.Sheet sheet = workbook['Items'];
    _writeBrandHeader(sheet);
    _appendRow(sheet, <String>[
      'التسمية',
      'النوع',
      'المورد',
      'التكلفة الافتراضية',
      'السعر الافتراضي',
      'ملاحظات',
      'نشط',
    ]);
    for (final ItemModel item in items) {
      _appendRow(sheet, <Object?>[
        item.label,
        item.itemTypeName ?? '',
        item.supplierName ?? '',
        item.defaultCost,
        item.defaultPrice,
        item.notes ?? '',
        item.isActive ? 'نعم' : 'لا',
      ]);
    }
  }

  static void _writeSuppliersSheet(
      xls.Excel workbook, List<SupplierModel> suppliers) {
    final xls.Sheet sheet = workbook['Suppliers'];
    _writeBrandHeader(sheet);
    _appendRow(sheet, <String>[
      'الاسم',
      'الموبايل',
      'ملاحظات',
      'نشط',
      'تاريخ الاضافة',
    ]);
    for (final SupplierModel supplier in suppliers) {
      _appendRow(sheet, <Object?>[
        supplier.name,
        supplier.phone ?? '',
        supplier.notes ?? '',
        supplier.isActive ? 'نعم' : 'لا',
        _formatNullableDate(supplier.createdAt),
      ]);
    }
  }

  /// One tab per supplier, mirroring the agency's suppliers workbook: every
  /// line sourced from that supplier, across every deal.
  static void _writeSupplierDetailSheet(
    xls.Excel workbook,
    SupplierModel supplier,
    List<TransactionWithItemsModel> deals,
  ) {
    final xls.Sheet sheet = workbook[_safeSheetName(supplier.name)];
    _writeBrandHeader(sheet);
    _appendRow(sheet, <String>[
      'الصنف',
      'المسار',
      'المده',
      'من تاريخ',
      'الي تاريخ',
      'الكيلومترات',
      'القيمة',
      'ملاحظات',
      'حالة الدفع',
    ]);

    for (final TransactionWithItemsModel deal in deals) {
      for (final TransactionItemModel line in deal.items) {
        if (line.supplierId != supplier.id) continue;

        final String km = (line.pickupKilometer != null || line.returnKilometer != null)
            ? '${line.pickupKilometer ?? ''} → ${line.returnKilometer ?? ''}'
            : '';

        _appendRow(sheet, <Object?>[
          line.itemLabel ?? '',
          '',
          _rentDaysLabel(line),
          _formatNullableDate(line.rentStart),
          _formatNullableDate(line.rentEnd),
          km,
          line.lineCost,
          line.notes ?? '',
          _statusLabel(deal.supplierStatusFor(supplier.id).name),
        ]);
      }
    }
  }

  static void _writePaymentsSheet(
    xls.Excel workbook,
    List<TransactionWithItemsModel> deals,
  ) {
    final xls.Sheet sheet = workbook['Payments'];
    _writeBrandHeader(sheet);
    _appendRow(sheet, <String>[
      'رقم العملية',
      'الطرف',
      'المورد',
      'طريقة الدفع',
      'المبلغ',
      'التاريخ',
      'ملاحظات',
      'الحالة',
    ]);
    for (final TransactionWithItemsModel deal in deals) {
      for (final PaymentModel payment in deal.payments) {
        _appendRow(sheet, <Object?>[
          deal.id,
          payment.party == PaymentParty.client ? 'عميل' : 'مورد',
          payment.supplierName ?? '',
          _methodLabel(payment.method),
          payment.amount,
          _formatNullableDate(payment.dateTime),
          payment.notes ?? '',
          payment.voided ? 'ملغاة' : 'سارية',
        ]);
      }
    }
  }

  static void _writeExpensesSheet(
      xls.Excel workbook, List<ExpenseModel> expenses) {
    final xls.Sheet sheet = workbook['Expenses'];
    _writeBrandHeader(sheet);
    _appendRow(sheet, <String>[
      'البيان',
      'المبلغ',
      'الفئة',
      'التاريخ',
      'ملاحظات',
    ]);
    for (final ExpenseModel expense in expenses) {
      _appendRow(sheet, <Object?>[
        expense.title,
        expense.amount,
        expense.categoryName ?? '',
        _formatNullableDate(expense.dateTime),
        expense.note ?? '',
      ]);
    }
  }

  /// A plain text brand banner row — the `excel` package cannot embed images,
  /// so the logo itself only appears in-app (side-nav) and on the app icon.
  static void _writeBrandHeader(xls.Sheet sheet) {
    _appendRow(sheet, <String>[AppConstants.appNameAr]);
    _appendRow(sheet, <String>[]);
  }

  static void _appendRow(xls.Sheet sheet, List<Object?> values) {
    sheet.appendRow(values.map(_toCellValue).toList());
  }

  static xls.CellValue? _toCellValue(Object? value) {
    if (value == null) return null;
    if (value is int) return xls.IntCellValue(value);
    if (value is double) return xls.DoubleCellValue(value);
    if (value is bool) return xls.BoolCellValue(value);
    return xls.TextCellValue(value.toString());
  }

  static String _safeSheetName(String name) {
    // Excel sheet names cannot contain: \ / ? * [ ] : and are capped at 31 chars.
    final String cleaned =
        name.replaceAll(RegExp(r'[\\/?*\[\]:]'), ' ').trim();
    return cleaned.isEmpty
        ? 'Sheet'
        : (cleaned.length > 31 ? cleaned.substring(0, 31) : cleaned);
  }

  static String _formatNullableDate(DateTime? date) {
    if (date == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  static String _formatTime(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.hour)}:${two(date.minute)}';
  }

  /// Inclusive rental day count: the line's billed `days` if set, else
  /// computed from the rent date range, else blank.
  static Object _rentDaysLabel(TransactionItemModel line) {
    if (line.days != null) return line.days!;
    final DateTime? start = line.rentStart;
    final DateTime? end = line.rentEnd;
    if (start == null || end == null || end.isBefore(start)) return '';
    return end.difference(start).inDays + 1;
  }

  static String _lastPaymentMethodLabel(TransactionWithItemsModel deal) {
    final List<PaymentModel> clientPayments = deal.payments
        .where((PaymentModel p) => p.party == PaymentParty.client && !p.voided)
        .toList()
      ..sort((PaymentModel a, PaymentModel b) => b.dateTime.compareTo(a.dateTime));
    if (clientPayments.isEmpty) return '';
    return _methodLabel(clientPayments.first.method);
  }

  static String _methodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'كاش';
      case PaymentMethod.mobileWallet:
        return 'محفظة';
      case PaymentMethod.instapay:
        return 'انستاباي';
    }
  }

  static String _contractStatusLabel(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.active:
        return 'ساري';
      case TransactionStatus.partiallyRefunded:
      case TransactionStatus.fullyRefunded:
        return 'غير ساري';
    }
  }

  static String _statusLabel(String statusName) {
    switch (statusName) {
      case 'paid':
        return 'مدفوع';
      case 'partial':
        return 'مدفوع جزئياً';
      default:
        return 'غير مدفوع';
    }
  }

  static String _stampDate(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${at.year}-${two(at.month)}-${two(at.day)}_'
        '${two(at.hour)}${two(at.minute)}';
  }
}
