-- Adicionar política de UPDATE para vouchers_volunteer
-- Permite ao voluntário atualizar apenas os seus próprios vouchers

drop policy if exists "vouchers_volunteer_update_own" on public.vouchers_volunteer;
create policy "vouchers_volunteer_update_own"
on public.vouchers_volunteer for update to authenticated
using (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'VOLUNTEER'
      and public.vouchers_volunteer.id_volunteer = u.id
  )
)
with check (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'VOLUNTEER'
      and public.vouchers_volunteer.id_volunteer = u.id
  )
);
