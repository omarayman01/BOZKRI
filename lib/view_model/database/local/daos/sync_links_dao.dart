import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'sync_links_dao.g.dart';

/// Local-only local-id ↔ Supabase-row-id mapping, one row per synced entity
/// (Phase 21). Never mirrored to Supabase itself.
@DriftAccessor(tables: <Type>[SyncLinks, PendingRemoteDeletes])
class SyncLinksDao extends DatabaseAccessor<AppDatabase>
    with _$SyncLinksDaoMixin {
  SyncLinksDao(super.db);

  Future<String?> remoteIdFor(String table, int localId) async {
    final SyncLinkRow? row = await (select(syncLinks)
          ..where(($SyncLinksTable t) =>
              t.localTable.equals(table) & t.localId.equals(localId)))
        .getSingleOrNull();
    return row?.remoteId;
  }

  Future<int?> localIdFor(String table, String remoteId) async {
    final SyncLinkRow? row = await (select(syncLinks)
          ..where(($SyncLinksTable t) =>
              t.localTable.equals(table) & t.remoteId.equals(remoteId)))
        .getSingleOrNull();
    return row?.localId;
  }

  Future<void> link(String table, int localId, String remoteId) async {
    await into(syncLinks).insertOnConflictUpdate(
      SyncLinksCompanion.insert(
        localTable: table,
        localId: localId,
        remoteId: remoteId,
      ),
    );
  }

  /// Every link recorded for [table], so a pull can tell which locally-known
  /// rows have a remote counterpart still worth checking for deletion.
  Future<List<SyncLinkRow>> linksForTable(String table) =>
      (select(syncLinks)..where(($SyncLinksTable t) => t.localTable.equals(table)))
          .get();

  /// Drops the link row itself, without touching the local data row. Used
  /// after a row that was deleted straight in Supabase (outside the app) has
  /// had its local counterpart removed too, so the bookkeeping doesn't keep
  /// pointing at a remote id that no longer exists.
  Future<void> unlink(String table, int localId) =>
      (delete(syncLinks)
            ..where(($SyncLinksTable t) =>
                t.localTable.equals(table) & t.localId.equals(localId)))
          .go();

  /// Called right before a local row is deleted, so its Supabase counterpart
  /// (if it was ever synced) gets removed on the next sync too — otherwise a
  /// deleted-locally row would silently live forever on the shared database.
  /// A no-op if the row was never synced (nothing to delete remotely).
  Future<void> recordPendingDeleteIfLinked(String table, int localId) async {
    final String? remoteId = await remoteIdFor(table, localId);
    if (remoteId == null) return;
    await into(pendingRemoteDeletes).insert(
      PendingRemoteDeletesCompanion.insert(localTable: table, remoteId: remoteId),
    );
  }

  Future<List<PendingRemoteDeleteRow>> listPendingDeletes() =>
      select(pendingRemoteDeletes).get();

  Future<void> clearPendingDelete(int id) =>
      (delete(pendingRemoteDeletes)
            ..where(($PendingRemoteDeletesTable t) => t.id.equals(id)))
          .go();

  /// Drops every sync bookkeeping row (links + queued deletes) — used by
  /// "إعادة تعيين النظام" once the remote data itself has been wiped, so a
  /// reset starts every table's sync state completely fresh.
  Future<void> clearAllSyncState() async {
    await delete(syncLinks).go();
    await delete(pendingRemoteDeletes).go();
  }
}
