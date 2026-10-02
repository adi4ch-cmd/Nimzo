-- Profile setup fields required by the locked Edit Profile flow.
alter table public.profiles
  add column if not exists country_code text,
  add column if not exists country_name text,
  add column if not exists language text default 'English',
  add column if not exists gender text,
  add column if not exists date_of_birth date;

update public.profiles
set language = 'English'
where language is null;

notify pgrst, 'reload schema';
