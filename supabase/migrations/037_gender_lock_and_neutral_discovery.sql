-- Zameel 037: lock gender after onboarding.
-- Corrections are handled only through an audited support process.

begin;

create or replace function public.prevent_user_gender_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.gender is not null and new.gender is distinct from old.gender then
    raise exception 'gender_locked_after_registration'
      using errcode = 'P0001',
            detail = 'Contact support to correct registration data.';
  end if;
  return new;
end;
$$;

drop trigger if exists users_prevent_gender_change on public.users;
create trigger users_prevent_gender_change
before update of gender on public.users
for each row
execute function public.prevent_user_gender_change();

comment on function public.prevent_user_gender_change() is
  'Prevents self-service gender changes after registration.';

commit;
