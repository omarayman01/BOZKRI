-- One-time bootstrap: promote the first admin account (created via sign-up)
-- to role = 'admin', is_active = true, so someone can approve everyone else
-- from the Accounts tab. Matched by email via auth.users, not a hardcoded id.
update public.profiles p
set role = 'admin', is_active = true
from auth.users u
where p.id = u.id
  and u.email = 'admin@bozkri.com';
