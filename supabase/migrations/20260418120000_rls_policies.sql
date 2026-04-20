-- ==============================================================
-- Geras - RLS Policies (versão corrigida)
-- Substitui Policies.sql (sem timestamp, era ignorado pelo CLI)
-- ==============================================================

-- --------------------------------------------------------------
-- 0) Private schema para funções helper
-- --------------------------------------------------------------
create schema if not exists private;

-- --------------------------------------------------------------
-- 1) Adicionar auth_user_id à public.users
-- --------------------------------------------------------------
alter table public.users
  add column if not exists auth_user_id uuid;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'users_auth_user_id_uniq'
  ) then
    alter table public.users
      add constraint users_auth_user_id_uniq unique (auth_user_id);
  end if;
end $$;

-- --------------------------------------------------------------
-- 2) Backfill por email
-- --------------------------------------------------------------
update public.users u
set auth_user_id = au.id
from auth.users au
where u.auth_user_id is null
  and u.email = au.email;

-- --------------------------------------------------------------
-- 3) Trigger: sync auth_user_id no registo de novos utilizadores
-- --------------------------------------------------------------
create or replace function public.sync_user_auth_id()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.users u
  set auth_user_id = new.id
  where u.email = new.email;
  return new;
end;
$$;

drop trigger if exists sync_user_auth_id_trigger on auth.users;
create trigger sync_user_auth_id_trigger
after insert on auth.users
for each row execute procedure public.sync_user_auth_id();

-- --------------------------------------------------------------
-- 4) Helper: devolve o INT id do utilizador autenticado atual
-- --------------------------------------------------------------
create or replace function private.get_my_user_id()
returns integer
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select u.id
  from public.users u
  where u.auth_user_id = auth.uid()
  limit 1
$$;

revoke all on function private.get_my_user_id() from public;
grant execute on function private.get_my_user_id() to authenticated;

-- --------------------------------------------------------------
-- 5) Activar RLS em todas as tabelas
-- --------------------------------------------------------------
alter table public.users             enable row level security;
alter table public.requests          enable row level security;
alter table public.evaluations       enable row level security;
alter table public.monitoring        enable row level security;
alter table public.notifications     enable row level security;
alter table public.vouchers_volunteer enable row level security;
alter table public.groceries         enable row level security;
alter table public.medicine          enable row level security;
alter table public.senior_caretaker  enable row level security;
alter table public.request_item      enable row level security;
alter table public.vouchers          enable row level security;

-- ==============================================================
-- 6) POLICIES: public.users
-- ==============================================================

drop policy if exists "users_select_own" on public.users;
create policy "users_select_own"
on public.users for select to authenticated
using (id = private.get_my_user_id());

drop policy if exists "users_update_own" on public.users;
create policy "users_update_own"
on public.users for update to authenticated
using (id = private.get_my_user_id())
with check (id = private.get_my_user_id());

-- ==============================================================
-- 7) POLICIES: public.requests
-- ==============================================================

-- SENIOR: criar pedidos
drop policy if exists "requests_senior_insert_own" on public.requests;
create policy "requests_senior_insert_own"
on public.requests for insert to authenticated
with check (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'SENIOR'
      and requests.id_senior = u.id
  )
);

-- SENIOR: ver os seus pedidos
drop policy if exists "requests_senior_select_own" on public.requests;
create policy "requests_senior_select_own"
on public.requests for select to authenticated
using (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'SENIOR'
      and public.requests.id_senior = u.id
  )
);

-- SENIOR: editar os seus pedidos
drop policy if exists "requests_senior_update_own" on public.requests;
create policy "requests_senior_update_own"
on public.requests for update to authenticated
using (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'SENIOR'
      and public.requests.id_senior = u.id
  )
)
with check (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'SENIOR'
      and public.requests.id_senior = u.id
  )
);

-- VOLUNTEER: ver PENDING ou pedidos onde está atribuído
drop policy if exists "requests_volunteer_select_pending_or_own" on public.requests;
create policy "requests_volunteer_select_pending_or_own"
on public.requests for select to authenticated
using (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'VOLUNTEER'
      and (
        public.requests.state = 'PENDING'
        or public.requests.id_volunteer = u.id
      )
  )
);

-- VOLUNTEER: aceitar pedido PENDING
drop policy if exists "requests_volunteer_accept" on public.requests;
create policy "requests_volunteer_accept"
on public.requests for update to authenticated
using (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'VOLUNTEER'
      and public.requests.state = 'PENDING'
      and public.requests.id_volunteer is null
  )
)
with check (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'VOLUNTEER'
      and public.requests.id_volunteer = u.id
      and public.requests.state = 'ACCEPTED'
  )
);

-- VOLUNTEER: concluir pedido ACCEPTED
drop policy if exists "requests_volunteer_complete" on public.requests;
create policy "requests_volunteer_complete"
on public.requests for update to authenticated
using (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'VOLUNTEER'
      and public.requests.id_volunteer = u.id
      and public.requests.state = 'ACCEPTED'
  )
)
with check (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'VOLUNTEER'
      and public.requests.id_volunteer = u.id
      and public.requests.state = 'COMPLETED'
  )
);

-- CARETAKER: ver PENDING ou os seus pedidos
drop policy if exists "requests_caretaker_select_pending_or_own" on public.requests;
create policy "requests_caretaker_select_pending_or_own"
on public.requests for select to authenticated
using (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'CARETAKER'
      and (
        public.requests.state = 'PENDING'
        or public.requests.id_caretaker = u.id
      )
  )
);

-- CARETAKER: aceitar pedido PENDING
drop policy if exists "requests_caretaker_accept" on public.requests;
create policy "requests_caretaker_accept"
on public.requests for update to authenticated
using (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'CARETAKER'
      and public.requests.state = 'PENDING'
      and public.requests.id_caretaker is null
  )
)
with check (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'CARETAKER'
      and public.requests.id_caretaker = u.id
      and public.requests.state = 'ACCEPTED'
  )
);

-- CARETAKER: reencaminhar para volunteer
drop policy if exists "requests_caretaker_forward_to_volunteer" on public.requests;
create policy "requests_caretaker_forward_to_volunteer"
on public.requests for update to authenticated
using (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'CARETAKER'
      and public.requests.state = 'ACCEPTED'
      and public.requests.id_caretaker = u.id
  )
)
with check (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'CARETAKER'
      and public.requests.id_caretaker = u.id
      and public.requests.id_volunteer is not null
      and public.requests.state = 'ACCEPTED'
  )
);

-- ==============================================================
-- 8) POLICIES: public.evaluations
-- FIX: lógica de SELECT corrigida (VOLUNTEER nunca tinha id_senior)
-- NEW: policy de INSERT adicionada
-- ==============================================================

-- SELECT: SENIOR ou VOLUNTEER participante no pedido
drop policy if exists "evaluations_select_participants" on public.evaluations;
create policy "evaluations_select_participants"
on public.evaluations for select to authenticated
using (
  exists (
    select 1 from public.requests r
    where r.id = public.evaluations.id_request
      and (
        r.id_senior    = private.get_my_user_id()
        or r.id_volunteer = private.get_my_user_id()
      )
  )
);

-- INSERT: apenas em pedidos COMPLETED, pelo SENIOR ou VOLUNTEER participante
drop policy if exists "evaluations_insert_participants" on public.evaluations;
create policy "evaluations_insert_participants"
on public.evaluations for insert to authenticated
with check (
  exists (
    select 1 from public.requests r
    where r.id = public.evaluations.id_request
      and r.state = 'COMPLETED'
      and (
        -- SENIOR avalia o VOLUNTEER
        (r.id_senior    = private.get_my_user_id()
          and public.evaluations.id_senior = private.get_my_user_id())
        or
        -- VOLUNTEER avalia (se aplicável no teu modelo)
        (r.id_volunteer = private.get_my_user_id()
          and public.evaluations.id_volunteer = private.get_my_user_id())
      )
  )
);

-- ==============================================================
-- 9) POLICIES: public.monitoring
-- FIX: adicionado acesso de leitura para CARETAKER dos seus seniores
-- ==============================================================

-- SENIOR: ver o seu próprio monitoring
drop policy if exists "monitoring_senior_select_own" on public.monitoring;
create policy "monitoring_senior_select_own"
on public.monitoring for select to authenticated
using (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'SENIOR'
      and public.monitoring.id_senior = u.id
  )
);

-- SENIOR: editar o seu próprio monitoring
drop policy if exists "monitoring_senior_update_own" on public.monitoring;
create policy "monitoring_senior_update_own"
on public.monitoring for update to authenticated
using (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'SENIOR'
      and public.monitoring.id_senior = u.id
  )
)
with check (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'SENIOR'
      and public.monitoring.id_senior = u.id
  )
);

-- NEW: CARETAKER vê o monitoring dos seus seniores (via senior_caretaker)
drop policy if exists "monitoring_caretaker_select_senior" on public.monitoring;
create policy "monitoring_caretaker_select_senior"
on public.monitoring for select to authenticated
using (
  exists (
    select 1 from public.senior_caretaker sc
    where sc.id_caretaker = private.get_my_user_id()
      and sc.id_senior    = public.monitoring.id_senior
  )
);

-- ==============================================================
-- 10) POLICIES: public.notifications
-- ==============================================================

drop policy if exists "notifications_select_own_by_role_field" on public.notifications;
create policy "notifications_select_own_by_role_field"
on public.notifications for select to authenticated
using (
  public.notifications.id_senior    = private.get_my_user_id()
  or public.notifications.id_caretaker = private.get_my_user_id()
  or public.notifications.id_volunteer = private.get_my_user_id()
);

-- ==============================================================
-- 11) POLICIES: public.vouchers_volunteer
-- ==============================================================

drop policy if exists "vouchers_volunteer_select_own" on public.vouchers_volunteer;
create policy "vouchers_volunteer_select_own"
on public.vouchers_volunteer for select to authenticated
using (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'VOLUNTEER'
      and public.vouchers_volunteer.id_volunteer = u.id
  )
);

-- ==============================================================
-- 12) POLICIES: public.senior_caretaker
-- ==============================================================

drop policy if exists "senior_caretaker_select_participation" on public.senior_caretaker;
create policy "senior_caretaker_select_participation"
on public.senior_caretaker for select to authenticated
using (
  id_senior    = private.get_my_user_id()
  or id_caretaker = private.get_my_user_id()
);

-- ==============================================================
-- 13) POLICIES: public.groceries
-- ==============================================================

-- Remover políticas abertas antigas caso existam
drop policy if exists "groceries_authenticated_insert" on public.groceries;
drop policy if exists "groceries_authenticated_select" on public.groceries;

-- SELECT: Senior vê os seus, Caretaker vê dos seniores, Volunteer vê dos seus requests
drop policy if exists "groceries_select_policy" on public.groceries;
create policy "groceries_select_policy"
on public.groceries for select to authenticated
using (
  id_senior = private.get_my_user_id()
  or exists (
    select 1 from public.senior_caretaker sc
    where sc.id_caretaker = private.get_my_user_id()
      and sc.id_senior = public.groceries.id_senior
  )
  or exists (
    select 1 from public.request_item ri
    join public.requests r on r.id = ri.id_request
    where ri.id_groceries = public.groceries.id
      and (r.id_volunteer = private.get_my_user_id() or r.state = 'PENDING')
  )
);

-- INSERT: Apenas o próprio Senior ou o seu Caretaker
drop policy if exists "groceries_insert_policy" on public.groceries;
create policy "groceries_insert_policy"
on public.groceries for insert to authenticated
with check (
  id_senior = private.get_my_user_id()
  or exists (
    select 1 from public.senior_caretaker sc
    where sc.id_caretaker = private.get_my_user_id()
      and sc.id_senior = public.groceries.id_senior
  )
);

-- UPDATE/DELETE: Apenas o próprio Senior ou o seu Caretaker
drop policy if exists "groceries_update_policy" on public.groceries;
create policy "groceries_update_policy"
on public.groceries for update to authenticated
using (
  id_senior = private.get_my_user_id()
  or exists (
    select 1 from public.senior_caretaker sc
    where sc.id_caretaker = private.get_my_user_id()
      and sc.id_senior = public.groceries.id_senior
  )
);

drop policy if exists "groceries_delete_policy" on public.groceries;
create policy "groceries_delete_policy"
on public.groceries for delete to authenticated
using (
  id_senior = private.get_my_user_id()
  or exists (
    select 1 from public.senior_caretaker sc
    where sc.id_caretaker = private.get_my_user_id()
      and sc.id_senior = public.groceries.id_senior
  )
);

-- ==============================================================
-- 14) POLICIES: public.medicine
-- ==============================================================

-- Remover políticas abertas antigas caso existam
drop policy if exists "medicine_authenticated_insert" on public.medicine;
drop policy if exists "medicine_authenticated_select" on public.medicine;

-- SELECT: Senior vê os seus, Caretaker vê dos seniores, Volunteer vê dos seus requests
drop policy if exists "medicine_select_policy" on public.medicine;
create policy "medicine_select_policy"
on public.medicine for select to authenticated
using (
  id_senior = private.get_my_user_id()
  or exists (
    select 1 from public.senior_caretaker sc
    where sc.id_caretaker = private.get_my_user_id()
      and sc.id_senior = public.medicine.id_senior
  )
  or exists (
    select 1 from public.request_item ri
    join public.requests r on r.id = ri.id_request
    where ri.id_medicine = public.medicine.id
      and (r.id_volunteer = private.get_my_user_id() or r.state = 'PENDING')
  )
);

-- INSERT: Apenas o próprio Senior ou o seu Caretaker
drop policy if exists "medicine_insert_policy" on public.medicine;
create policy "medicine_insert_policy"
on public.medicine for insert to authenticated
with check (
  id_senior = private.get_my_user_id()
  or exists (
    select 1 from public.senior_caretaker sc
    where sc.id_caretaker = private.get_my_user_id()
      and sc.id_senior = public.medicine.id_senior
  )
);

-- UPDATE/DELETE: Apenas o próprio Senior ou o seu Caretaker
drop policy if exists "medicine_update_policy" on public.medicine;
create policy "medicine_update_policy"
on public.medicine for update to authenticated
using (
  id_senior = private.get_my_user_id()
  or exists (
    select 1 from public.senior_caretaker sc
    where sc.id_caretaker = private.get_my_user_id()
      and sc.id_senior = public.medicine.id_senior
  )
);

drop policy if exists "medicine_delete_policy" on public.medicine;
create policy "medicine_delete_policy"
on public.medicine for delete to authenticated
using (
  id_senior = private.get_my_user_id()
  or exists (
    select 1 from public.senior_caretaker sc
    where sc.id_caretaker = private.get_my_user_id()
      and sc.id_senior = public.medicine.id_senior
  )
);

-- ==============================================================
-- 15) POLICIES: public.request_item
-- NEW: tabela tinha RLS activado mas zero policies (bloqueada!)
-- ==============================================================

-- SELECT: qualquer participante no pedido pode ver os itens
drop policy if exists "request_item_select_participants" on public.request_item;
create policy "request_item_select_participants"
on public.request_item for select to authenticated
using (
  exists (
    select 1 from public.requests r
    where r.id = public.request_item.id_request
      and (
        r.id_senior    = private.get_my_user_id()
        or r.id_volunteer  = private.get_my_user_id()
        or r.id_caretaker  = private.get_my_user_id()
      )
  )
);

-- INSERT: apenas o SENIOR dono do pedido pode adicionar itens
drop policy if exists "request_item_senior_insert" on public.request_item;
create policy "request_item_senior_insert"
on public.request_item for insert to authenticated
with check (
  exists (
    select 1 from public.requests r
    where r.id = public.request_item.id_request
      and r.id_senior = private.get_my_user_id()
  )
);

-- ==============================================================
-- 16) POLICIES: public.vouchers
-- NEW: tabela tinha RLS activado mas zero policies (bloqueada!)
-- Catálogo de vouchers — leitura para todos os autenticados.
-- INSERT/UPDATE gerido pelo service_role / admin.
-- ==============================================================

drop policy if exists "vouchers_authenticated_select" on public.vouchers;
create policy "vouchers_authenticated_select"
on public.vouchers for select to authenticated
using (true);
