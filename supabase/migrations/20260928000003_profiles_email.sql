-- The client can only ever read its OWN row from auth.users (never other
-- users'), but the Accounts tab needs to list every user's email. Denormalize
-- email onto profiles (kept in sync at signup time; email changes are rare
-- enough for an internal tool that this isn't kept live-synced afterward).

alter table public.profiles add column email text not null default '';

update public.profiles p
set email = u.email
from auth.users u
where p.id = u.id;

alter table public.profiles alter column email drop default;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name, role, is_active)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'display_name', new.email),
    'staff',
    false
  );
  return new;
end;
$$;
