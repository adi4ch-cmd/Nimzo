-- Backend continuation (2026-10-18): make every family founder an actual family member.
-- Additive only: never delete or reset families, users, wallet balances or history.
-- The existing private create_family RPC remains the sole 1,000,000-coin charge path.
create or replace function nimzo_private.ensure_family_founder_member()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.nimzo_family_members(family_id, user_id)
  values (new.id, new.owner_id)
  on conflict (family_id, user_id) do nothing;
  return new;
end;
$$;

revoke all on function nimzo_private.ensure_family_founder_member() from public, anon, authenticated;

drop trigger if exists nimzo_family_founder_member_after_insert on public.nimzo_families;
create trigger nimzo_family_founder_member_after_insert
  after insert on public.nimzo_families
  for each row execute function nimzo_private.ensure_family_founder_member();

-- Repair membership omissions without changing ownership or existing members.
insert into public.nimzo_family_members(family_id, user_id)
select f.id, f.owner_id from public.nimzo_families f
on conflict (family_id, user_id) do nothing;

create index if not exists nimzo_family_members_user_idx
on public.nimzo_family_members(user_id, joined_at desc);
