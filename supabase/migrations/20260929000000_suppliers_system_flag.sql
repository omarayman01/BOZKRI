-- Mirrors the local "بوزكري (بدون مورد)" system-supplier flag, so a pulled
-- copy of it on another device is still recognized as protected (never
-- deletable/renamable), not just a normal supplier row.
alter table public.suppliers add column is_system_supplier boolean not null default false;
