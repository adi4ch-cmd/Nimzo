-- pg_net creates transport tables with PUBLIC privileges on this project.
-- Keep signed request headers and responses internal to trusted backend roles.
revoke all on net.http_request_queue,net._http_response from public,anon,authenticated;
grant all on net.http_request_queue,net._http_response to postgres,service_role;
revoke all on all sequences in schema net from public,anon,authenticated;
grant usage,select on all sequences in schema net to postgres,service_role;
-- Deployment note: on the managed project these tables belong to supabase_admin.
-- The migration API recorded success but live ACL verification found PUBLIC grants
-- unchanged (non-owner REVOKE/GRANT warnings). Owner-level follow-up is REQUIRED;
-- do not treat this migration record alone as proof of applied hardening.
-- The net schema is not exposed over PostgREST (verified HTTP406/PGRST106).
