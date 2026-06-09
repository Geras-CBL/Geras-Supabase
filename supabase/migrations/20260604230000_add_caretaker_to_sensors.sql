-- ============================================================
-- Migration: add_id_caretaker_to_sensors
-- Description: Adds id_caretaker column to sensors table so
--   each caretaker has their own sensor configuration per senior.
--   Drops and recreates the table (and RLS policies) cleanly.
-- ============================================================

-- 1. Drop existing table and policies
drop table if exists sensors cascade;

-- 2. Recreate table with id_caretaker
create table sensors (
  id            serial primary key,
  id_senior     integer not null references users(id) on delete cascade,
  id_caretaker  integer not null references users(id) on delete cascade,
  name          text not null,
  icon          text not null,
  active        boolean not null default false,
  created_at    timestamptz not null default now()
);

-- 3. Enable RLS
alter table sensors enable row level security;

-- 4. Sénior pode ver os seus próprios sensores (todos os cuidadores)
create policy "Senior can view own sensors"
  on sensors for select
  using (
    id_senior = (
      select id from users where auth_user_id = auth.uid()
    )
  );

-- 5. Cuidador pode ver os seus próprios sensores para os seus seniores
create policy "Caretaker can view sensors"
  on sensors for select
  using (
    id_caretaker = (
      select id from users where auth_user_id = auth.uid()
    )
  );

-- 6. Cuidador pode atualizar os seus sensores
create policy "Caretaker can update sensors"
  on sensors for update
  using (
    id_caretaker = (
      select id from users where auth_user_id = auth.uid()
    )
  );

-- 7. Cuidador pode inserir sensores
create policy "Caretaker can insert sensors"
  on sensors for insert
  with check (
    id_caretaker = (
      select id from users where auth_user_id = auth.uid()
    )
  );

-- 8. Cuidador pode apagar os seus sensores
create policy "Caretaker can delete sensors"
  on sensors for delete
  using (
    id_caretaker = (
      select id from users where auth_user_id = auth.uid()
    )
  );
