-- ==============================================================
-- Geras - RLS policies
-- Link Auth (auth.users) -> Perfis (public.users)
-- ==============================================================

-- --------------------------------------------------------------
-- 0) Private schema for helper functions
-- --------------------------------------------------------------
create schema if not exists private;

-- --------------------------------------------------------------
-- 1) Ensure public.users has a link to auth.users
-- --------------------------------------------------------------
alter table public.users
add column if not exists auth_user_id uuid;

-- Colocar um constraint para não haver múltiplos perfis para o mesmo auth_user_id
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'users_auth_user_id_uniq'
  ) then
    alter table public.users
      add constraint users_auth_user_id_uniq unique (auth_user_id);
  end if;
end $$;

-- --------------------------------------------------------------
-- 2) Backfill (opcional) - se já tens um mapeamento por email
--    Isto só funciona se o email de auth.users coincidir com public.users.email.
-- --------------------------------------------------------------
update public.users u
set auth_user_id = au.id
from auth.users au
where u.auth_user_id is null
  and u.email = au.email;

-- --------------------------------------------------------------
-- 3) Trigger to set auth_user_id on new auth.users rows
-- --------------------------------------------------------------
create or replace function public.handle_new_user_auth_link()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, email, password_hash, name, role, auth_user_id)
  values (
    -- nota: assumes public.users rows são geridas por ti/seed.
    -- Se no teu projeto o public.users já é criado por outro processo,
    -- NÃO queremos duplicar: por isso vamos fazer update ao invés de insert.
    -- Vamos trocar para update abaixo.
    0, '', '', '', 'SENIOR', new.id
  );
exception when unique_violation then
  -- ignore
  null;
end;
$$;

-- A abordagem acima é perigosa (podia criar registos lixo).
-- Em vez disso, vamos fazer uma trigger "UPDATE by email" segura:
drop function if exists public.handle_new_user_auth_link();

create or replace function public.sync_user_auth_id()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Se o perfil public.users já existir (por email), liga ao auth_user_id
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
-- 4) Helper: return the INT user id for current auth uid
--    (SECURITY DEFINER, para não aceder/recursar policies)
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
-- 5) Enable RLS on relevant tables
-- --------------------------------------------------------------
alter table public.users enable row level security;
alter table public.requests enable row level security;
alter table public.evaluations enable row level security;
alter table public.monitoring enable row level security;
alter table public.notifications enable row level security;
alter table public.vouchers_volunteer enable row level security;

-- “Auxiliares” (normalmente devem ser leitura pública/autenticada conforme regra do teu negócio)
alter table public.groceries enable row level security;
alter table public.medicine enable row level security;
alter table public.request_item enable row level security;
alter table public.vouchers enable row level security;

-- Relação SENIOR <-> CARETAKER
alter table public.senior_caretaker enable row level security;

-- --------------------------------------------------------------
-- 6) POLICIES: public.users
-- --------------------------------------------------------------

drop policy if exists "users_select_own" on public.users;
create policy "users_select_own"
on public.users
for select
to authenticated
using (id = private.get_my_user_id());

drop policy if exists "users_update_own" on public.users;
create policy "users_update_own"
on public.users
for update
to authenticated
using (id = private.get_my_user_id())
with check (id = private.get_my_user_id());

-- --------------------------------------------------------------
-- 7) POLICIES: public.requests (pedidos)
-- Roles (enum): SENIOR | VOLUNTEER | CARETAKER
-- Status (enum): PENDING | ACCEPTED | COMPLETED | CANCELLED
-- --------------------------------------------------------------

-- SENIOR: pode ver/editar só pedidos onde é o sénior e pode criar pedidos
drop policy if exists "requests_senior_insert_own" on public.requests;
create policy "requests_senior_insert_own"
on public.requests
for insert
to authenticated
with check (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'SENIOR'
      and requests.id_senior = u.id
  )
);

drop policy if exists "requests_senior_select_own" on public.requests;
create policy "requests_senior_select_own"
on public.requests
for select
to authenticated
using (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'SENIOR'
      and public.requests.id_senior = u.id
  )
);

drop policy if exists "requests_senior_update_own" on public.requests;
create policy "requests_senior_update_own"
on public.requests
for update
to authenticated
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

-- VOLUNTEER: vê PENDENTE ou pedidos onde já está atribuído (id_volunteer)
drop policy if exists "requests_volunteer_select_pending_or_own" on public.requests;
create policy "requests_volunteer_select_pending_or_own"
on public.requests
for select
to authenticated
using (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'VOLUNTEER'
      and (
        public.requests.status = 'PENDING'
        or public.requests.id_volunteer = u.id
      )
  )
);

-- VOLUNTEER: aceitar um pedido PENDENTE (id_volunteer estava NULL) -> status = ACCEPTED e id_volunteer = self
drop policy if exists "requests_volunteer_accept" on public.requests;
create policy "requests_volunteer_accept"
on public.requests
for update
to authenticated
using (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'VOLUNTEER'
      and public.requests.status = 'PENDING'
      and public.requests.id_volunteer is null
  )
)
with check (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'VOLUNTEER'
      and public.requests.id_volunteer = u.id
      and public.requests.status = 'ACCEPTED'
  )
);

-- VOLUNTEER: concluir pedidos onde é o executante (id_volunteer) -> status = COMPLETED
drop policy if exists "requests_volunteer_complete" on public.requests;
create policy "requests_volunteer_complete"
on public.requests
for update
to authenticated
using (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'VOLUNTEER'
      and public.requests.id_volunteer = u.id
      and public.requests.status = 'ACCEPTED'
  )
)
with check (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'VOLUNTEER'
      and public.requests.id_volunteer = u.id
      and public.requests.status = 'COMPLETED'
  )
);

-- CARETAKER: (não estava no teu prompt original)
-- Vou deixar “bloqueado por defeito” (sem policies) para não dar permissões indevidas.
-- Se quiseres regras específicas para CARETAKER, diz-me como deve funcionar.

-- --------------------------------------------------------------
-- 8) POLICIES: public.evaluations
-- Avaliações ligadas a requests e a users.
-- Regra segura: permitir apenas quem participa no request.
-- --------------------------------------------------------------
drop policy if exists "evaluations_select_participants" on public.evaluations;
create policy "evaluations_select_participants"
on public.evaluations
for select
to authenticated
using (
  exists (
    select 1
    from public.requests r
    where r.id = public.evaluations.id_request
      and (
        (exists (select 1 from public.users u where u.id = private.get_my_user_id() and u.role in ('SENIOR','VOLUNTEER') and u.id = r.id_senior))
        or
        (exists (select 1 from public.users u where u.id = private.get_my_user_id() and u.role = 'VOLUNTEER' and u.id = r.id_volunteer))
      )
  )
);

-- update: senão for tua regra explícita, bloqueamos update por defeito
-- (para não abrir escrita indevida).
-- --------------------------------------------------------------
-- 9) POLICIES: public.monitoring (sensível)
-- --------------------------------------------------------------
-- Regra conservadora: apenas SENIOR vê/edita o seu próprio monitoring (id_senior)
drop policy if exists "monitoring_senior_select_own" on public.monitoring;
create policy "monitoring_senior_select_own"
on public.monitoring
for select
to authenticated
using (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'SENIOR'
      and public.monitoring.id_senior = u.id
  )
);

drop policy if exists "monitoring_senior_update_own" on public.monitoring;
create policy "monitoring_senior_update_own"
on public.monitoring
for update
to authenticated
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

-- --------------------------------------------------------------
-- 10) POLICIES: public.notifications
-- Regra: cada destinatário (id_senior / id_caretaker / id_volunteer) vê as suas.
-- --------------------------------------------------------------
drop policy if exists "notifications_select_own_by_role_field" on public.notifications;
create policy "notifications_select_own_by_role_field"
on public.notifications
for select
to authenticated
using (
  public.notifications.id_senior = private.get_my_user_id()
  or public.notifications.id_caretaker = private.get_my_user_id()
  or public.notifications.id_volunteer = private.get_my_user_id()
);

-- bloqueamos updates/deletes por defeito (sem policies)

-- --------------------------------------------------------------
-- 11) POLICIES: public.vouchers_volunteer (carteira_voluntario)
-- Regra: VOLUNTEER só vê a sua carteira (id_volunteer = self). Sem INSERT/UPDATE.
-- --------------------------------------------------------------
drop policy if exists "vouchers_volunteer_select_own" on public.vouchers_volunteer;
create policy "vouchers_volunteer_select_own"
on public.vouchers_volunteer
for select
to authenticated
using (
  exists (
    select 1 from public.users u
    where u.id = private.get_my_user_id()
      and u.role = 'VOLUNTEER'
      and public.vouchers_volunteer.id_volunteer = u.id
  )
);

-- --------------------------------------------------------------
-- 12) POLICIES: public.senior_caretaker
-- Regra segura: só permitir ver a relação onde o utilizador participa.
-- --------------------------------------------------------------
drop policy if exists "senior_caretaker_select_participation" on public.senior_caretaker;
create policy "senior_caretaker_select_participation"
on public.senior_caretaker
for select
to authenticated
using (
  id_senior = private.get_my_user_id()
  or id_caretaker = private.get_my_user_id()
);

-- --------------------------------------------------------------
-- 13) Tabelas auxiliares (groceries/medicine/vouchers/request_item)
-- Sem regras explícitas no teu prompt, por defeito:
-- - ou bloqueadas
-- - ou leitura apenas quando necessário
-- Vou deixar bloqueadas (sem policies), para segurança máxima.
-- --------------------------------------------------------------