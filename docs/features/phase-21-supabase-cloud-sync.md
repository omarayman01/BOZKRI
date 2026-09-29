# Phase 21 — Supabase as Shared Online Database + Offline Badge

[← Back to roadmap index](../FEATURES_ROADMAP.md)

> **Reverses prior scope, revised from an earlier Google Sheets draft.** Every earlier phase and
> this roadmap's own "Out of scope" section stated the app is permanently offline-only,
> single-device, with any online/cloud sync explicitly excluded. This phase reverses that: the
> admin wants multiple users/machines to share one live dataset. The first draft of this phase
> used Google Sheets as the shared store; after reviewing Sheets' lack of transactions, quotas,
> and cell-count ceiling, **the admin chose Supabase (hosted Postgres + built-in Auth) instead**,
> free-tier, no credit card required. This revision replaces Sheets with Supabase throughout.

## Goal
Make the system usable by several users on different machines against one shared dataset, using
a free Supabase Postgres project as the online database, while keeping the app usable when the
internet drops (queue changes locally, warn the user, sync when back online).

## Why Supabase instead of Sheets
Supabase is a real Postgres database, not a spreadsheet, so it removes almost every risk the
Sheets draft carried:
- **Real transactions.** This app's entire money-safety model (README's "Invariants worth
  knowing": a deal + its payments + its supplier cost commit or roll back together) maps
  directly onto a Postgres transaction — no client-side workaround needed the way Sheets would
  have required.
- **Real concurrency control.** Postgres row-level locking and `updated_at`/version-column
  optimistic-concurrency checks (below) mean two admins editing the same row is detected and
  handled at the database level, not bolted on afterward.
- **Enforced schema, foreign keys, constraints** — the same integrity guarantees SQLite already
  gives the app locally carry over to the shared store, instead of being re-implemented in app
  code the way they would have been against Sheets.
- **Built-in Auth** — solves Phase 22's login/register requirement with proper, audited password
  handling (bcrypt hashing, session tokens, email confirmation if wanted) instead of the app
  hand-rolling password storage.
- **Free tier is generous for this app's scale**: 500MB database storage, 5GB bandwidth/month, no
  card required. The one operational quirk: a free-tier project **pauses after 7 days with zero
  activity** (data is preserved, not deleted; an admin clicks "Restore" in the Supabase dashboard
  to resume, taking about a minute) — irrelevant for daily use, worth knowing about after a long
  office closure. See the acceptance criteria below for how the app should behave if this happens
  mid-use.

The core architecture below is otherwise the same shape as the original Sheets draft: **SQLite
remains the only thing the UI ever reads or writes**, and Supabase is a remote store a background
sync layer pushes to and pulls from. This preserves every existing atomicity/derived-balance
invariant unchanged and is what keeps the offline mode (also requested) working at all — even
though Supabase could technically be read/written directly and live (it supports realtime
subscriptions), going through the local cache keeps this app fast and fully usable offline, which
a direct-connection design would not.

## Depends on
Phase 22 (Accounts) should land alongside or before this phase in practice, since Supabase Auth
*is* the account system this phase's `updatedByUserId` columns need. Independent of Phases 1–20's
Arabic/UX work.

## Setup (one-time, admin)
1. Create a free Supabase project at supabase.com (email sign-up, no card).
2. Note the project's URL and anon/public API key (used by the Flutter app via the
   `supabase_flutter` package) and the service-role key (used only for admin scripts/migrations,
   never bundled in the app).
3. Define the schema below via Supabase's SQL editor or migrations.
4. Enable Row Level Security (RLS) on every table (default-deny, explicit policies — see Security
   below) — this is a Postgres/Supabase feature Sheets had no equivalent of at all.

## Schema deltas
On every syncable local Drift table (`clients`, `suppliers`, `items`, `item_types`,
`item_type_fields`, `item_field_values`, `transactions`, `transaction_items`, `payments`,
`refunds`, `refund_items`, `expenses`) — mirrored by an identically-shaped Postgres table in
Supabase:
- `remoteId TEXT NULL` (Postgres: `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`) — the stable
  shared-row id, separate from the local Drift autoincrement `id`, so local ids never collide
  across devices.
- `updatedAt DATETIME NOT NULL` (Postgres: `updated_at TIMESTAMPTZ NOT NULL DEFAULT now()`,
  bumped by a trigger on every row update) — drives both "last write wins with a warning"
  conflict resolution and incremental pull (only rows newer than the last successful sync are
  fetched).
- `updatedByUserId INTEGER NULL` (Postgres: `updated_by UUID REFERENCES auth.users(id)`) — who
  made the change, using Supabase Auth's own user id (ties directly into Phase 22, no separate
  local `users` table needed for identity — Supabase Auth already owns that).
- `syncStatus TEXT NOT NULL DEFAULT 'pending'` — local-only column; `pending` / `synced` /
  `conflict`; drives what the outbox still needs to push and what the UI should flag.

New local-only tables (Drift, not mirrored to Supabase):
- `sync_outbox` — one row per pending local mutation not yet confirmed pushed (table name, row
  id, operation, payload snapshot, createdAt) — the durable queue that survives an app restart
  while offline.
- `sync_state` — one row: `lastPulledAt`, `lastPushedAt`, `isOnline` (last known connectivity),
  `lastError`.

`schemaVersion` bumps accordingly with a matching `onUpgrade` step, per the existing pattern in
COMMANDS.md's "Schema version note".

## Security (Row Level Security policies)
Every Supabase table gets RLS enabled with explicit policies rather than being left open:
- `select`/`insert`/`update`/`delete` allowed only for `authenticated` Supabase users (no
  anonymous access at all) — ties directly to Phase 22's login requirement.
- Optionally, once Phase 22's roles exist, a `staff` role can be restricted from `delete` on
  sensitive tables (e.g. `expenses`, `payments`) while `admin` has full access — a real
  Postgres-enforced permission, not just a hidden UI button, which Sheets could never offer.

## State
- New `cubit/sync/sync_cubit.dart` — owns connectivity state, pending-outbox count, last sync
  time/error; emits the state the offline badge and a "آخر مزامنة" (last synced) indicator read.
- New `provider/connectivity_provider.dart` (e.g. via the `connectivity_plus` package) — watches
  actual network reachability, not just "has Wi-Fi" (a captive portal or a Supabase outage should
  also show offline), by periodically pinging the Supabase project's own health endpoint.
- Every existing cubit's write methods are unchanged in shape (still call the repo, still one
  Drift transaction) — a repo-level decorator/wrapper enqueues a `sync_outbox` row inside the
  same local transaction as the write, so the local write and the "needs sync" marker are never
  inconsistent with each other.

## Sync engine (new: `view_model/sync/`)
- `SupabaseClientWrapper` — thin wrapper over the `supabase_flutter` package's Postgrest client,
  holding the current authenticated session (from Phase 22).
- `SyncEngine.pushPending()` — drains `sync_outbox` in order, one Postgres `upsert` per row
  (batched where the table allows it), marking each row `synced` and clearing its outbox entry
  only after a confirmed response; a failure (including a lost connection mid-push) leaves it
  `pending` for the next attempt, never drops it.
- `SyncEngine.pullRemote()` — reads rows with `updated_at` after `sync_state.lastPulledAt` from
  each table (optionally via Supabase's **realtime subscriptions**, so other users' changes can
  arrive as push events while the app is online, instead of only on a timer — a genuine
  capability Sheets never offered), upserts into local SQLite by `remoteId`. A row whose local
  `updatedAt` is newer than the incoming remote row **and** whose local copy is still `pending`
  is a conflict: the incoming write is not applied automatically — it is written to a small
  `sync_conflicts` table and surfaced to the user (a toast/badge + a "تعارضات المزامنة" screen:
  the user manually picks local or remote per conflicting field), never silently overwritten.
- Runs: on app start (pull), on every local write (best-effort immediate push, falling back to
  the outbox if offline), continuously via realtime subscription while online, and as a periodic
  fallback poll (e.g. every 60s) in case a realtime event is missed.
- If a push/pull fails specifically because the Supabase project is **paused** (the 7-day free-
  tier inactivity pause), the badge shows a distinct message telling the admin to open the
  Supabase dashboard and click Restore, rather than the generic "sync error" — this is the one
  operational quirk of the free tier worth surfacing clearly instead of leaving as an unexplained
  failure.

## UI
- A persistent small badge in the app's top bar / side rail: green "متصل" (online, synced) /
  gray-yellow "غير متصل بالإنترنت — التغييرات محفوظة محلياً وستتم المزامنة عند الاتصال" (offline
  — changes saved locally, will sync when back online) / orange "قاعدة البيانات متوقفة مؤقتاً —
  يرجى إعادة تفعيلها من لوحة Supabase" (project paused, needs a dashboard restore) / red "خطأ في
  المزامنة" with a retry action, plus a small pending-changes counter when nonzero.
- A "تعارضات المزامنة" (sync conflicts) screen, reachable from the badge, listing any row where
  local and remote diverged, letting the user resolve each one.
- Settings gains a "حالة المزامنة" section: last synced time, force-sync-now button, and (admin
  only) the connected Supabase project's status.

## Localization
New: متصل, غير متصل بالإنترنت, التغييرات محفوظة محلياً وستتم المزامنة عند الاتصال, قاعدة البيانات
متوقفة مؤقتاً, خطأ في المزامنة, إعادة المحاولة, تعارضات المزامنة, آخر مزامنة, مزامنة الآن.

## Acceptance criteria
- [ ] Every screen keeps reading/writing local SQLite only — no UI code makes a direct Supabase
      call; sync is entirely a background concern.
- [ ] Turning off the network mid-session: every existing feature (deals, payments, expenses,
      cars) continues to work exactly as it does today, writes to `sync_outbox`, and the badge
      turns to "offline" within one connectivity-check interval.
- [ ] Restoring the network: all queued outbox rows push automatically, in original order, with
      no duplicate rows created remotely (idempotent by `remoteId`), and the badge returns to
      "online, synced" once the queue drains.
- [ ] Two machines editing different rows concurrently both end up with both changes present
      after both sync.
- [ ] Two machines editing the *same* row concurrently never silently lose one side's edit — the
      conflict is surfaced for manual resolution.
- [ ] No money-mutation atomicity guarantee already in place (README's "Invariants worth
      knowing") is weakened: a deal + its payments still commit or roll back together locally,
      and are pushed to Supabase as a unit (a single upsert transaction) or not at all.
- [ ] A fresh install with no local data, pointed at an existing Supabase project, ends up with a
      full local copy of every row after its first pull.
- [ ] If the Supabase project is paused, the app shows the specific "database paused" message
      (not a generic error) and continues working fully offline until someone restores it.
- [ ] Every table has Row Level Security enabled; no table is readable or writable by an
      unauthenticated request.

## Out of scope
- Real-time collaborative editing within the same screen (e.g. two admins on the exact same open
  deal form at once) — conflicts are resolved on sync, not live-merged field-by-field.
- Migrating away from SQLite as the local store — it remains the only thing the UI touches.
- Upgrading to a paid Supabase plan — this phase targets the free tier; revisit if usage ever
  approaches its storage/bandwidth limits (visible in the Supabase dashboard well before a hard
  failure).
