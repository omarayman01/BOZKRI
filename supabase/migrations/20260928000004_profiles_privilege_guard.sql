-- RLS policies only filter which ROWS are visible/writable, not which
-- COLUMNS — the "self update own display name" policy technically lets a
-- non-admin's update touch role/is_active on their own row too, since
-- Postgres RLS has no column-level concept. Close that with a trigger: any
-- change to role or is_active must be made by a currently-active admin,
-- regardless of which row it targets (including their own).

create function public.guard_profile_privilege_columns()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  acting_is_admin boolean;
begin
  if new.role is distinct from old.role or new.is_active is distinct from old.is_active then
    select (role = 'admin' and is_active) into acting_is_admin
    from public.profiles where id = auth.uid();

    if not coalesce(acting_is_admin, false) then
      raise exception 'Only an active admin may change role or is_active';
    end if;
  end if;
  return new;
end;
$$;

create trigger guard_profile_privilege_columns
  before update on public.profiles
  for each row execute procedure public.guard_profile_privilege_columns();
