begin;
do $$begin
 if has_table_privilege('anon','net.http_request_queue','select') or has_table_privilege('authenticated','net.http_request_queue','select') then raise exception 'Transport requests exposed';end if;
 if has_table_privilege('anon','net._http_response','select') or has_table_privilege('authenticated','net._http_response','select') then raise exception 'Transport responses exposed';end if;
 if not has_table_privilege('service_role','net.http_request_queue','insert') then raise exception 'Trusted backend transport unavailable';end if;
end$$;
rollback;
