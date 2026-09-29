# Phase 22 — Accounts Tab: Login, Register, User Action Log

[← Back to roadmap index](../FEATURES_ROADMAP.md)

> **Reverses prior scope, revised from an earlier "app-managed accounts" draft.** The app has
> never had user accounts — it is single-admin, offline, with no login screen. This phase adds
> real authenticated multi-user accounts so the admin can see who did what, once more than one
> person can use the system at once via [Phase 21](phase-21-supabase-cloud-sync.md). The first
> draft of this phase proposed the app hand-roll password storage in a Sheets-backed `users`
> table; since Phase 21 now uses **Supabase**, this revision uses **Supabase Auth** instead —
> real, audited authentication instead of home-grown password handling.

## Goal
Let each person who uses the system log in with their own account, register new accounts (admin-
approved before first use), and give the admin a per-user, per-action audit trail: who
created/edited/deleted which deal, payment, expense, car, etc., and when.

## Auth model: Supabase Auth
Supabase Auth is a built-in part of the same project Phase 21 already uses for data — no
separate service, no separate login to build:
- **Register** calls Supabase Auth's sign-up (email + password); Supabase handles password
  hashing, storage, and session tokens entirely — the app never stores or sees a password beyond
  the moment the user types it into the login/register form and hands it to the Supabase SDK.
- **Login** calls Supabase Auth's sign-in; a successful call returns a session (access + refresh
  token) that `supabase_flutter` persists securely and refreshes automatically.
- Supabase's `auth.users` table is the source of truth for "who can log in." A separate
  `profiles` table (below) holds the app-specific fields (display name, role, active/inactive)
  keyed by the same user id, since `auth.users` itself shouldn't be extended directly.
- This removes the entire "how do we safely hash and store passwords ourselves" problem the
  Sheets-backed draft carried — that risk no longer exists with this design.

## Depends on
Phase 21's Supabase project and sync engine — `updatedByUserId` columns added there reference
`auth.users(id)` directly.

## Schema deltas
New Postgres table `profiles` (mirrored locally as a read-mostly Drift table, synced like any
other Phase 21 table):
- `id UUID PRIMARY KEY REFERENCES auth.users(id)`, `displayName`, `role` (`admin` / `staff`),
  `isActive BOOLEAN NOT NULL DEFAULT false`, `createdAt`, `lastLoginAt`.
- A new sign-up gets `isActive = false` by default (a database trigger on `auth.users` insert can
  create the matching `profiles` row automatically) — self-registration should not silently grant
  access to shared business data; an admin must flip it to `true` from the Accounts tab.

New Postgres table `audit_log` (append-only, mirrored locally):
- `id UUID`, `userId UUID REFERENCES auth.users(id)`, `action` (`create` / `update` / `delete` /
  `close_deal` / `reopen_deal` / `login` / etc.), `entityType` (`deal` / `payment` / `expense` /
  `car` / ...), `entityId`, `summary` (short human-readable Arabic description, e.g. "عدّل صفقة
  رقم 12 — غيّر السعر من 500 إلى 600"), `createdAt`.

Every existing syncable table already gets `updated_by` from Phase 21 — `audit_log` is the
append-only, human-readable feed built from those writes, not a replacement for them.

## Security (Row Level Security policies)
- `profiles`: any authenticated user can read all rows (needed for the Accounts list and for
  showing "edited by X" elsewhere) but can only update their own `displayName`; only rows where
  the acting user's own `role = 'admin'` may update another user's `isActive`/`role`.
- `audit_log`: insert-only for authenticated users (via the sync engine, stamped with their own
  `userId` — never a spoofed one, enforced by an RLS policy comparing `userId` to
  `auth.uid()`); no update or delete allowed for anyone through the client (append-only by
  policy, not just by convention).
- A deactivated (`isActive = false`) user's Supabase Auth session should be checked on every
  sync/login attempt — a policy or a lightweight edge function denies data access once
  deactivated, even if their access token hasn't expired yet.

## State
- New `cubit/auth/auth_cubit.dart` — login/register/logout, current user (id, displayName, role,
  isActive), emits authenticated/unauthenticated/pendingApproval/loading/error states.
- New `provider/current_user_provider.dart` — the logged-in user's profile available app-wide
  (who is doing the current action, read by every cubit that needs to stamp `updatedByUserId` and
  by the audit-log writer).
- App start: `startApp()` (`lib/app.dart`) checks for a valid Supabase session before mounting
  the rest of the app; no session (or a session for a not-yet-approved/deactivated user) shows the
  login/pending screen instead of the deals/cars/expenses shell.

## DAO / repo
- `repos/auth_repo.dart` — wraps `supabase_flutter`'s `auth.signUp`, `auth.signInWithPassword`,
  `auth.signOut`, `auth.currentSession`, plus `profiles` reads/updates (`getProfile`,
  `setActive`, `setRole`).
- `daos/audit_log_dao.dart` (local mirror) / `repos/audit_log_repo.dart` — `append(entry)`,
  `getRecent({filters})` for the Accounts screen's activity view; appends go through Phase 21's
  same outbox/sync path as any other write.
- Every existing write path (`TransactionsDao`, `ExpensesDao`, `ItemsDao`, etc.) gains one
  `AuditLogRepo.append(...)` call inside the same local transaction as the data write it's
  logging, so an audit entry is never recorded for a write that didn't actually commit (and vice
  versa) — same atomicity discipline as every other invariant in this codebase.

## UI
- `view/features/auth_features/login_screen.dart` (new) — email + password, "دخول" primary
  action, link to register.
- `view/features/auth_features/register_screen.dart` (new) — calls Supabase sign-up, then shows
  "تم إنشاء الحساب — بانتظار موافقة المسؤول" (account created, awaiting admin approval) instead of
  logging the user straight in.
- `view/features/accounts_features/accounts_screen.dart` (new) — new side-nav tab "الحسابات"
  (admin-only): list of users (display name, email, role, active/inactive, last login), toggle
  active, change role, and a per-user or global activity feed built from `audit_log` (filterable
  by user/date/entity type), each entry showing its Arabic `summary`.
- Every screen that currently has no concept of "who", now implicitly stamps the acting user via
  `current_user_provider` — no per-screen UI change required beyond Accounts itself.
- A "تسجيل الخروج" (logout) action in the existing settings/side-nav area.

## Localization
New: تسجيل الدخول, البريد الإلكتروني, كلمة المرور, إنشاء حساب, تم إنشاء الحساب — بانتظار موافقة
المسؤول, الحسابات, سجل النشاط, نشط/غير نشط, تسجيل الخروج, دور المستخدم (مسؤول/موظف).

## Acceptance criteria
- [ ] No screen in the app is reachable before a successful login with an approved
      (`isActive = true`) account; app start with no valid session shows the login screen first.
- [ ] Registering a new account creates a `profiles` row with `isActive = false`; that account
      cannot use the app's data screens until an admin activates it from the Accounts tab.
- [ ] Every deal/payment/expense/car/refund create/edit/delete action produces exactly one
      matching `audit_log` row, alongside the same local transaction as the underlying write,
      with a human-readable Arabic summary and the correct acting user.
- [ ] The Accounts tab lists every user with an accurate active/inactive state and last-login
      time, and an admin can deactivate a user (blocking further access) without deleting their
      historical audit entries or past deals.
- [ ] No screen, log, or synced table ever exposes a plaintext password — Supabase Auth owns
      password storage entirely; the app never persists one beyond the in-memory moment of a
      login/register call.
- [ ] A deactivated user's already-synced past actions remain fully attributed and visible in the
      audit log, and their active session (if any) loses data access on their next sync/login
      check, not just on their next password entry.
- [ ] Every `profiles`/`audit_log` table has Row Level Security enabled matching the policies
      above; no unauthenticated request can read or write either table.

## Out of scope
- Fine-grained per-screen permissions beyond admin/staff (e.g. "can view expenses but not edit
  them") — a two-role model only, for this phase.
- Password reset via a custom flow — Supabase Auth's own built-in password-reset email flow can
  be used as-is if email sending is configured on the project; not re-implemented here.
- Multi-factor authentication.
