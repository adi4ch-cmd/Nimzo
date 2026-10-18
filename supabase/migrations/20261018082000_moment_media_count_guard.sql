-- Tighten the existing author-scoped Moment image guard without touching
-- existing posts. Flutter supports 1–9 photos; the server enforces the same cap.
CREATE OR REPLACE FUNCTION public.nimzo_moment_media_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare path text; changed boolean;
begin
 if TG_OP='INSERT' then
  if cardinality(new.image_paths)=0 and new.image_path is not null then new.image_paths=array[new.image_path]; end if;
  changed=true;
 else
  changed=new.image_paths is distinct from old.image_paths or new.image_path is distinct from old.image_path;
  if new.image_paths is not distinct from old.image_paths and new.image_path is distinct from old.image_path then
   new.image_paths=case when new.image_path is null then '{}'::text[] else array[new.image_path] end;
  end if;
 end if;
 if changed then
  if cardinality(new.image_paths)>9 then
   raise exception 'A Moment may contain at most 9 photos' using errcode='23514';
  end if;
  foreach path in array new.image_paths loop
   if path is null or path not like new.author_id::text||'/%' or path like '%..%' or char_length(path)>512 then
    raise exception 'Moment images must belong to the author' using errcode='23514';
   end if;
  end loop;
 end if;
 new.image_path=new.image_paths[1];
 return new;
end $function$;

revoke all on function public.nimzo_moment_media_guard() from public,anon,authenticated;
