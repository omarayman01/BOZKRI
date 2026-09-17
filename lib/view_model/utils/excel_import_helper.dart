import 'dart:io';

import 'package:excel/excel.dart' as xls;

import '../../model/client_model.dart';
import '../../model/item_model.dart';
import '../../model/item_type_field_model.dart';
import '../../model/item_type_model.dart';
import '../../model/supplier_model.dart';
import '../errors/failure.dart';
import '../repos/clients_repo.dart';
import '../repos/item_types_repo.dart';
import '../repos/items_repo.dart';
import '../repos/suppliers_repo.dart';

/// Created/updated counts per table, for the restore success message.
class MasterDataImportSummary {
  const MasterDataImportSummary({
    this.clientsCreated = 0,
    this.clientsUpdated = 0,
    this.suppliersCreated = 0,
    this.suppliersUpdated = 0,
    this.itemsCreated = 0,
    this.itemsUpdated = 0,
    this.itemTypesCreated = 0,
    this.fieldsCreated = 0,
  });

  final int clientsCreated;
  final int clientsUpdated;
  final int suppliersCreated;
  final int suppliersUpdated;
  final int itemsCreated;
  final int itemsUpdated;
  final int itemTypesCreated;
  final int fieldsCreated;

  int get totalCreated =>
      clientsCreated + suppliersCreated + itemsCreated + itemTypesCreated + fieldsCreated;
  int get totalUpdated => clientsUpdated + suppliersUpdated + itemsUpdated;
}

/// Limited master-data-only import from a `.xlsx` file: upserts item types
/// (and their dynamic field schemas), clients, suppliers, and items/cars by
/// their natural key. Never touches transactions, transaction_items,
/// payments, refunds, or expenses — an Excel file cannot carry the
/// relational + snapshot integrity those tables require, so deals,
/// payments, and balances are left exactly as they were before the import.
class ExcelImportHelper {
  const ExcelImportHelper._();

  static Future<MasterDataImportSummary> importMasterData({
    required String sourcePath,
    required ClientsRepo clientsRepo,
    required SuppliersRepo suppliersRepo,
    required ItemsRepo itemsRepo,
    required ItemTypesRepo itemTypesRepo,
  }) async {
    try {
      final File file = File(sourcePath);
      if (!file.existsSync()) {
        throw const FileFailure('الملف المختار غير موجود.');
      }
      final xls.Excel workbook = xls.Excel.decodeBytes(file.readAsBytesSync());

      int clientsCreated = 0;
      int clientsUpdated = 0;
      int suppliersCreated = 0;
      int suppliersUpdated = 0;
      int itemsCreated = 0;
      int itemsUpdated = 0;
      int itemTypesCreated = 0;
      int fieldsCreated = 0;

      if (workbook.tables.containsKey('ItemTypes')) {
        final Map<String, int> typeIdByName = <String, int>{
          for (final ItemTypeModel t in await itemTypesRepo.getTypes())
            t.name: t.id,
        };
        final Map<int, List<ItemTypeFieldModel>> fieldsByType = <int, List<ItemTypeFieldModel>>{};

        for (final List<String> row in _dataRows(
          workbook.tables['ItemTypes']!,
          headerMarker: 'النوع',
        )) {
          final String typeName = row.isNotEmpty ? row[0] : '';
          if (typeName.isEmpty) continue;

          int typeId;
          if (typeIdByName.containsKey(typeName)) {
            typeId = typeIdByName[typeName]!;
          } else {
            typeId = await itemTypesRepo.addType(typeName);
            typeIdByName[typeName] = typeId;
            itemTypesCreated++;
          }

          final String fieldName = row.length > 1 ? row[1] : '';
          if (fieldName.isEmpty) continue; // a type-only row (no fields)

          final FieldType fieldType =
              FieldType.fromName(row.length > 2 ? row[2] : '');
          final bool isRequired = row.length > 3 ? row[3] == 'نعم' : false;
          final int sortOrder =
              row.length > 4 ? int.tryParse(row[4]) ?? 0 : 0;

          final List<ItemTypeFieldModel> existingFields =
              fieldsByType[typeId] ??= await itemTypesRepo.getFields(typeId);
          final ItemTypeFieldModel? match =
              existingFields.firstWhereOrNullByFieldName(fieldName);

          if (match == null) {
            await itemTypesRepo.addField(
              itemTypeId: typeId,
              fieldName: fieldName,
              fieldType: fieldType,
              isRequired: isRequired,
              sortOrder: sortOrder,
            );
            fieldsCreated++;
            fieldsByType[typeId] = await itemTypesRepo.getFields(typeId);
          } else if (match.fieldType != fieldType ||
              match.isRequired != isRequired ||
              match.sortOrder != sortOrder) {
            await itemTypesRepo.updateField(match.copyWith(
              fieldType: fieldType,
              isRequired: isRequired,
              sortOrder: sortOrder,
            ));
            fieldsByType[typeId] = await itemTypesRepo.getFields(typeId);
          }
        }
      }

      if (workbook.tables.containsKey('Clients')) {
        final List<ClientModel> existing = await clientsRepo.getClients();
        for (final List<String> row
            in _dataRows(workbook.tables['Clients']!, headerMarker: 'الاسم')) {
          final String name = row.isNotEmpty ? row[0] : '';
          if (name.isEmpty) continue;
          final String phone = row.length > 1 ? row[1] : '';
          final String notes = row.length > 2 ? row[2] : '';
          final bool isActive = row.length > 3 ? row[3] == 'نعم' : true;

          final ClientModel? match = _findClient(existing, name, phone);
          if (match != null) {
            await clientsRepo.updateClient(match.copyWith(
              phone: phone.isEmpty ? null : phone,
              notes: notes.isEmpty ? null : notes,
              isActive: isActive,
            ));
            clientsUpdated++;
          } else {
            await clientsRepo.addClient(
              name: name,
              phone: phone.isEmpty ? null : phone,
              notes: notes.isEmpty ? null : notes,
              isActive: isActive,
            );
            clientsCreated++;
          }
        }
      }

      List<SupplierModel> suppliers = <SupplierModel>[];
      if (workbook.tables.containsKey('Suppliers')) {
        suppliers = await suppliersRepo.getSuppliers();
        for (final List<String> row
            in _dataRows(workbook.tables['Suppliers']!, headerMarker: 'الاسم')) {
          final String name = row.isNotEmpty ? row[0] : '';
          if (name.isEmpty) continue;
          final String phone = row.length > 1 ? row[1] : '';
          final String notes = row.length > 2 ? row[2] : '';
          final bool isActive = row.length > 3 ? row[3] == 'نعم' : true;

          final SupplierModel? match = _findSupplier(suppliers, name, phone);
          if (match != null) {
            await suppliersRepo.updateSupplier(match.copyWith(
              phone: phone.isEmpty ? null : phone,
              notes: notes.isEmpty ? null : notes,
              isActive: isActive,
            ));
            suppliersUpdated++;
          } else {
            await suppliersRepo.addSupplier(
              name: name,
              phone: phone.isEmpty ? null : phone,
              notes: notes.isEmpty ? null : notes,
              isActive: isActive,
            );
            suppliersCreated++;
          }
        }
        // Re-read so newly created suppliers are resolvable by the Items pass.
        suppliers = await suppliersRepo.getSuppliers();
      } else {
        suppliers = await suppliersRepo.getSuppliers();
      }

      final String? itemsSheetName = workbook.tables.containsKey('Items')
          ? 'Items'
          : (workbook.tables.containsKey('Cars') ? 'Cars' : null);
      if (itemsSheetName != null) {
        final List<ItemModel> existingItems = await itemsRepo.getItems();
        final List<ItemTypeModel> types = await itemTypesRepo.getTypes();

        for (final List<String> row in _dataRows(
          workbook.tables[itemsSheetName]!,
          headerMarker: 'التسمية',
        )) {
          final String label = row.isNotEmpty ? row[0] : '';
          if (label.isEmpty) continue;
          final String typeName = row.length > 1 ? row[1] : '';
          final String supplierName = row.length > 2 ? row[2] : '';
          final double? cost =
              row.length > 3 ? double.tryParse(row[3]) : null;
          final double? price =
              row.length > 4 ? double.tryParse(row[4]) : null;
          final String notes = row.length > 5 ? row[5] : '';
          final bool isActive = row.length > 6 ? row[6] == 'نعم' : true;

          final SupplierModel? supplier = suppliers.firstWhereOrNullByName(supplierName);
          final ItemTypeModel? itemType = types.firstWhereOrNullByName(typeName);
          if (supplier == null || itemType == null) {
            // Can't place this row without a matching supplier and item
            // type already in the system — skip rather than guess.
            continue;
          }

          final ItemModel? match = _findItem(existingItems, label, supplier.id);

          if (match != null) {
            await itemsRepo.updateItem(
              id: match.id,
              itemTypeId: itemType.id,
              supplierId: supplier.id,
              label: label,
              defaultCost: cost,
              defaultPrice: price,
              expiryDate: match.expiryDate,
              isSingleUse: match.isSingleUse,
              isAvailable: match.isAvailable,
              notes: notes.isEmpty ? null : notes,
              isActive: isActive,
              fieldValues: const <int, String>{},
            );
            itemsUpdated++;
          } else {
            await itemsRepo.addItem(
              itemTypeId: itemType.id,
              supplierId: supplier.id,
              label: label,
              defaultCost: cost,
              defaultPrice: price,
              notes: notes.isEmpty ? null : notes,
              isActive: isActive,
              fieldValues: const <int, String>{},
            );
            itemsCreated++;
          }
        }
      }

      return MasterDataImportSummary(
        clientsCreated: clientsCreated,
        clientsUpdated: clientsUpdated,
        suppliersCreated: suppliersCreated,
        suppliersUpdated: suppliersUpdated,
        itemsCreated: itemsCreated,
        itemsUpdated: itemsUpdated,
        itemTypesCreated: itemTypesCreated,
        fieldsCreated: fieldsCreated,
      );
    } on Failure {
      rethrow;
    } catch (error) {
      throw FileFailure('فشل استيراد الملف: $error', cause: error);
    }
  }

  static ClientModel? _findClient(
      List<ClientModel> clients, String name, String phone) {
    for (final ClientModel c in clients) {
      if (c.name == name && (c.phone ?? '') == phone) return c;
    }
    return null;
  }

  static ItemModel? _findItem(
      List<ItemModel> items, String label, int supplierId) {
    for (final ItemModel i in items) {
      if (i.label == label && i.supplierId == supplierId) return i;
    }
    return null;
  }

  static SupplierModel? _findSupplier(
      List<SupplierModel> suppliers, String name, String phone) {
    for (final SupplierModel s in suppliers) {
      if (s.name == name && (s.phone ?? '') == phone) return s;
    }
    return null;
  }

  /// Rows after the header row (matched by [headerMarker] in the first
  /// column, skipping the brand-banner rows every export sheet starts
  /// with), each cell converted to a trimmed string.
  static List<List<String>> _dataRows(
    xls.Sheet sheet, {
    required String headerMarker,
  }) {
    final List<List<xls.Data?>> rows = sheet.rows;
    int headerIndex = -1;
    for (int i = 0; i < rows.length; i++) {
      final List<xls.Data?> row = rows[i];
      if (row.isNotEmpty && _cellString(row[0]) == headerMarker) {
        headerIndex = i;
        break;
      }
    }
    if (headerIndex == -1) return const <List<String>>[];

    return rows
        .skip(headerIndex + 1)
        .map((List<xls.Data?> row) => row.map(_cellString).toList())
        .toList();
  }

  static String _cellString(xls.Data? cell) =>
      cell?.value?.toString().trim() ?? '';
}

extension _FirstWhereByName on List<SupplierModel> {
  SupplierModel? firstWhereOrNullByName(String name) {
    for (final SupplierModel s in this) {
      if (s.name == name) return s;
    }
    return null;
  }
}

extension _ItemTypeFirstWhereByName on List<ItemTypeModel> {
  ItemTypeModel? firstWhereOrNullByName(String name) {
    for (final ItemTypeModel t in this) {
      if (t.name == name) return t;
    }
    return null;
  }
}

extension _ItemTypeFieldFirstWhereByName on List<ItemTypeFieldModel> {
  ItemTypeFieldModel? firstWhereOrNullByFieldName(String name) {
    for (final ItemTypeFieldModel f in this) {
      if (f.fieldName == name) return f;
    }
    return null;
  }
}
