-- CARETAKER: concluir pedido ACCEPTED
drop policy if exists "requests_caretaker_complete" on public.requests;
create policy "requests_caretaker_complete"
on public.requests for update to authenticated
using (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'CARETAKER'
      and public.requests.id_caretaker = u.id
      and public.requests.state = 'ACCEPTED'
  )
)
with check (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'CARETAKER'
      and public.requests.id_caretaker = u.id
      and public.requests.state = 'COMPLETED'
  )
);
