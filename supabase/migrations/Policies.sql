-- ==============================================================
-- Geras - RLS policies
-- Auth source: auth.users (Supabase Auth)
-- App roles source: public.utilizadores.role
-- ==============================================================

-- --------------------------------------------------------------
-- 1) Safe role lookup function (avoids recursive policy checks)
-- --------------------------------------------------------------
create schema if not exists private;

create or replace function private.get_user_role()
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
	select u.role::text
	from public.utilizadores as u
	where u.id = auth.uid()
	limit 1;
$$;

revoke all on function private.get_user_role() from public;
grant execute on function private.get_user_role() to authenticated;

-- --------------------------------------------------------------
-- 2) Enable RLS on all relevant tables
-- --------------------------------------------------------------
alter table if exists public.utilizadores enable row level security;
alter table if exists public.perfil_senior enable row level security;
alter table if exists public.pedidos enable row level security;
alter table if exists public.carteira_voluntario enable row level security;

-- --------------------------------------------------------------
-- 3) Policies: utilizadores
-- --------------------------------------------------------------
drop policy if exists "utilizadores_select_own" on public.utilizadores;
create policy "utilizadores_select_own"
on public.utilizadores
for select
to authenticated
using (id = auth.uid());

drop policy if exists "utilizadores_update_own" on public.utilizadores;
create policy "utilizadores_update_own"
on public.utilizadores
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

-- --------------------------------------------------------------
-- 3) Policies: perfil_senior
-- --------------------------------------------------------------
drop policy if exists "perfil_senior_select_own_senior" on public.perfil_senior;
create policy "perfil_senior_select_own_senior"
on public.perfil_senior
for select
to authenticated
using (
	private.get_user_role() = 'SENIOR'
	and id_utilizador = auth.uid()
);

drop policy if exists "perfil_senior_update_own_senior" on public.perfil_senior;
create policy "perfil_senior_update_own_senior"
on public.perfil_senior
for update
to authenticated
using (
	private.get_user_role() = 'SENIOR'
	and id_utilizador = auth.uid()
)
with check (
	private.get_user_role() = 'SENIOR'
	and id_utilizador = auth.uid()
);

-- --------------------------------------------------------------
-- 3) Policies: pedidos
-- --------------------------------------------------------------

-- SENIOR can create only their own requests.
drop policy if exists "pedidos_insert_senior_own" on public.pedidos;
create policy "pedidos_insert_senior_own"
on public.pedidos
for insert
to authenticated
with check (
	private.get_user_role() = 'SENIOR'
	and id_senior = auth.uid()
);

-- SENIOR can list only their own requests.
drop policy if exists "pedidos_select_senior_own" on public.pedidos;
create policy "pedidos_select_senior_own"
on public.pedidos
for select
to authenticated
using (
	private.get_user_role() = 'SENIOR'
	and id_senior = auth.uid()
);

-- SENIOR can update only their own requests.
drop policy if exists "pedidos_update_senior_own" on public.pedidos;
create policy "pedidos_update_senior_own"
on public.pedidos
for update
to authenticated
using (
	private.get_user_role() = 'SENIOR'
	and id_senior = auth.uid()
)
with check (
	private.get_user_role() = 'SENIOR'
	and id_senior = auth.uid()
);

-- VOLUNTEER can see pending requests or requests already assigned to them.
drop policy if exists "pedidos_select_voluntario_pending_or_own" on public.pedidos;
create policy "pedidos_select_voluntario_pending_or_own"
on public.pedidos
for select
to authenticated
using (
	private.get_user_role() = 'VOLUNTARIO'
	and (
		status = 'PENDENTE'
		or id_voluntario = auth.uid()
	)
);

-- VOLUNTEER accepts a pending request by assigning self and setting status ACEITE.
drop policy if exists "pedidos_update_voluntario_accept" on public.pedidos;
create policy "pedidos_update_voluntario_accept"
on public.pedidos
for update
to authenticated
using (
	private.get_user_role() = 'VOLUNTARIO'
	and status = 'PENDENTE'
	and id_voluntario is null
)
with check (
	private.get_user_role() = 'VOLUNTARIO'
	and id_voluntario = auth.uid()
	and status = 'ACEITE'
);

-- VOLUNTEER concludes only their own accepted requests.
drop policy if exists "pedidos_update_voluntario_complete" on public.pedidos;
create policy "pedidos_update_voluntario_complete"
on public.pedidos
for update
to authenticated
using (
	private.get_user_role() = 'VOLUNTARIO'
	and id_voluntario = auth.uid()
	and status = 'ACEITE'
)
with check (
	private.get_user_role() = 'VOLUNTARIO'
	and id_voluntario = auth.uid()
	and status = 'CONCLUIDO'
);

-- --------------------------------------------------------------
-- 3) Policies: carteira_voluntario
-- --------------------------------------------------------------
drop policy if exists "carteira_voluntario_select_own" on public.carteira_voluntario;
create policy "carteira_voluntario_select_own"
on public.carteira_voluntario
for select
to authenticated
using (
	private.get_user_role() = 'VOLUNTARIO'
	and id_voluntario = auth.uid()
);

-- No INSERT/UPDATE/DELETE policy is created on purpose.
-- Those operations stay blocked for authenticated users,
-- and can be handled by privileged backend/triggers.
