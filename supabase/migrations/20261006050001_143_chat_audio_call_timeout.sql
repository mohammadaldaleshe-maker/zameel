begin;
-- Retain existing participant/storage policies and add the audio attachment type.
do $$ declare c record; begin
  for c in select conname from pg_constraint where conrelid='public.chat_attachments'::regclass
    and contype='c' and pg_get_constraintdef(oid) like '%media_type%' loop
    execute format('alter table public.chat_attachments drop constraint %I',c.conname);
  end loop;
  alter table public.chat_attachments add constraint chat_attachment_media_type_check
    check(media_type in ('image','video','file','audio'));
end $$;
update storage.buckets set allowed_mime_types = array(
  select distinct item from unnest(allowed_mime_types || array['audio/mp4','audio/aac']) item
) where id='chat_attachments' and allowed_mime_types is not null;
-- The server prevents old clients from accepting an invitation after 45 seconds.
create or replace function public.zameel_call_deadline_143()
returns trigger language plpgsql set search_path='' as $$
begin
  if old.status='ringing' and new.status='active'
     and old.created_at <= clock_timestamp()-interval '45 seconds' then
    new.status:='missed';
    new.answered_at:=null;
    new.ended_at:=clock_timestamp();
  end if;
  return new;
end $$;
revoke all on function public.zameel_call_deadline_143() from public,anon,authenticated;
drop trigger if exists zameel_call_deadline_143 on public.direct_call_sessions;
create trigger zameel_call_deadline_143 before update of status on public.direct_call_sessions
for each row execute function public.zameel_call_deadline_143();
notify pgrst,'reload schema';
commit;
