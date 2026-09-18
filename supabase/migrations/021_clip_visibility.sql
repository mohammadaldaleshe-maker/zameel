-- Owner controls for campus video clips.
-- The Notes feature was explicitly removed from the product.
drop table if exists public.social_notes cascade;

alter table public.clips
  add column if not exists is_hidden boolean not null default false;

alter table public.clips drop constraint if exists clips_audience_check;
alter table public.clips add constraint clips_audience_check
  check (audience in ('public','friends','private','faculty','group'));

drop policy if exists clips_read on public.clips;
create policy clips_read on public.clips for select to authenticated
using (
  user_id = auth.uid()
  or (
    is_hidden = false
    and (
      audience = 'public'
      or (audience = 'friends' and public.is_colleague(auth.uid(), user_id))
      or audience in ('faculty','group')
    )
  )
);

create index if not exists clips_visibility_idx
  on public.clips(is_hidden, audience, created_at desc);
