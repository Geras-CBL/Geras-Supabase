-- ============================================================
-- Migration: create_sensors_table
-- Description: Creates the sensors table and RLS policies.
--   Sensors are associated to a senior and can be toggled
--   active/inactive by their assigned caretaker.
-- ============================================================

-- 1. Drop table if already exists (e.g. created manually)
drop table if exists sensors cascade;

-- 2. Create table
create table sensors (
  id          serial primary key,
  id_senior   integer not null references users(id) on delete cascade,
  name        text not null,
  icon        text not null,
  active      boolean not null default false,
  created_at  timestamptz not null default now()
);

-- 2. Enable RLS
alter table sensors enable row level security;

-- 3. Sénior pode ver os seus próprios sensores
create policy "Senior can view own sensors"
  on sensors for select
  using (
    id_senior = (
      select id from users where auth_user_id = auth.uid()
    )
  );

-- 4. Cuidador pode ver sensores dos seus seniores
create policy "Caretaker can view sensors"
  on sensors for select
  using (
    exists (
      select 1 from senior_caretaker sc
      where sc.id_senior = sensors.id_senior
        and sc.id_caretaker = (
          select id from users where auth_user_id = auth.uid()
        )
    )
  );

-- 5. Cuidador pode atualizar (ex: toggle ativo/inativo)
create policy "Caretaker can update sensors"
  on sensors for update
  using (
    exists (
      select 1 from senior_caretaker sc
      where sc.id_senior = sensors.id_senior
        and sc.id_caretaker = (
          select id from users where auth_user_id = auth.uid()
        )
    )
  );

-- 6. Cuidador pode adicionar sensores
create policy "Caretaker can insert sensors"
  on sensors for insert
  with check (
    exists (
      select 1 from senior_caretaker sc
      where sc.id_senior = sensors.id_senior
        and sc.id_caretaker = (
          select id from users where auth_user_id = auth.uid()
        )
    )
  );

-- 7. Cuidador pode remover sensores
create policy "Caretaker can delete sensors"
  on sensors for delete
  using (
    exists (
      select 1 from senior_caretaker sc
      where sc.id_senior = sensors.id_senior
        and sc.id_caretaker = (
          select id from users where auth_user_id = auth.uid()
        )
    )
  );
