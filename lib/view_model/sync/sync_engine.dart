import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/local/app_database.dart';
import '../provider/current_user_provider.dart';

/// Outcome of one [SyncEngine.syncAll] run, for the status badge.
class SyncResult {
  const SyncResult({this.pushed = 0, this.pulled = 0, this.errors = const <String>[]});
  final int pushed;
  final int pulled;
  final List<String> errors;
  bool get hasError => errors.isNotEmpty;
}

/// Phase 21, first slice: pushes/pulls the master-data tables (suppliers,
/// clients, item types + their fields, items/cars) between local SQLite and
/// the shared Supabase project. Deals/payments/expenses are not synced yet —
/// see docs/features/phase-21-supabase-cloud-sync.md for the follow-up.
///
/// Conflict rule: last-write-wins by `updated_at`, compared per row. There is
/// no manual conflict-resolution UI in this slice — a losing edit is simply
/// not applied and stays queued for the next push (it is never deleted).
class SyncEngine {
  SyncEngine(this._db, this._client, this._currentUser);

  final AppDatabase _db;
  final SupabaseClient _client;
  final CurrentUserProvider _currentUser;

  /// Table names, in dependency order (parents before children) — the same
  /// order both push and pull must follow so a child's foreign key can
  /// always resolve against an already-linked parent.
  static const List<String> _tableOrder = <String>[
    'suppliers',
    'clients',
    'item_types',
    'item_type_fields',
    'items',
    'expense_categories',
    'transactions',
    'transaction_items',
    'payments',
    'refunds',
    'refund_items',
    'expenses',
  ];

  Future<SyncResult> syncAll() async {
    int pushed = 0;
    int pulled = 0;
    final List<String> errors = <String>[];
    try {
      // ---- Deletes: a local row deleted since the last sync gets its
      // Supabase counterpart removed too, before anything else — otherwise a
      // deleted item would still exist remotely (and could resurface via the
      // pull step further down).
      await _processPendingDeletes();

      // ---- Push: per table, immediate network calls. A push failure never
      // corrupts local data — it only leaves that row queued for next time —
      // so this phase does not need the same all-or-nothing guarantee pull
      // does; each row push is independently idempotent (upsert by remoteId).
      //
      // Each table's push is wrapped separately: a failure on one table (e.g.
      // a duplicate-name conflict) must not stop every other table from
      // pushing and, critically, must not skip the pull phase below — that
      // used to leave every screen showing nothing after a sync error,
      // because one bad row aborted the entire sync.
      pushed += await _pushTable('suppliers', _pushSuppliers, errors);
      pushed += await _pushTable('clients', _pushClients, errors);
      pushed += await _pushTable('item_types', _pushItemTypes, errors);
      pushed += await _pushTable('item_type_fields', _pushItemTypeFields, errors);
      pushed += await _pushTable('items', _pushItems, errors);
      pushed +=
          await _pushTable('expense_categories', _pushExpenseCategories, errors);
      pushed += await _pushTable('transactions', _pushTransactions, errors);
      pushed += await _pushTable(
          'transaction_items', _pushTransactionItems, errors);
      pushed += await _pushTable('payments', _pushPayments, errors);
      pushed += await _pushTable('refunds', _pushRefunds, errors);
      pushed += await _pushTable('refund_items', _pushRefundItems, errors);
      pushed += await _pushTable('expenses', _pushExpenses, errors);

      // ---- Pull: fetch every table's remote rows FIRST (network only, no
      // local writes yet), then apply every local write inside ONE Drift
      // transaction. If anything fails partway through applying them — a
      // thrown exception, the app being killed, a crash — Drift rolls the
      // whole batch back, so the local database is never left with e.g. a
      // deal's `transaction_items` updated but its parent `transactions`
      // totals not, or vice versa. This is the fix for the pull-atomicity
      // gap noted when this table set was added.
      final Map<String, List<Map<String, dynamic>>> remoteRows =
          <String, List<Map<String, dynamic>>>{};
      for (final String table in _tableOrder) {
        remoteRows[table] = await _fetchAllRows(table);
      }

      await _db.transaction(() async {
        // A row deleted straight in Supabase (outside the app, e.g. via the
        // table editor) never queues a local pending-delete — that mechanism
        // only fires when the delete happens through this app. So on every
        // pull, also remove any local row that is still linked to a remote
        // id but no longer appears in that table's remote rows. Children
        // first, mirroring wipeRemoteData's order, so FK constraints on
        // tables without ON DELETE CASCADE (e.g. transaction_items -> items)
        // never block a parent's removal.
        pulled += await _pullRemoteDeletes(remoteRows);

        pulled += await _pullSuppliers(remoteRows['suppliers']!);
        pulled += await _pullClients(remoteRows['clients']!);
        pulled += await _pullItemTypes(remoteRows['item_types']!);
        pulled += await _pullItemTypeFields(remoteRows['item_type_fields']!);
        pulled += await _pullItems(remoteRows['items']!);
        pulled += await _pullExpenseCategories(remoteRows['expense_categories']!);
        pulled += await _pullTransactions(remoteRows['transactions']!);
        pulled += await _pullTransactionItems(remoteRows['transaction_items']!);
        pulled += await _pullPayments(remoteRows['payments']!);
        pulled += await _pullRefunds(remoteRows['refunds']!);
        pulled += await _pullRefundItems(remoteRows['refund_items']!);
        pulled += await _pullExpenses(remoteRows['expenses']!);
      });
    } catch (e) {
      errors.add(e.toString());
    }
    return SyncResult(pushed: pushed, pulled: pulled, errors: errors);
  }

  /// Fetches every row of [table], paging through Supabase's REST API
  /// instead of one plain `.select()` — PostgREST caps an unranged select to
  /// a default row limit (commonly 1000, configurable per-project), so once
  /// a table like `transactions` or `payments` grows past that, a plain
  /// select would silently truncate and a device syncing for the first time
  /// (or after being offline a while) would end up missing rows with no
  /// error at all. Keeps requesting pages until an empty one comes back,
  /// rather than stopping as soon as a page is "short" — a page can be
  /// shorter than requested purely because of the server's own per-request
  /// cap, not because there's no more data.
  Future<List<Map<String, dynamic>>> _fetchAllRows(String table) async {
    const int pageSize = 1000;
    final List<Map<String, dynamic>> all = <Map<String, dynamic>>[];
    int from = 0;
    while (true) {
      final List<Map<String, dynamic>> page =
          await _client.from(table).select().range(from, from + pageSize - 1);
      if (page.isEmpty) break;
      all.addAll(page);
      from += page.length;
    }
    return all;
  }

  /// Runs one table's push function, catching any failure so it can't stop
  /// the other tables from pushing or block the pull phase from running.
  Future<int> _pushTable(
    String table,
    Future<int> Function() push,
    List<String> errors,
  ) async {
    try {
      return await push();
    } catch (e) {
      errors.add('$table: $e');
      return 0;
    }
  }

  String? get _userId => _currentUser.userId;

  // ---------------------------------------------------------------------
  // Suppliers
  // ---------------------------------------------------------------------

  Future<int> _pushSuppliers() async {
    final List<SupplierRow> rows = await _db.select(_db.suppliers).get();
    int count = 0;
    for (final SupplierRow row in rows) {
      final String? remoteId =
          await _db.syncLinksDao.remoteIdFor('suppliers', row.id);
      final Map<String, dynamic> payload = <String, dynamic>{
        'name': row.name,
        'phone': row.phone,
        'notes': row.notes,
        'is_active': row.isActive,
        'is_system_supplier': row.isSystemSupplier,
        'created_at': row.createdAt.toUtc().toIso8601String(),
        'updated_at': (row.updatedAt ?? row.createdAt).toUtc().toIso8601String(),
        'updated_by': _userId,
      };
      if (remoteId != null) {
        await _client.from('suppliers').update(payload).eq('id', remoteId);
      } else {
        final Map<String, dynamic> inserted =
            await _client.from('suppliers').insert(payload).select('id').single();
        await _db.syncLinksDao.link('suppliers', row.id, inserted['id'] as String);
      }
      count++;
    }
    return count;
  }

  Future<int> _pullSuppliers(List<Map<String, dynamic>> remoteRows) async {
    int count = 0;
    for (final Map<String, dynamic> r in remoteRows) {
      final String remoteId = r['id'] as String;
      final DateTime remoteUpdatedAt = DateTime.parse(r['updated_at'] as String);
      final int? localId =
          await _db.syncLinksDao.localIdFor('suppliers', remoteId);
      if (localId != null) {
        final SupplierRow? local = await (_db.select(_db.suppliers)
              ..where(($SuppliersTable t) => t.id.equals(localId)))
            .getSingleOrNull();
        if (local == null) continue;
        final DateTime localUpdatedAt = local.updatedAt ?? local.createdAt;
        if (!remoteUpdatedAt.isAfter(localUpdatedAt)) continue;
        await (_db.update(_db.suppliers)
              ..where(($SuppliersTable t) => t.id.equals(localId)))
            .write(SuppliersCompanion(
          name: Value<String>(r['name'] as String),
          phone: Value<String?>(r['phone'] as String?),
          notes: Value<String?>(r['notes'] as String?),
          isActive: Value<bool>(r['is_active'] as bool? ?? true),
          isSystemSupplier: Value<bool>(r['is_system_supplier'] as bool? ?? false),
          updatedAt: Value<DateTime>(remoteUpdatedAt),
          updatedBy: Value<String?>(r['updated_by'] as String?),
        ));
      } else {
        // A remote system-supplier row is only inserted locally if this
        // device doesn't already have one from its own seed — otherwise two
        // devices that both went online for the first time before ever
        // syncing would end up with two "بوزكري (بدون مورد)" rows.
        if (r['is_system_supplier'] == true) {
          final SupplierRow? existingSystemSupplier = await (_db
                  .select(_db.suppliers)
                ..where(($SuppliersTable t) => t.isSystemSupplier.equals(true)))
              .getSingleOrNull();
          if (existingSystemSupplier != null) {
            await _db.syncLinksDao
                .link('suppliers', existingSystemSupplier.id, remoteId);
            count++;
            continue;
          }
        }
        final int newId = await _db.into(_db.suppliers).insert(
              SuppliersCompanion.insert(
                name: r['name'] as String,
                phone: Value<String?>(r['phone'] as String?),
                notes: Value<String?>(r['notes'] as String?),
                isActive: Value<bool>(r['is_active'] as bool? ?? true),
                isSystemSupplier:
                    Value<bool>(r['is_system_supplier'] as bool? ?? false),
                createdAt: DateTime.parse(r['created_at'] as String),
                updatedAt: Value<DateTime>(remoteUpdatedAt),
                updatedBy: Value<String?>(r['updated_by'] as String?),
              ),
            );
        await _db.syncLinksDao.link('suppliers', newId, remoteId);
      }
      count++;
    }
    return count;
  }

  // ---------------------------------------------------------------------
  // Clients
  // ---------------------------------------------------------------------

  Future<int> _pushClients() async {
    final List<ClientRow> rows = await _db.select(_db.clients).get();
    int count = 0;
    for (final ClientRow row in rows) {
      final String? remoteId =
          await _db.syncLinksDao.remoteIdFor('clients', row.id);
      final Map<String, dynamic> payload = <String, dynamic>{
        'name': row.name,
        'phone': row.phone,
        'notes': row.notes,
        'is_active': row.isActive,
        'created_at': row.createdAt.toUtc().toIso8601String(),
        'passport_id': row.passportId,
        'national_id': row.nationalId,
        'updated_at': (row.updatedAt ?? row.createdAt).toUtc().toIso8601String(),
        'updated_by': _userId,
      };
      if (remoteId != null) {
        await _client.from('clients').update(payload).eq('id', remoteId);
      } else {
        final Map<String, dynamic> inserted =
            await _client.from('clients').insert(payload).select('id').single();
        await _db.syncLinksDao.link('clients', row.id, inserted['id'] as String);
      }
      count++;
    }
    return count;
  }

  Future<int> _pullClients(List<Map<String, dynamic>> remoteRows) async {
    int count = 0;
    for (final Map<String, dynamic> r in remoteRows) {
      final String remoteId = r['id'] as String;
      final DateTime remoteUpdatedAt = DateTime.parse(r['updated_at'] as String);
      final int? localId = await _db.syncLinksDao.localIdFor('clients', remoteId);
      if (localId != null) {
        final ClientRow? local = await (_db.select(_db.clients)
              ..where(($ClientsTable t) => t.id.equals(localId)))
            .getSingleOrNull();
        if (local == null) continue;
        final DateTime localUpdatedAt = local.updatedAt ?? local.createdAt;
        if (!remoteUpdatedAt.isAfter(localUpdatedAt)) continue;
        await (_db.update(_db.clients)
              ..where(($ClientsTable t) => t.id.equals(localId)))
            .write(ClientsCompanion(
          name: Value<String>(r['name'] as String),
          phone: Value<String?>(r['phone'] as String?),
          notes: Value<String?>(r['notes'] as String?),
          isActive: Value<bool>(r['is_active'] as bool? ?? true),
          passportId: Value<String?>(r['passport_id'] as String?),
          nationalId: Value<String?>(r['national_id'] as String?),
          updatedAt: Value<DateTime>(remoteUpdatedAt),
          updatedBy: Value<String?>(r['updated_by'] as String?),
        ));
      } else {
        final int newId = await _db.into(_db.clients).insert(
              ClientsCompanion.insert(
                name: r['name'] as String,
                phone: Value<String?>(r['phone'] as String?),
                notes: Value<String?>(r['notes'] as String?),
                isActive: Value<bool>(r['is_active'] as bool? ?? true),
                createdAt: DateTime.parse(r['created_at'] as String),
                passportId: Value<String?>(r['passport_id'] as String?),
                nationalId: Value<String?>(r['national_id'] as String?),
                updatedAt: Value<DateTime>(remoteUpdatedAt),
                updatedBy: Value<String?>(r['updated_by'] as String?),
              ),
            );
        await _db.syncLinksDao.link('clients', newId, remoteId);
      }
      count++;
    }
    return count;
  }

  // ---------------------------------------------------------------------
  // Item types
  // ---------------------------------------------------------------------

  Future<int> _pushItemTypes() async {
    final List<ItemTypeRow> rows = await _db.select(_db.itemTypes).get();
    int count = 0;
    for (final ItemTypeRow row in rows) {
      final String? remoteId =
          await _db.syncLinksDao.remoteIdFor('item_types', row.id);
      final Map<String, dynamic> payload = <String, dynamic>{
        'name': row.name,
        'created_at': row.createdAt.toUtc().toIso8601String(),
        'updated_at': (row.updatedAt ?? row.createdAt).toUtc().toIso8601String(),
        'updated_by': _userId,
      };
      if (remoteId != null) {
        await _client.from('item_types').update(payload).eq('id', remoteId);
      } else {
        final String linkedRemoteId = await _insertOrLinkByName(
          table: 'item_types',
          payload: payload,
          name: row.name,
        );
        await _db.syncLinksDao.link('item_types', row.id, linkedRemoteId);
      }
      count++;
    }
    return count;
  }

  /// Inserts a row into a table whose `name` column is unique remotely, and
  /// falls back to linking against an already-existing row with the same
  /// name on a 23505 conflict — e.g. two devices that both seeded the same
  /// default item type or expense category locally before either had ever
  /// synced. Without this, the second device's push throws a
  /// PostgrestException that (before this fix) aborted the entire sync,
  /// including the pull phase, leaving every screen looking empty.
  Future<String> _insertOrLinkByName({
    required String table,
    required Map<String, dynamic> payload,
    required String name,
  }) async {
    try {
      final Map<String, dynamic> inserted =
          await _client.from(table).insert(payload).select('id').single();
      return inserted['id'] as String;
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
      final Map<String, dynamic> existing =
          await _client.from(table).select('id').eq('name', name).single();
      return existing['id'] as String;
    }
  }

  Future<int> _pullItemTypes(List<Map<String, dynamic>> remoteRows) async {
    int count = 0;
    for (final Map<String, dynamic> r in remoteRows) {
      final String remoteId = r['id'] as String;
      final DateTime remoteUpdatedAt = DateTime.parse(r['updated_at'] as String);
      final int? localId =
          await _db.syncLinksDao.localIdFor('item_types', remoteId);
      if (localId != null) {
        final ItemTypeRow? local = await (_db.select(_db.itemTypes)
              ..where(($ItemTypesTable t) => t.id.equals(localId)))
            .getSingleOrNull();
        if (local == null) continue;
        final DateTime localUpdatedAt = local.updatedAt ?? local.createdAt;
        if (!remoteUpdatedAt.isAfter(localUpdatedAt)) continue;
        await (_db.update(_db.itemTypes)
              ..where(($ItemTypesTable t) => t.id.equals(localId)))
            .write(ItemTypesCompanion(
          name: Value<String>(r['name'] as String),
          updatedAt: Value<DateTime>(remoteUpdatedAt),
        ));
      } else {
        final int newId = await _db.into(_db.itemTypes).insert(
              ItemTypesCompanion.insert(
                name: r['name'] as String,
                createdAt: DateTime.parse(r['created_at'] as String),
                updatedAt: Value<DateTime>(remoteUpdatedAt),
              ),
            );
        await _db.syncLinksDao.link('item_types', newId, remoteId);
      }
      count++;
    }
    return count;
  }

  // ---------------------------------------------------------------------
  // Item type fields (FK: item_type_id -> item_types)
  // ---------------------------------------------------------------------

  Future<int> _pushItemTypeFields() async {
    final List<ItemTypeFieldRow> rows = await _db.select(_db.itemTypeFields).get();
    int count = 0;
    for (final ItemTypeFieldRow row in rows) {
      final String? parentRemoteId =
          await _db.syncLinksDao.remoteIdFor('item_types', row.itemTypeId);
      if (parentRemoteId == null) continue; // parent not synced yet
      final String? remoteId =
          await _db.syncLinksDao.remoteIdFor('item_type_fields', row.id);
      final Map<String, dynamic> payload = <String, dynamic>{
        'item_type_id': parentRemoteId,
        'field_name': row.fieldName,
        'field_type': row.fieldType,
        'is_required': row.isRequired,
        'sort_order': row.sortOrder,
        'updated_at': (row.updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
        'updated_by': _userId,
      };
      if (remoteId != null) {
        await _client.from('item_type_fields').update(payload).eq('id', remoteId);
      } else {
        final Map<String, dynamic> inserted = await _client
            .from('item_type_fields')
            .insert(payload)
            .select('id')
            .single();
        await _db.syncLinksDao
            .link('item_type_fields', row.id, inserted['id'] as String);
      }
      count++;
    }
    return count;
  }

  Future<int> _pullItemTypeFields(List<Map<String, dynamic>> remoteRows) async {
    int count = 0;
    for (final Map<String, dynamic> r in remoteRows) {
      final String remoteId = r['id'] as String;
      final int? parentLocalId = await _db.syncLinksDao
          .localIdFor('item_types', r['item_type_id'] as String);
      if (parentLocalId == null) continue; // parent not pulled yet
      final DateTime remoteUpdatedAt = DateTime.parse(r['updated_at'] as String);
      final int? localId =
          await _db.syncLinksDao.localIdFor('item_type_fields', remoteId);
      if (localId != null) {
        final ItemTypeFieldRow? local = await (_db.select(_db.itemTypeFields)
              ..where(($ItemTypeFieldsTable t) => t.id.equals(localId)))
            .getSingleOrNull();
        if (local == null) continue;
        final DateTime localUpdatedAt = local.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        if (!remoteUpdatedAt.isAfter(localUpdatedAt)) continue;
        await (_db.update(_db.itemTypeFields)
              ..where(($ItemTypeFieldsTable t) => t.id.equals(localId)))
            .write(ItemTypeFieldsCompanion(
          itemTypeId: Value<int>(parentLocalId),
          fieldName: Value<String>(r['field_name'] as String),
          fieldType: Value<String>(r['field_type'] as String),
          isRequired: Value<bool>(r['is_required'] as bool? ?? false),
          sortOrder: Value<int>(r['sort_order'] as int? ?? 0),
          updatedAt: Value<DateTime>(remoteUpdatedAt),
        ));
      } else {
        final int newId = await _db.into(_db.itemTypeFields).insert(
              ItemTypeFieldsCompanion.insert(
                itemTypeId: parentLocalId,
                fieldName: r['field_name'] as String,
                fieldType: r['field_type'] as String,
                isRequired: Value<bool>(r['is_required'] as bool? ?? false),
                sortOrder: Value<int>(r['sort_order'] as int? ?? 0),
                updatedAt: Value<DateTime>(remoteUpdatedAt),
              ),
            );
        await _db.syncLinksDao.link('item_type_fields', newId, remoteId);
      }
      count++;
    }
    return count;
  }

  // ---------------------------------------------------------------------
  // Items (FK: item_type_id -> item_types, supplier_id -> suppliers)
  // ---------------------------------------------------------------------

  Future<int> _pushItems() async {
    final List<ItemRow> rows = await _db.select(_db.items).get();
    int count = 0;
    for (final ItemRow row in rows) {
      final String? typeRemoteId =
          await _db.syncLinksDao.remoteIdFor('item_types', row.itemTypeId);
      final String? supplierRemoteId =
          await _db.syncLinksDao.remoteIdFor('suppliers', row.supplierId);
      if (typeRemoteId == null || supplierRemoteId == null) continue;
      final String? remoteId = await _db.syncLinksDao.remoteIdFor('items', row.id);
      final Map<String, dynamic> payload = <String, dynamic>{
        'item_type_id': typeRemoteId,
        'supplier_id': supplierRemoteId,
        'label': row.label,
        'default_cost': row.defaultCost,
        'default_price': row.defaultPrice,
        'expiry_date': row.expiryDate?.toUtc().toIso8601String(),
        'is_single_use': row.isSingleUse,
        'is_available': row.isAvailable,
        'notes': row.notes,
        'is_active': row.isActive,
        'created_at': row.createdAt.toUtc().toIso8601String(),
        'updated_at': (row.updatedAt ?? row.createdAt).toUtc().toIso8601String(),
        'updated_by': _userId,
      };
      if (remoteId != null) {
        await _client.from('items').update(payload).eq('id', remoteId);
      } else {
        final Map<String, dynamic> inserted =
            await _client.from('items').insert(payload).select('id').single();
        await _db.syncLinksDao.link('items', row.id, inserted['id'] as String);
      }
      count++;
    }
    return count;
  }

  Future<int> _pullItems(List<Map<String, dynamic>> remoteRows) async {
    int count = 0;
    for (final Map<String, dynamic> r in remoteRows) {
      final String remoteId = r['id'] as String;
      final int? typeLocalId = await _db.syncLinksDao
          .localIdFor('item_types', r['item_type_id'] as String);
      final int? supplierLocalId = await _db.syncLinksDao
          .localIdFor('suppliers', r['supplier_id'] as String);
      if (typeLocalId == null || supplierLocalId == null) continue;
      final DateTime remoteUpdatedAt = DateTime.parse(r['updated_at'] as String);
      final int? localId = await _db.syncLinksDao.localIdFor('items', remoteId);
      final DateTime? expiryDate = r['expiry_date'] == null
          ? null
          : DateTime.parse(r['expiry_date'] as String);
      if (localId != null) {
        final ItemRow? local = await (_db.select(_db.items)
              ..where(($ItemsTable t) => t.id.equals(localId)))
            .getSingleOrNull();
        if (local == null) continue;
        final DateTime localUpdatedAt = local.updatedAt ?? local.createdAt;
        if (!remoteUpdatedAt.isAfter(localUpdatedAt)) continue;
        await (_db.update(_db.items)..where(($ItemsTable t) => t.id.equals(localId)))
            .write(ItemsCompanion(
          itemTypeId: Value<int>(typeLocalId),
          supplierId: Value<int>(supplierLocalId),
          label: Value<String>(r['label'] as String),
          defaultCost: Value<double?>((r['default_cost'] as num?)?.toDouble()),
          defaultPrice: Value<double?>((r['default_price'] as num?)?.toDouble()),
          expiryDate: Value<DateTime?>(expiryDate),
          isSingleUse: Value<bool>(r['is_single_use'] as bool? ?? false),
          isAvailable: Value<bool>(r['is_available'] as bool? ?? true),
          notes: Value<String?>(r['notes'] as String?),
          isActive: Value<bool>(r['is_active'] as bool? ?? true),
          updatedAt: Value<DateTime>(remoteUpdatedAt),
          updatedBy: Value<String?>(r['updated_by'] as String?),
        ));
      } else {
        final int newId = await _db.into(_db.items).insert(
              ItemsCompanion.insert(
                itemTypeId: typeLocalId,
                supplierId: supplierLocalId,
                label: r['label'] as String,
                defaultCost: Value<double?>((r['default_cost'] as num?)?.toDouble()),
                defaultPrice: Value<double?>((r['default_price'] as num?)?.toDouble()),
                expiryDate: Value<DateTime?>(expiryDate),
                isSingleUse: Value<bool>(r['is_single_use'] as bool? ?? false),
                isAvailable: Value<bool>(r['is_available'] as bool? ?? true),
                notes: Value<String?>(r['notes'] as String?),
                isActive: Value<bool>(r['is_active'] as bool? ?? true),
                createdAt: DateTime.parse(r['created_at'] as String),
                updatedAt: Value<DateTime>(remoteUpdatedAt),
                updatedBy: Value<String?>(r['updated_by'] as String?),
              ),
            );
        await _db.syncLinksDao.link('items', newId, remoteId);
      }
      count++;
    }
    return count;
  }

  // ---------------------------------------------------------------------
  // Expense categories
  // ---------------------------------------------------------------------

  Future<int> _pushExpenseCategories() async {
    final List<ExpenseCategoryRow> rows =
        await _db.select(_db.expenseCategories).get();
    int count = 0;
    for (final ExpenseCategoryRow row in rows) {
      final String? remoteId =
          await _db.syncLinksDao.remoteIdFor('expense_categories', row.id);
      final Map<String, dynamic> payload = <String, dynamic>{
        'name': row.name,
        'updated_at': (row.updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
        'updated_by': _userId,
      };
      if (remoteId != null) {
        await _client.from('expense_categories').update(payload).eq('id', remoteId);
      } else {
        final String linkedRemoteId = await _insertOrLinkByName(
          table: 'expense_categories',
          payload: payload,
          name: row.name,
        );
        await _db.syncLinksDao
            .link('expense_categories', row.id, linkedRemoteId);
      }
      count++;
    }
    return count;
  }

  Future<int> _pullExpenseCategories(List<Map<String, dynamic>> remoteRows) async {
    int count = 0;
    for (final Map<String, dynamic> r in remoteRows) {
      final String remoteId = r['id'] as String;
      final DateTime remoteUpdatedAt = DateTime.parse(r['updated_at'] as String);
      final int? localId =
          await _db.syncLinksDao.localIdFor('expense_categories', remoteId);
      if (localId != null) {
        final ExpenseCategoryRow? local = await (_db.select(_db.expenseCategories)
              ..where(($ExpenseCategoriesTable t) => t.id.equals(localId)))
            .getSingleOrNull();
        if (local == null) continue;
        final DateTime localUpdatedAt =
            local.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        if (!remoteUpdatedAt.isAfter(localUpdatedAt)) continue;
        await (_db.update(_db.expenseCategories)
              ..where(($ExpenseCategoriesTable t) => t.id.equals(localId)))
            .write(ExpenseCategoriesCompanion(
          name: Value<String>(r['name'] as String),
          updatedAt: Value<DateTime>(remoteUpdatedAt),
        ));
      } else {
        final int newId = await _db.into(_db.expenseCategories).insert(
              ExpenseCategoriesCompanion.insert(
                name: r['name'] as String,
                updatedAt: Value<DateTime>(remoteUpdatedAt),
              ),
              mode: InsertMode.insertOrIgnore,
            );
        if (newId != 0) {
          await _db.syncLinksDao.link('expense_categories', newId, remoteId);
        }
      }
      count++;
    }
    return count;
  }

  // ---------------------------------------------------------------------
  // Transactions (FK: client_id -> clients)
  // ---------------------------------------------------------------------

  Future<int> _pushTransactions() async {
    final List<TransactionRow> rows = await _db.select(_db.transactions).get();
    int count = 0;
    for (final TransactionRow row in rows) {
      final String? clientRemoteId =
          await _db.syncLinksDao.remoteIdFor('clients', row.clientId);
      if (clientRemoteId == null) continue;
      final String? remoteId =
          await _db.syncLinksDao.remoteIdFor('transactions', row.id);
      final Map<String, dynamic> payload = <String, dynamic>{
        'client_id': clientRemoteId,
        'date_time': row.occurredAt.toUtc().toIso8601String(),
        'deal_type': row.dealType,
        'subtotal': row.subtotal,
        'discount': row.discount,
        'total': row.total,
        'total_cost': row.totalCost,
        'status': row.status,
        'notes': row.notes,
        'commission_name': row.commissionName,
        'commission_amount': row.commissionAmount,
        'payment_status_override': row.paymentStatusOverride,
        'updated_at': (row.updatedAt ?? row.occurredAt).toUtc().toIso8601String(),
        'updated_by': _userId,
      };
      if (remoteId != null) {
        await _client.from('transactions').update(payload).eq('id', remoteId);
      } else {
        final Map<String, dynamic> inserted =
            await _client.from('transactions').insert(payload).select('id').single();
        await _db.syncLinksDao.link('transactions', row.id, inserted['id'] as String);
      }
      count++;
    }
    return count;
  }

  Future<int> _pullTransactions(List<Map<String, dynamic>> remoteRows) async {
    int count = 0;
    for (final Map<String, dynamic> r in remoteRows) {
      final String remoteId = r['id'] as String;
      final int? clientLocalId =
          await _db.syncLinksDao.localIdFor('clients', r['client_id'] as String);
      if (clientLocalId == null) continue;
      final DateTime remoteUpdatedAt = DateTime.parse(r['updated_at'] as String);
      final int? localId =
          await _db.syncLinksDao.localIdFor('transactions', remoteId);
      if (localId != null) {
        final TransactionRow? local = await (_db.select(_db.transactions)
              ..where(($TransactionsTable t) => t.id.equals(localId)))
            .getSingleOrNull();
        if (local == null) continue;
        final DateTime localUpdatedAt = local.updatedAt ?? local.occurredAt;
        if (!remoteUpdatedAt.isAfter(localUpdatedAt)) continue;
        await (_db.update(_db.transactions)
              ..where(($TransactionsTable t) => t.id.equals(localId)))
            .write(TransactionsCompanion(
          clientId: Value<int>(clientLocalId),
          occurredAt: Value<DateTime>(DateTime.parse(r['date_time'] as String)),
          dealType: Value<String>(r['deal_type'] as String),
          subtotal: Value<double>((r['subtotal'] as num).toDouble()),
          discount: Value<double>((r['discount'] as num).toDouble()),
          total: Value<double>((r['total'] as num).toDouble()),
          totalCost: Value<double>((r['total_cost'] as num).toDouble()),
          status: Value<String>(r['status'] as String),
          notes: Value<String?>(r['notes'] as String?),
          commissionName: Value<String?>(r['commission_name'] as String?),
          commissionAmount:
              Value<double?>((r['commission_amount'] as num?)?.toDouble()),
          paymentStatusOverride:
              Value<String?>(r['payment_status_override'] as String?),
          updatedAt: Value<DateTime>(remoteUpdatedAt),
          updatedBy: Value<String?>(r['updated_by'] as String?),
        ));
      } else {
        final int newId = await _db.into(_db.transactions).insert(
              TransactionsCompanion.insert(
                clientId: clientLocalId,
                occurredAt: DateTime.parse(r['date_time'] as String),
                dealType: r['deal_type'] as String,
                subtotal: (r['subtotal'] as num).toDouble(),
                total: (r['total'] as num).toDouble(),
                totalCost: (r['total_cost'] as num).toDouble(),
                status: r['status'] as String,
                discount: Value<double>((r['discount'] as num?)?.toDouble() ?? 0),
                notes: Value<String?>(r['notes'] as String?),
                commissionName: Value<String?>(r['commission_name'] as String?),
                commissionAmount:
                    Value<double?>((r['commission_amount'] as num?)?.toDouble()),
                paymentStatusOverride:
                    Value<String?>(r['payment_status_override'] as String?),
                updatedAt: Value<DateTime>(remoteUpdatedAt),
                updatedBy: Value<String?>(r['updated_by'] as String?),
              ),
            );
        await _db.syncLinksDao.link('transactions', newId, remoteId);
      }
      count++;
    }
    return count;
  }

  // ---------------------------------------------------------------------
  // Transaction items (FK: transaction_id, item_id, supplier_id)
  // ---------------------------------------------------------------------

  Future<int> _pushTransactionItems() async {
    final List<TransactionItemRow> rows =
        await _db.select(_db.transactionItems).get();
    int count = 0;
    for (final TransactionItemRow row in rows) {
      final String? txRemoteId =
          await _db.syncLinksDao.remoteIdFor('transactions', row.transactionId);
      final String? itemRemoteId =
          await _db.syncLinksDao.remoteIdFor('items', row.itemId);
      final String? supplierRemoteId =
          await _db.syncLinksDao.remoteIdFor('suppliers', row.supplierId);
      if (txRemoteId == null || itemRemoteId == null || supplierRemoteId == null) {
        continue;
      }
      final String? remoteId =
          await _db.syncLinksDao.remoteIdFor('transaction_items', row.id);
      final Map<String, dynamic> payload = <String, dynamic>{
        'transaction_id': txRemoteId,
        'item_id': itemRemoteId,
        'supplier_id': supplierRemoteId,
        'deal_type': row.dealType,
        'qty': row.qty,
        'unit_cost': row.unitCost,
        'unit_price': row.unitPrice,
        'line_total': row.lineTotal,
        'rent_start': row.rentStart?.toUtc().toIso8601String(),
        'rent_end': row.rentEnd?.toUtc().toIso8601String(),
        'expiry_date': row.expiryDate?.toUtc().toIso8601String(),
        'notes': row.notes,
        'price_per_day': row.pricePerDay,
        'cost_per_day': row.costPerDay,
        'days': row.days,
        'allowed_km_per_day': row.allowedKmPerDay,
        'extra_km_rate': row.extraKmRate,
        'pickup_kilometer': row.pickupKilometer,
        'return_kilometer': row.returnKilometer,
        'extra_km_charge': row.extraKmCharge,
        'line_status': row.lineStatus,
        'updated_at': (row.updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
        'updated_by': _userId,
      };
      if (remoteId != null) {
        await _client.from('transaction_items').update(payload).eq('id', remoteId);
      } else {
        final Map<String, dynamic> inserted = await _client
            .from('transaction_items')
            .insert(payload)
            .select('id')
            .single();
        await _db.syncLinksDao
            .link('transaction_items', row.id, inserted['id'] as String);
      }
      count++;
    }
    return count;
  }

  Future<int> _pullTransactionItems(List<Map<String, dynamic>> remoteRows) async {
    int count = 0;
    for (final Map<String, dynamic> r in remoteRows) {
      final String remoteId = r['id'] as String;
      final int? txLocalId = await _db.syncLinksDao
          .localIdFor('transactions', r['transaction_id'] as String);
      final int? itemLocalId =
          await _db.syncLinksDao.localIdFor('items', r['item_id'] as String);
      final int? supplierLocalId =
          await _db.syncLinksDao.localIdFor('suppliers', r['supplier_id'] as String);
      if (txLocalId == null || itemLocalId == null || supplierLocalId == null) {
        continue;
      }
      final DateTime remoteUpdatedAt = DateTime.parse(r['updated_at'] as String);
      final int? localId =
          await _db.syncLinksDao.localIdFor('transaction_items', remoteId);
      final DateTime? rentStart =
          r['rent_start'] == null ? null : DateTime.parse(r['rent_start'] as String);
      final DateTime? rentEnd =
          r['rent_end'] == null ? null : DateTime.parse(r['rent_end'] as String);
      final DateTime? expiryDate = r['expiry_date'] == null
          ? null
          : DateTime.parse(r['expiry_date'] as String);
      if (localId != null) {
        final TransactionItemRow? local = await (_db.select(_db.transactionItems)
              ..where(($TransactionItemsTable t) => t.id.equals(localId)))
            .getSingleOrNull();
        if (local == null) continue;
        final DateTime localUpdatedAt =
            local.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        if (!remoteUpdatedAt.isAfter(localUpdatedAt)) continue;
        await (_db.update(_db.transactionItems)
              ..where(($TransactionItemsTable t) => t.id.equals(localId)))
            .write(TransactionItemsCompanion(
          transactionId: Value<int>(txLocalId),
          itemId: Value<int>(itemLocalId),
          supplierId: Value<int>(supplierLocalId),
          dealType: Value<String>(r['deal_type'] as String),
          qty: Value<int>(r['qty'] as int? ?? 1),
          unitCost: Value<double>((r['unit_cost'] as num).toDouble()),
          unitPrice: Value<double>((r['unit_price'] as num).toDouble()),
          lineTotal: Value<double>((r['line_total'] as num).toDouble()),
          rentStart: Value<DateTime?>(rentStart),
          rentEnd: Value<DateTime?>(rentEnd),
          expiryDate: Value<DateTime?>(expiryDate),
          notes: Value<String?>(r['notes'] as String?),
          pricePerDay: Value<double?>((r['price_per_day'] as num?)?.toDouble()),
          costPerDay: Value<double?>((r['cost_per_day'] as num?)?.toDouble()),
          days: Value<int?>(r['days'] as int?),
          allowedKmPerDay:
              Value<double?>((r['allowed_km_per_day'] as num?)?.toDouble()),
          extraKmRate: Value<double?>((r['extra_km_rate'] as num?)?.toDouble()),
          pickupKilometer:
              Value<double?>((r['pickup_kilometer'] as num?)?.toDouble()),
          returnKilometer:
              Value<double?>((r['return_kilometer'] as num?)?.toDouble()),
          extraKmCharge: Value<double?>((r['extra_km_charge'] as num?)?.toDouble()),
          lineStatus: Value<String>(r['line_status'] as String? ?? 'active'),
          updatedAt: Value<DateTime>(remoteUpdatedAt),
        ));
      } else {
        final int newId = await _db.into(_db.transactionItems).insert(
              TransactionItemsCompanion.insert(
                transactionId: txLocalId,
                itemId: itemLocalId,
                supplierId: supplierLocalId,
                dealType: r['deal_type'] as String,
                unitCost: (r['unit_cost'] as num).toDouble(),
                unitPrice: (r['unit_price'] as num).toDouble(),
                lineTotal: (r['line_total'] as num).toDouble(),
                qty: Value<int>(r['qty'] as int? ?? 1),
                rentStart: Value<DateTime?>(rentStart),
                rentEnd: Value<DateTime?>(rentEnd),
                expiryDate: Value<DateTime?>(expiryDate),
                notes: Value<String?>(r['notes'] as String?),
                pricePerDay: Value<double?>((r['price_per_day'] as num?)?.toDouble()),
                costPerDay: Value<double?>((r['cost_per_day'] as num?)?.toDouble()),
                days: Value<int?>(r['days'] as int?),
                allowedKmPerDay:
                    Value<double?>((r['allowed_km_per_day'] as num?)?.toDouble()),
                extraKmRate: Value<double?>((r['extra_km_rate'] as num?)?.toDouble()),
                pickupKilometer:
                    Value<double?>((r['pickup_kilometer'] as num?)?.toDouble()),
                returnKilometer:
                    Value<double?>((r['return_kilometer'] as num?)?.toDouble()),
                extraKmCharge:
                    Value<double?>((r['extra_km_charge'] as num?)?.toDouble()),
                lineStatus: Value<String>(r['line_status'] as String? ?? 'active'),
                updatedAt: Value<DateTime>(remoteUpdatedAt),
              ),
            );
        await _db.syncLinksDao.link('transaction_items', newId, remoteId);
      }
      count++;
    }
    return count;
  }

  // ---------------------------------------------------------------------
  // Payments (FK: transaction_id, supplier_id?, transaction_item_id?)
  // ---------------------------------------------------------------------

  Future<int> _pushPayments() async {
    final List<PaymentRow> rows = await _db.select(_db.payments).get();
    int count = 0;
    for (final PaymentRow row in rows) {
      final String? txRemoteId =
          await _db.syncLinksDao.remoteIdFor('transactions', row.transactionId);
      if (txRemoteId == null) continue;
      final String? supplierRemoteId = row.supplierId == null
          ? null
          : await _db.syncLinksDao.remoteIdFor('suppliers', row.supplierId!);
      final String? lineRemoteId = row.transactionItemId == null
          ? null
          : await _db.syncLinksDao
              .remoteIdFor('transaction_items', row.transactionItemId!);
      final String? remoteId =
          await _db.syncLinksDao.remoteIdFor('payments', row.id);
      final Map<String, dynamic> payload = <String, dynamic>{
        'transaction_id': txRemoteId,
        'party': row.party,
        'supplier_id': supplierRemoteId,
        'method': row.method,
        'amount': row.amount,
        'date_time': row.occurredAt.toUtc().toIso8601String(),
        'notes': row.notes,
        'transaction_item_id': lineRemoteId,
        'rental_day_date': row.rentalDayDate?.toUtc().toIso8601String(),
        'voided': row.voided,
        'updated_at': (row.updatedAt ?? row.occurredAt).toUtc().toIso8601String(),
        'updated_by': _userId,
      };
      if (remoteId != null) {
        await _client.from('payments').update(payload).eq('id', remoteId);
      } else {
        final Map<String, dynamic> inserted =
            await _client.from('payments').insert(payload).select('id').single();
        await _db.syncLinksDao.link('payments', row.id, inserted['id'] as String);
      }
      count++;
    }
    return count;
  }

  Future<int> _pullPayments(List<Map<String, dynamic>> remoteRows) async {
    int count = 0;
    for (final Map<String, dynamic> r in remoteRows) {
      final String remoteId = r['id'] as String;
      final int? txLocalId = await _db.syncLinksDao
          .localIdFor('transactions', r['transaction_id'] as String);
      if (txLocalId == null) continue;
      final int? supplierLocalId = r['supplier_id'] == null
          ? null
          : await _db.syncLinksDao
              .localIdFor('suppliers', r['supplier_id'] as String);
      final int? lineLocalId = r['transaction_item_id'] == null
          ? null
          : await _db.syncLinksDao
              .localIdFor('transaction_items', r['transaction_item_id'] as String);
      final DateTime remoteUpdatedAt = DateTime.parse(r['updated_at'] as String);
      final int? localId = await _db.syncLinksDao.localIdFor('payments', remoteId);
      final DateTime? rentalDayDate = r['rental_day_date'] == null
          ? null
          : DateTime.parse(r['rental_day_date'] as String);
      if (localId != null) {
        final PaymentRow? local = await (_db.select(_db.payments)
              ..where(($PaymentsTable t) => t.id.equals(localId)))
            .getSingleOrNull();
        if (local == null) continue;
        final DateTime localUpdatedAt = local.updatedAt ?? local.occurredAt;
        if (!remoteUpdatedAt.isAfter(localUpdatedAt)) continue;
        await (_db.update(_db.payments)
              ..where(($PaymentsTable t) => t.id.equals(localId)))
            .write(PaymentsCompanion(
          transactionId: Value<int>(txLocalId),
          party: Value<String>(r['party'] as String),
          supplierId: Value<int?>(supplierLocalId),
          method: Value<String>(r['method'] as String),
          amount: Value<double>((r['amount'] as num).toDouble()),
          occurredAt: Value<DateTime>(DateTime.parse(r['date_time'] as String)),
          notes: Value<String?>(r['notes'] as String?),
          transactionItemId: Value<int?>(lineLocalId),
          rentalDayDate: Value<DateTime?>(rentalDayDate),
          voided: Value<bool>(r['voided'] as bool? ?? false),
          updatedAt: Value<DateTime>(remoteUpdatedAt),
        ));
      } else {
        final int newId = await _db.into(_db.payments).insert(
              PaymentsCompanion.insert(
                transactionId: txLocalId,
                party: r['party'] as String,
                method: r['method'] as String,
                amount: (r['amount'] as num).toDouble(),
                occurredAt: DateTime.parse(r['date_time'] as String),
                supplierId: Value<int?>(supplierLocalId),
                notes: Value<String?>(r['notes'] as String?),
                transactionItemId: Value<int?>(lineLocalId),
                rentalDayDate: Value<DateTime?>(rentalDayDate),
                voided: Value<bool>(r['voided'] as bool? ?? false),
                updatedAt: Value<DateTime>(remoteUpdatedAt),
              ),
            );
        await _db.syncLinksDao.link('payments', newId, remoteId);
      }
      count++;
    }
    return count;
  }

  // ---------------------------------------------------------------------
  // Refunds (FK: transaction_id) — insert-only locally (plus whole-row
  // delete, not propagated by this sync engine yet)
  // ---------------------------------------------------------------------

  Future<int> _pushRefunds() async {
    final List<RefundRow> rows = await _db.select(_db.refunds).get();
    int count = 0;
    for (final RefundRow row in rows) {
      final String? txRemoteId =
          await _db.syncLinksDao.remoteIdFor('transactions', row.transactionId);
      if (txRemoteId == null) continue;
      final String? remoteId = await _db.syncLinksDao.remoteIdFor('refunds', row.id);
      if (remoteId != null) continue; // never updated locally after insert
      final Map<String, dynamic> payload = <String, dynamic>{
        'transaction_id': txRemoteId,
        'date_time': row.occurredAt.toUtc().toIso8601String(),
        'total_refunded': row.totalRefunded,
        'total_cost_refunded': row.totalCostRefunded,
        'reason': row.reason,
        'updated_at': (row.updatedAt ?? row.occurredAt).toUtc().toIso8601String(),
        'updated_by': _userId,
      };
      final Map<String, dynamic> inserted =
          await _client.from('refunds').insert(payload).select('id').single();
      await _db.syncLinksDao.link('refunds', row.id, inserted['id'] as String);
      count++;
    }
    return count;
  }

  Future<int> _pullRefunds(List<Map<String, dynamic>> remoteRows) async {
    int count = 0;
    for (final Map<String, dynamic> r in remoteRows) {
      final String remoteId = r['id'] as String;
      final int? existingLocalId =
          await _db.syncLinksDao.localIdFor('refunds', remoteId);
      if (existingLocalId != null) continue; // already have it, never updated
      final int? txLocalId = await _db.syncLinksDao
          .localIdFor('transactions', r['transaction_id'] as String);
      if (txLocalId == null) continue;
      final int newId = await _db.into(_db.refunds).insert(
            RefundsCompanion.insert(
              transactionId: txLocalId,
              occurredAt: DateTime.parse(r['date_time'] as String),
              totalRefunded: (r['total_refunded'] as num).toDouble(),
              totalCostRefunded: (r['total_cost_refunded'] as num).toDouble(),
              reason: Value<String?>(r['reason'] as String?),
              updatedAt: Value<DateTime>(DateTime.parse(r['updated_at'] as String)),
            ),
          );
      await _db.syncLinksDao.link('refunds', newId, remoteId);
      count++;
    }
    return count;
  }

  // ---------------------------------------------------------------------
  // Refund items (FK: refund_id, transaction_item_id, item_id) — insert-only
  // ---------------------------------------------------------------------

  Future<int> _pushRefundItems() async {
    final List<RefundItemRow> rows = await _db.select(_db.refundItems).get();
    int count = 0;
    for (final RefundItemRow row in rows) {
      final String? remoteId =
          await _db.syncLinksDao.remoteIdFor('refund_items', row.id);
      if (remoteId != null) continue;
      final String? refundRemoteId =
          await _db.syncLinksDao.remoteIdFor('refunds', row.refundId);
      final String? lineRemoteId = await _db.syncLinksDao
          .remoteIdFor('transaction_items', row.transactionItemId);
      final String? itemRemoteId =
          await _db.syncLinksDao.remoteIdFor('items', row.itemId);
      if (refundRemoteId == null || lineRemoteId == null || itemRemoteId == null) {
        continue;
      }
      final Map<String, dynamic> payload = <String, dynamic>{
        'refund_id': refundRemoteId,
        'transaction_item_id': lineRemoteId,
        'item_id': itemRemoteId,
        'qty': row.qty,
        'unit_cost': row.unitCost,
        'unit_price': row.unitPrice,
        'updated_at': (row.updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
        'updated_by': _userId,
      };
      final Map<String, dynamic> inserted =
          await _client.from('refund_items').insert(payload).select('id').single();
      await _db.syncLinksDao.link('refund_items', row.id, inserted['id'] as String);
      count++;
    }
    return count;
  }

  Future<int> _pullRefundItems(List<Map<String, dynamic>> remoteRows) async {
    int count = 0;
    for (final Map<String, dynamic> r in remoteRows) {
      final String remoteId = r['id'] as String;
      final int? existingLocalId =
          await _db.syncLinksDao.localIdFor('refund_items', remoteId);
      if (existingLocalId != null) continue;
      final int? refundLocalId =
          await _db.syncLinksDao.localIdFor('refunds', r['refund_id'] as String);
      final int? lineLocalId = await _db.syncLinksDao
          .localIdFor('transaction_items', r['transaction_item_id'] as String);
      final int? itemLocalId =
          await _db.syncLinksDao.localIdFor('items', r['item_id'] as String);
      if (refundLocalId == null || lineLocalId == null || itemLocalId == null) {
        continue;
      }
      final int newId = await _db.into(_db.refundItems).insert(
            RefundItemsCompanion.insert(
              refundId: refundLocalId,
              transactionItemId: lineLocalId,
              itemId: itemLocalId,
              qty: r['qty'] as int,
              unitCost: (r['unit_cost'] as num).toDouble(),
              unitPrice: (r['unit_price'] as num).toDouble(),
              updatedAt:
                  Value<DateTime>(DateTime.parse(r['updated_at'] as String)),
            ),
          );
      await _db.syncLinksDao.link('refund_items', newId, remoteId);
      count++;
    }
    return count;
  }

  // ---------------------------------------------------------------------
  // Expenses (FK: category_id?, transaction_id?)
  // ---------------------------------------------------------------------

  Future<int> _pushExpenses() async {
    final List<ExpenseRow> rows = await _db.select(_db.expenses).get();
    int count = 0;
    for (final ExpenseRow row in rows) {
      final String? categoryRemoteId = row.categoryId == null
          ? null
          : await _db.syncLinksDao.remoteIdFor('expense_categories', row.categoryId!);
      final String? txRemoteId = row.transactionId == null
          ? null
          : await _db.syncLinksDao.remoteIdFor('transactions', row.transactionId!);
      final String? remoteId = await _db.syncLinksDao.remoteIdFor('expenses', row.id);
      final Map<String, dynamic> payload = <String, dynamic>{
        'title': row.title,
        'amount': row.amount,
        'category_id': categoryRemoteId,
        'transaction_id': txRemoteId,
        'date_time': row.occurredAt.toUtc().toIso8601String(),
        'note': row.note,
        'updated_at': (row.updatedAt ?? row.occurredAt).toUtc().toIso8601String(),
        'updated_by': _userId,
      };
      if (remoteId != null) {
        await _client.from('expenses').update(payload).eq('id', remoteId);
      } else {
        final Map<String, dynamic> inserted =
            await _client.from('expenses').insert(payload).select('id').single();
        await _db.syncLinksDao.link('expenses', row.id, inserted['id'] as String);
      }
      count++;
    }
    return count;
  }

  Future<int> _pullExpenses(List<Map<String, dynamic>> remoteRows) async {
    int count = 0;
    for (final Map<String, dynamic> r in remoteRows) {
      final String remoteId = r['id'] as String;
      final int? categoryLocalId = r['category_id'] == null
          ? null
          : await _db.syncLinksDao
              .localIdFor('expense_categories', r['category_id'] as String);
      final int? txLocalId = r['transaction_id'] == null
          ? null
          : await _db.syncLinksDao
              .localIdFor('transactions', r['transaction_id'] as String);
      final DateTime remoteUpdatedAt = DateTime.parse(r['updated_at'] as String);
      final int? localId = await _db.syncLinksDao.localIdFor('expenses', remoteId);
      if (localId != null) {
        final ExpenseRow? local = await (_db.select(_db.expenses)
              ..where(($ExpensesTable t) => t.id.equals(localId)))
            .getSingleOrNull();
        if (local == null) continue;
        final DateTime localUpdatedAt = local.updatedAt ?? local.occurredAt;
        if (!remoteUpdatedAt.isAfter(localUpdatedAt)) continue;
        await (_db.update(_db.expenses)
              ..where(($ExpensesTable t) => t.id.equals(localId)))
            .write(ExpensesCompanion(
          title: Value<String>(r['title'] as String),
          amount: Value<double>((r['amount'] as num).toDouble()),
          categoryId: Value<int?>(categoryLocalId),
          transactionId: Value<int?>(txLocalId),
          occurredAt: Value<DateTime>(DateTime.parse(r['date_time'] as String)),
          note: Value<String?>(r['note'] as String?),
          updatedAt: Value<DateTime>(remoteUpdatedAt),
        ));
      } else {
        final int newId = await _db.into(_db.expenses).insert(
              ExpensesCompanion.insert(
                title: r['title'] as String,
                amount: (r['amount'] as num).toDouble(),
                occurredAt: DateTime.parse(r['date_time'] as String),
                categoryId: Value<int?>(categoryLocalId),
                transactionId: Value<int?>(txLocalId),
                note: Value<String?>(r['note'] as String?),
                updatedAt: Value<DateTime>(remoteUpdatedAt),
              ),
            );
        await _db.syncLinksDao.link('expenses', newId, remoteId);
      }
      count++;
    }
    return count;
  }

  // ---------------------------------------------------------------------
  // Deletes made directly on Supabase (outside the app) — detected by diffing
  // each table's remote rows against the local rows still linked to it.
  // ---------------------------------------------------------------------

  Future<int> _pullRemoteDeletes(
      Map<String, List<Map<String, dynamic>>> remoteRows) async {
    int count = 0;
    for (final String table in _tableOrder.reversed) {
      final Set<String> remoteIds = remoteRows[table]!
          .map((Map<String, dynamic> r) => r['id'] as String)
          .toSet();
      final List<SyncLinkRow> links = await _db.syncLinksDao.linksForTable(table);
      for (final SyncLinkRow link in links) {
        if (remoteIds.contains(link.remoteId)) continue;
        await _deleteLocalRow(table, link.localId);
        await _db.syncLinksDao.unlink(table, link.localId);
        count++;
      }
    }
    return count;
  }

  Future<void> _deleteLocalRow(String table, int localId) async {
    switch (table) {
      case 'suppliers':
        await (_db.delete(_db.suppliers)
              ..where(($SuppliersTable t) => t.id.equals(localId)))
            .go();
      case 'clients':
        await (_db.delete(_db.clients)
              ..where(($ClientsTable t) => t.id.equals(localId)))
            .go();
      case 'item_types':
        await (_db.delete(_db.itemTypes)
              ..where(($ItemTypesTable t) => t.id.equals(localId)))
            .go();
      case 'item_type_fields':
        await (_db.delete(_db.itemTypeFields)
              ..where(($ItemTypeFieldsTable t) => t.id.equals(localId)))
            .go();
      case 'items':
        await (_db.delete(_db.items)
              ..where(($ItemsTable t) => t.id.equals(localId)))
            .go();
      case 'expense_categories':
        await (_db.delete(_db.expenseCategories)
              ..where(($ExpenseCategoriesTable t) => t.id.equals(localId)))
            .go();
      case 'transactions':
        await (_db.delete(_db.transactions)
              ..where(($TransactionsTable t) => t.id.equals(localId)))
            .go();
      case 'transaction_items':
        await (_db.delete(_db.transactionItems)
              ..where(($TransactionItemsTable t) => t.id.equals(localId)))
            .go();
      case 'payments':
        await (_db.delete(_db.payments)
              ..where(($PaymentsTable t) => t.id.equals(localId)))
            .go();
      case 'refunds':
        await (_db.delete(_db.refunds)
              ..where(($RefundsTable t) => t.id.equals(localId)))
            .go();
      case 'refund_items':
        await (_db.delete(_db.refundItems)
              ..where(($RefundItemsTable t) => t.id.equals(localId)))
            .go();
      case 'expenses':
        await (_db.delete(_db.expenses)
              ..where(($ExpensesTable t) => t.id.equals(localId)))
            .go();
    }
  }

  // ---------------------------------------------------------------------
  // Deletes queued by a local delete (see SyncLinksDao.recordPendingDeleteIfLinked)
  // ---------------------------------------------------------------------

  Future<void> _processPendingDeletes() async {
    final List<PendingRemoteDeleteRow> pending =
        await _db.syncLinksDao.listPendingDeletes();
    for (final PendingRemoteDeleteRow row in pending) {
      try {
        await _client.from(row.localTable).delete().eq('id', row.remoteId);
      } on PostgrestException catch (e) {
        // A 404-equivalent (row already gone remotely) is fine to treat as
        // done; anything else is left queued for the next sync attempt.
        if (e.code != 'PGRST116') continue;
      }
      await _db.syncLinksDao.clearPendingDelete(row.id);
    }
  }

  /// Deletes every row from every synced Supabase table, then clears all
  /// local sync bookkeeping (links + queued deletes) so sync starts fresh
  /// afterward. Used by Settings' "إعادة تعيين النظام" once local data has
  /// already been wiped, now that the system is connected to Supabase —
  /// without this, a local reset would leave the old data still sitting on
  /// the shared database for every other device to keep seeing.
  Future<void> wipeRemoteData() async {
    // Children before parents, so foreign key constraints never block a
    // delete (mirrors the dependency order used everywhere else, reversed).
    final List<String> childFirst = _tableOrder.reversed.toList();
    for (final String table in childFirst) {
      // `.neq` on a column every row has, with a value no row can equal, is
      // the standard "delete every row" pattern for the Supabase client.
      await _client.from(table).delete().neq('id', '00000000-0000-0000-0000-000000000000');
    }
    await _db.syncLinksDao.clearAllSyncState();
  }
}
