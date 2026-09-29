-- Phase 21 (Supabase shared database) + Phase 22 (Accounts/Auth) schema.
-- Mirrors lib/view_model/database/local/tables.dart, with local Drift
-- autoincrement ints replaced by UUID primary keys here (the "remoteId" the
-- local sync engine stores alongside each local row), and updated_at/
-- updated_by columns added for conflict detection and attribution.

-- ---------------------------------------------------------------------------
-- Phase 22: profiles + audit_log (depends on auth.users, created first)
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null,
  role text not null default 'staff' check (role in ('admin', 'staff')),
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  last_login_at timestamptz
);

comment on table public.profiles is
  'App-specific fields for a Supabase Auth user: role and admin-approval status. A new sign-up starts is_active = false until an admin approves it.';

-- Auto-create a profile row (inactive, staff) whenever someone signs up.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, role, is_active)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', new.email), 'staff', false);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

create table public.audit_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id),
  action text not null,
  entity_type text not null,
  entity_id text,
  summary text not null,
  created_at timestamptz not null default now()
);

comment on table public.audit_log is
  'Append-only action trail: who did what, when. Never updated or deleted through the client.';

-- ---------------------------------------------------------------------------
-- Phase 21: syncable business tables
-- ---------------------------------------------------------------------------

create table public.suppliers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id)
);

create table public.clients (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  passport_id text,
  national_id text,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id)
);

create table public.item_types (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id)
);

create table public.item_type_fields (
  id uuid primary key default gen_random_uuid(),
  item_type_id uuid not null references public.item_types (id) on delete cascade,
  field_name text not null,
  field_type text not null,
  is_required boolean not null default false,
  sort_order integer not null default 0,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id)
);

create table public.items (
  id uuid primary key default gen_random_uuid(),
  item_type_id uuid not null references public.item_types (id),
  supplier_id uuid not null references public.suppliers (id),
  label text not null,
  default_cost double precision,
  default_price double precision,
  expiry_date timestamptz,
  is_single_use boolean not null default false,
  is_available boolean not null default true,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id)
);

create table public.item_field_values (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.items (id) on delete cascade,
  field_id uuid not null references public.item_type_fields (id) on delete cascade,
  value text not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id),
  unique (item_id, field_id)
);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients (id),
  date_time timestamptz not null,
  deal_type text not null,
  subtotal double precision not null,
  discount double precision not null default 0,
  total double precision not null,
  total_cost double precision not null,
  status text not null,
  notes text,
  commission_name text,
  commission_amount double precision,
  payment_status_override text,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id)
);

create table public.transaction_items (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null references public.transactions (id) on delete cascade,
  item_id uuid not null references public.items (id),
  supplier_id uuid not null references public.suppliers (id),
  deal_type text not null,
  qty integer not null default 1,
  unit_cost double precision not null,
  unit_price double precision not null,
  line_total double precision not null,
  rent_start timestamptz,
  rent_end timestamptz,
  expiry_date timestamptz,
  notes text,
  price_per_day double precision,
  cost_per_day double precision,
  days integer,
  allowed_km_per_day double precision,
  extra_km_rate double precision,
  pickup_kilometer double precision,
  return_kilometer double precision,
  extra_km_charge double precision,
  line_status text not null default 'active',
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id)
);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null references public.transactions (id) on delete cascade,
  party text not null,
  supplier_id uuid references public.suppliers (id),
  method text not null,
  amount double precision not null,
  date_time timestamptz not null,
  notes text,
  transaction_item_id uuid references public.transaction_items (id) on delete cascade,
  rental_day_date timestamptz,
  voided boolean not null default false,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id)
);

create table public.refunds (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null references public.transactions (id) on delete cascade,
  date_time timestamptz not null,
  total_refunded double precision not null,
  total_cost_refunded double precision not null,
  reason text,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id)
);

create table public.refund_items (
  id uuid primary key default gen_random_uuid(),
  refund_id uuid not null references public.refunds (id) on delete cascade,
  transaction_item_id uuid not null references public.transaction_items (id) on delete cascade,
  item_id uuid not null references public.items (id),
  qty integer not null,
  unit_cost double precision not null,
  unit_price double precision not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id)
);

create table public.expense_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id)
);

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  amount double precision not null,
  category_id uuid references public.expense_categories (id) on delete set null,
  transaction_id uuid references public.transactions (id) on delete cascade,
  date_time timestamptz not null,
  note text,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id)
);

-- ---------------------------------------------------------------------------
-- updated_at auto-touch trigger, applied to every syncable table
-- ---------------------------------------------------------------------------

create function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'suppliers', 'clients', 'item_types', 'item_type_fields', 'items',
    'item_field_values', 'transactions', 'transaction_items', 'payments',
    'refunds', 'refund_items', 'expense_categories', 'expenses'
  ]
  loop
    execute format(
      'create trigger touch_updated_at before update on public.%I for each row execute procedure public.touch_updated_at();',
      t
    );
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Row Level Security: enabled on every table, authenticated-only access.
-- Two-role split (admin vs staff) is intentionally not enforced at the row
-- level yet, per Phase 22's "out of scope" — every signed-in, approved user
-- has full read/write on business tables for now.
-- ---------------------------------------------------------------------------

do $$
declare
  t text;
begin
  foreach t in array array[
    'suppliers', 'clients', 'item_types', 'item_type_fields', 'items',
    'item_field_values', 'transactions', 'transaction_items', 'payments',
    'refunds', 'refund_items', 'expense_categories', 'expenses'
  ]
  loop
    execute format('alter table public.%I enable row level security;', t);
    execute format(
      'create policy "authenticated read" on public.%I for select to authenticated using (true);',
      t
    );
    execute format(
      'create policy "authenticated write" on public.%I for insert to authenticated with check (true);',
      t
    );
    execute format(
      'create policy "authenticated update" on public.%I for update to authenticated using (true) with check (true);',
      t
    );
    execute format(
      'create policy "authenticated delete" on public.%I for delete to authenticated using (true);',
      t
    );
  end loop;
end $$;

-- profiles: everyone authenticated can read (needed for "edited by X" and the
-- Accounts list); a user can only update their own display_name; only an
-- admin can change is_active/role (including their own — checked via a
-- second policy so a non-admin's update of other columns still works).
alter table public.profiles enable row level security;

create policy "authenticated read profiles"
  on public.profiles for select to authenticated using (true);

create policy "self update own display name"
  on public.profiles for update to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

create policy "admin manage any profile"
  on public.profiles for update to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin' and p.is_active))
  with check (true);

-- audit_log: insert-only, and only stamped as yourself; no update/delete from
-- the client at all (append-only by policy, not just convention).
alter table public.audit_log enable row level security;

create policy "authenticated read audit_log"
  on public.audit_log for select to authenticated using (true);

create policy "insert own audit_log entries"
  on public.audit_log for insert to authenticated
  with check (auth.uid() = user_id);
