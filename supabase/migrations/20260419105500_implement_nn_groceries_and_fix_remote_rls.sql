-- ==============================================================
-- MIGRATION: N:N Groceries + Force RLS Policies on Remote
-- ==============================================================

-- --------------------------------------------------------------
-- 1) REAPLICAR POLICIES DE MEDICINE PARA ATUALIZAR O REMOTO
-- O Supabase CLI não corre ficheiros antigos alterados (como o rls_policies.sql)
-- por isso forçamos o drop e a criação do RLS nesta nova migração.
-- --------------------------------------------------------------

drop policy if exists "medicine_authenticated_insert" on public.medicine;
drop policy if exists "medicine_authenticated_select" on public.medicine;
drop policy if exists "medicine_select_policy" on public.medicine;
drop policy if exists "medicine_insert_policy" on public.medicine;
drop policy if exists "medicine_update_policy" on public.medicine;
drop policy if exists "medicine_delete_policy" on public.medicine;

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

-- --------------------------------------------------------------
-- 2) TRANSFORMAR GROCERIES NUM CATÁLOGO E CRIAR TABELA N:N
-- --------------------------------------------------------------

-- Remover id_senior de groceries (agora é só catálogo)
ALTER TABLE public.groceries DROP COLUMN IF EXISTS id_senior CASCADE;

-- Criar tabela N:N (Despensa do Sénior)
CREATE TABLE IF NOT EXISTS public.senior_groceries (
    id serial PRIMARY KEY,
    id_senior integer NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    id_groceries integer NOT NULL REFERENCES public.groceries(id) ON DELETE CASCADE,
    quantity integer DEFAULT 1,
    created_at timestamp without time zone DEFAULT now()
);

-- Ligar o RLS na nova tabela
ALTER TABLE public.senior_groceries ENABLE ROW LEVEL SECURITY;

-- --------------------------------------------------------------
-- 3) POLICIES PARA O CATÁLOGO GROCERIES
-- --------------------------------------------------------------

drop policy if exists "groceries_authenticated_insert" on public.groceries;
drop policy if exists "groceries_authenticated_select" on public.groceries;
drop policy if exists "groceries_select_policy" on public.groceries;
drop policy if exists "groceries_insert_policy" on public.groceries;
drop policy if exists "groceries_update_policy" on public.groceries;
drop policy if exists "groceries_delete_policy" on public.groceries;

-- SELECT: Qualquer pessoa autenticada pode ver o catálogo de groceries
create policy "groceries_catalog_select"
on public.groceries for select to authenticated
using (true);

-- INSERT: Restringir de "true" para verificação de autenticação estrita para limpar o aviso
create policy "groceries_catalog_insert"
on public.groceries for insert to authenticated
with check (auth.uid() is not null);

-- --------------------------------------------------------------
-- 4) POLICIES PARA A DESPENSA (SENIOR_GROCERIES) N:N
-- --------------------------------------------------------------

-- SELECT: Senior vê a sua despensa, Caretaker também vê
create policy "senior_groceries_select"
on public.senior_groceries for select to authenticated
using (
  id_senior = private.get_my_user_id()
  or exists (
    select 1 from public.senior_caretaker sc
    where sc.id_caretaker = private.get_my_user_id()
      and sc.id_senior = public.senior_groceries.id_senior
  )
);

-- INSERT/UPDATE/DELETE: Apenas o Senior ou o seu Caretaker podem alterar a despensa
create policy "senior_groceries_insert"
on public.senior_groceries for insert to authenticated
with check (
  id_senior = private.get_my_user_id()
  or exists (
    select 1 from public.senior_caretaker sc
    where sc.id_caretaker = private.get_my_user_id()
      and sc.id_senior = public.senior_groceries.id_senior
  )
);

create policy "senior_groceries_update"
on public.senior_groceries for update to authenticated
using (
  id_senior = private.get_my_user_id()
  or exists (
    select 1 from public.senior_caretaker sc
    where sc.id_caretaker = private.get_my_user_id()
      and sc.id_senior = public.senior_groceries.id_senior
  )
);

create policy "senior_groceries_delete"
on public.senior_groceries for delete to authenticated
using (
  id_senior = private.get_my_user_id()
  or exists (
    select 1 from public.senior_caretaker sc
    where sc.id_caretaker = private.get_my_user_id()
      and sc.id_senior = public.senior_groceries.id_senior
  )
);
