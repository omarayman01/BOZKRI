-- "Automatically expose new tables" was left off (by design), so the API
-- roles have no privileges on these tables yet — RLS policies only filter
-- rows, they don't grant access at all without this. Grant the authenticated
-- role (signed-in Supabase Auth users) exactly what Phase 21/22 needs; the
-- anon role gets nothing, since every business table requires login.

grant usage on schema public to authenticated;

grant select, insert, update, delete on
  public.suppliers,
  public.clients,
  public.item_types,
  public.item_type_fields,
  public.items,
  public.item_field_values,
  public.transactions,
  public.transaction_items,
  public.payments,
  public.refunds,
  public.refund_items,
  public.expense_categories,
  public.expenses
to authenticated;

-- profiles: select granted broadly (RLS still restricts row visibility to
-- "all authenticated" per policy); update/insert handled by the app via
-- Supabase Auth (the on_auth_user_created trigger inserts, not the client).
grant select, update on public.profiles to authenticated;

-- audit_log: insert + select only, no update/delete grant at all (append-only
-- enforced at the privilege level, not just by RLS policy).
grant select, insert on public.audit_log to authenticated;
