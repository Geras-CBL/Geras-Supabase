-- ============================================================
-- Migration: create_sensor_readings_table
-- Description: Creates sensor_readings table to simulate sensor
--   data from the database, with realtime support.
-- ============================================================

-- 1. Create table
create table if not exists sensor_readings (
  id           serial primary key,
  id_sensor    integer not null references sensors(id) on delete cascade,
  value        text,
  unit         text,
  type         text not null default 'motion', -- motion | temperature | humidity | etc.
  triggered_at timestamptz not null default now()
);

-- 2. Enable RLS
alter table sensor_readings enable row level security;

-- 3. Caretaker pode ver as leituras dos seus sensores
create policy "Caretaker can view sensor readings"
  on sensor_readings for select
  using (
    exists (
      select 1 from sensors s
      where s.id = sensor_readings.id_sensor
        and s.id_caretaker = (
          select id from users where auth_user_id = auth.uid()
        )
    )
  );

-- 4. Sénior pode ver as leituras dos seus sensores
create policy "Senior can view sensor readings"
  on sensor_readings for select
  using (
    exists (
      select 1 from sensors s
      where s.id = sensor_readings.id_sensor
        and s.id_senior = (
          select id from users where auth_user_id = auth.uid()
        )
    )
  );

-- 5. Caretaker pode inserir leituras (para simular dados)
create policy "Caretaker can insert sensor readings"
  on sensor_readings for insert
  with check (
    exists (
      select 1 from sensors s
      where s.id = sensor_readings.id_sensor
        and s.id_caretaker = (
          select id from users where auth_user_id = auth.uid()
        )
    )
  );

-- 6. Enable realtime for sensor_readings
alter publication supabase_realtime add table sensor_readings;
