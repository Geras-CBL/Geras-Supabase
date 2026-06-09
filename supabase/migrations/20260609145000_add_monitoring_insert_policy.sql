-- Adicionar permissões de INSERT para a tabela monitoring,
-- permitindo ao SENIOR inserir os seus próprios registos
-- e ao CARETAKER inserir registos dos seus seniores associados.

-- SENIOR: inserir o seu próprio monitoring
drop policy if exists "monitoring_senior_insert_own" on public.monitoring;
create policy "monitoring_senior_insert_own"
on public.monitoring for insert to authenticated
with check (
  id_senior = private.get_my_user_id()
);

-- CARETAKER: inserir monitoring para os seus seniores
drop policy if exists "monitoring_caretaker_insert_senior" on public.monitoring;
create policy "monitoring_caretaker_insert_senior"
on public.monitoring for insert to authenticated
with check (
  exists (
    select 1 from public.senior_caretaker sc
    where sc.id_caretaker = private.get_my_user_id()
      and sc.id_senior = id_senior
  )
);
