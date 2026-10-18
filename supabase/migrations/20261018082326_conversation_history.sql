-- Bound chat reads to one participant pair without changing message RLS.
alter table public.messages add column conversation_key text generated always as (
 least(sender_id,receiver_id)::text || ':' || greatest(sender_id,receiver_id)::text
) stored;
create index messages_conversation_history on public.messages(conversation_key,created_at desc,id desc);
grant select(conversation_key) on public.messages to authenticated;
notify pgrst,'reload schema';
