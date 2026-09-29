import 'package:drift/drift.dart';

// ---------------------------------------------------------------------------
// Parties
// ---------------------------------------------------------------------------

@DataClassName('SupplierRow')
class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 160)();
  TextColumn get phone => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant<bool>(true))();
  DateTimeColumn get createdAt => dateTime()();

  /// Bumped on every write; the Phase 21 sync engine uses it for
  /// last-write-wins conflict resolution against the Supabase copy.
  DateTimeColumn get updatedAt =>
      dateTime().nullable().clientDefault(() => DateTime.now())();

  /// True only for the single seeded "بوزكري (بدون مورد)" row — the
  /// placeholder supplier a car is assigned to when it has no real
  /// supplier. Never admin-created, renamed, or deleted.
  BoolColumn get isSystemSupplier =>
      boolean().withDefault(const Constant<bool>(false))();
}

@DataClassName('ClientRow')
class Clients extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 160)();
  TextColumn get phone => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant<bool>(true))();
  DateTimeColumn get createdAt => dateTime()();

  /// Optional identity documents, for identification and search only — no
  /// format validation, no uniqueness constraint.
  TextColumn get passportId => text().nullable()();
  TextColumn get nationalId => text().nullable()();

  DateTimeColumn get updatedAt =>
      dateTime().nullable().clientDefault(() => DateTime.now())();
}

// ---------------------------------------------------------------------------
// Dynamic item schema
// ---------------------------------------------------------------------------

@DataClassName('ItemTypeRow')
class ItemTypes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt =>
      dateTime().nullable().clientDefault(() => DateTime.now())();

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
        <Column<Object>>{name},
      ];
}

/// `fieldType` holds a [FieldType] name: text | number | date | bool.
@DataClassName('ItemTypeFieldRow')
class ItemTypeFields extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get itemTypeId => integer()
      .references(ItemTypes, #id, onDelete: KeyAction.cascade)();
  TextColumn get fieldName => text().withLength(min: 1, max: 120)();
  TextColumn get fieldType => text().withLength(min: 1, max: 16)();
  BoolColumn get isRequired =>
      boolean().withDefault(const Constant<bool>(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant<int>(0))();
  DateTimeColumn get updatedAt =>
      dateTime().nullable().clientDefault(() => DateTime.now())();
}

@DataClassName('ItemRow')
class Items extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get itemTypeId => integer().references(ItemTypes, #id)();
  IntColumn get supplierId => integer().references(Suppliers, #id)();
  TextColumn get label => text().withLength(min: 1, max: 200)();
  RealColumn get defaultCost => real().nullable()();
  RealColumn get defaultPrice => real().nullable()();
  DateTimeColumn get expiryDate => dateTime().nullable()();

  /// false = reusable template (never depletes). true = consumable one-time.
  BoolColumn get isSingleUse =>
      boolean().withDefault(const Constant<bool>(false))();

  /// Enforced only when [isSingleUse] is true; ignored for reusable items.
  BoolColumn get isAvailable =>
      boolean().withDefault(const Constant<bool>(true))();

  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant<bool>(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt =>
      dateTime().nullable().clientDefault(() => DateTime.now())();
}

/// One value per (item, field). Stored as text, interpreted by the field type.
@DataClassName('ItemFieldValueRow')
class ItemFieldValues extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get itemId =>
      integer().references(Items, #id, onDelete: KeyAction.cascade)();
  IntColumn get fieldId =>
      integer().references(ItemTypeFields, #id, onDelete: KeyAction.cascade)();
  TextColumn get value => text()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
        <Column<Object>>{itemId, fieldId},
      ];
}

// ---------------------------------------------------------------------------
// Deals
// ---------------------------------------------------------------------------

@DataClassName('TransactionRow')
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clientId => integer().references(Clients, #id)();
  /// Named `occurredAt` in Dart because a getter called `dateTime` would
  /// shadow drift's own `dateTime()` column builder. The SQL column keeps
  /// the name `date_time`.
  DateTimeColumn get occurredAt => dateTime().named('date_time')();
  TextColumn get dealType => text().withLength(min: 1, max: 16)();
  RealColumn get subtotal => real()();
  RealColumn get discount => real().withDefault(const Constant<double>(0))();
  RealColumn get total => real()();
  RealColumn get totalCost => real()();
  TextColumn get status => text().withLength(min: 1, max: 24)();
  TextColumn get notes => text().nullable()();

  /// Optional commission, mirrored into a linked expense so it reaches net
  /// profit through the existing expense aggregate rather than its own path.
  TextColumn get commissionName => text().nullable()();
  RealColumn get commissionAmount => real().nullable()();

  /// null = use the derived status; else 'paid'/'unpaid', for DISPLAY only —
  /// every money computation always uses actual payments.
  TextColumn get paymentStatusOverride => text().nullable()();

  DateTimeColumn get updatedAt =>
      dateTime().nullable().clientDefault(() => DateTime.now())();
}

/// unitCost / unitPrice are immutable snapshots captured at deal time.
/// Analytics must never join live item prices.
@DataClassName('TransactionItemRow')
class TransactionItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId => integer()
      .references(Transactions, #id, onDelete: KeyAction.cascade)();
  IntColumn get itemId => integer().references(Items, #id)();
  IntColumn get supplierId => integer().references(Suppliers, #id)();
  TextColumn get dealType => text().withLength(min: 1, max: 16)();
  IntColumn get qty => integer().withDefault(const Constant<int>(1))();
  RealColumn get unitCost => real()();
  RealColumn get unitPrice => real()();
  RealColumn get lineTotal => real()();
  DateTimeColumn get rentStart => dateTime().nullable()();
  DateTimeColumn get rentEnd => dateTime().nullable()();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  TextColumn get notes => text().nullable()();

  /// Per-day pricing (cars): when set, unitPrice/unitCost/qty above are kept
  /// equal to pricePerDay/costPerDay/days so every existing lineTotal/
  /// lineCost computation keeps working unchanged. These three columns exist
  /// only so the UI can show and edit "price per day" and "days" as their own
  /// concept instead of the generic qty/unit labels. Null for flat-priced
  /// lines (apartments, flights).
  RealColumn get pricePerDay => real().nullable()();
  RealColumn get costPerDay => real().nullable()();
  IntColumn get days => integer().nullable()();

  /// Car kilometer parameters and return settlement. `extraKmCharge` is a
  /// settlement snapshot, fixed once at return time — like unitCost/
  /// unitPrice, it must never be recomputed from a later `extraKmRate`.
  RealColumn get allowedKmPerDay => real().nullable()();
  RealColumn get extraKmRate => real().nullable()();
  RealColumn get pickupKilometer => real().nullable()();
  RealColumn get returnKilometer => real().nullable()();
  RealColumn get extraKmCharge => real().nullable()();

  /// 'active' | 'returned' (حالة العقد ساري / غير ساري).
  TextColumn get lineStatus =>
      text().withLength(min: 1, max: 16).withDefault(const Constant<String>('active'))();

  DateTimeColumn get updatedAt =>
      dateTime().nullable().clientDefault(() => DateTime.now())();
}

@DataClassName('PaymentRow')
class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId => integer()
      .references(Transactions, #id, onDelete: KeyAction.cascade)();
  TextColumn get party => text().withLength(min: 1, max: 16)();

  /// Required when party = supplier so multi-supplier deals attribute
  /// payments to the correct payable.
  IntColumn get supplierId => integer().nullable().references(Suppliers, #id)();
  TextColumn get method => text().withLength(min: 1, max: 24)();
  RealColumn get amount => real()();
  /// Named `occurredAt` in Dart because a getter called `dateTime` would
  /// shadow drift's own `dateTime()` column builder. The SQL column keeps
  /// the name `date_time`.
  DateTimeColumn get occurredAt => dateTime().named('date_time')();
  TextColumn get notes => text().nullable()();

  /// Set only for a per-day rental payment: which line and which rental day
  /// it settles. One payment row per paid day; unpaid days simply have no
  /// matching row here.
  IntColumn get transactionItemId => integer()
      .nullable()
      .references(TransactionItems, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get rentalDayDate => dateTime().nullable()();

  /// Undo/refund of this payment. Voided rows are never deleted — they stay
  /// visible in the payment history — but are excluded from every
  /// paid/owed sum, so the balance derivation reflects the reversal.
  BoolColumn get voided =>
      boolean().withDefault(const Constant<bool>(false))();

  DateTimeColumn get updatedAt =>
      dateTime().nullable().clientDefault(() => DateTime.now())();
}

@DataClassName('RefundRow')
class Refunds extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId => integer()
      .references(Transactions, #id, onDelete: KeyAction.cascade)();
  /// Named `occurredAt` in Dart because a getter called `dateTime` would
  /// shadow drift's own `dateTime()` column builder. The SQL column keeps
  /// the name `date_time`.
  DateTimeColumn get occurredAt => dateTime().named('date_time')();
  RealColumn get totalRefunded => real()();
  RealColumn get totalCostRefunded => real()();
  TextColumn get reason => text().nullable()();

  DateTimeColumn get updatedAt =>
      dateTime().nullable().clientDefault(() => DateTime.now())();
}

@DataClassName('RefundItemRow')
class RefundItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get refundId =>
      integer().references(Refunds, #id, onDelete: KeyAction.cascade)();
  IntColumn get transactionItemId => integer()
      .references(TransactionItems, #id, onDelete: KeyAction.cascade)();
  IntColumn get itemId => integer().references(Items, #id)();
  IntColumn get qty => integer()();
  RealColumn get unitCost => real()();
  RealColumn get unitPrice => real()();

  DateTimeColumn get updatedAt =>
      dateTime().nullable().clientDefault(() => DateTime.now())();
}

// ---------------------------------------------------------------------------
// Expenses
// ---------------------------------------------------------------------------

@DataClassName('ExpenseCategoryRow')
class ExpenseCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  DateTimeColumn get updatedAt =>
      dateTime().nullable().clientDefault(() => DateTime.now())();

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
        <Column<Object>>{name},
      ];
}

@DataClassName('ExpenseRow')
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  RealColumn get amount => real()();
  IntColumn get categoryId => integer()
      .nullable()
      .references(ExpenseCategories, #id, onDelete: KeyAction.setNull)();
  IntColumn get transactionId => integer()
      .nullable()
      .references(Transactions, #id, onDelete: KeyAction.cascade)();
  /// Named `occurredAt` in Dart because a getter called `dateTime` would
  /// shadow drift's own `dateTime()` column builder. The SQL column keeps
  /// the name `date_time`.
  DateTimeColumn get occurredAt => dateTime().named('date_time')();
  TextColumn get note => text().nullable()();
  DateTimeColumn get updatedAt =>
      dateTime().nullable().clientDefault(() => DateTime.now())();
}

// ---------------------------------------------------------------------------
// Phase 21: online sync bookkeeping (local-only, never mirrored to Supabase)
// ---------------------------------------------------------------------------

/// Maps a local row to its Supabase row, per synced table. Kept separate
/// from the business tables so pushing/pulling never has to touch (or risk
/// clobbering via `update(...).replace(...)`) the entity tables' own shape.
@DataClassName('SyncLinkRow')
class SyncLinks extends Table {
  TextColumn get localTable => text()();
  IntColumn get localId => integer()();
  TextColumn get remoteId => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{localTable, localId};

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
        <Column<Object>>{localTable, remoteId},
      ];
}

/// A local row was deleted before its Supabase counterpart could be — queued
/// here so the next sync actually deletes it remotely too, instead of the
/// deleted row silently surviving forever on the shared database.
@DataClassName('PendingRemoteDeleteRow')
class PendingRemoteDeletes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get localTable => text()();
  TextColumn get remoteId => text()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
}
