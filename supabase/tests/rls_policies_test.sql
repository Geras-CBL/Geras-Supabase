-- ==============================================================
-- Geras - Testes de RLS Policies (pgTAP)
-- Executar com: npx supabase test db
--
-- Padrão usado:
--   1. set jwt claims (como postgres)
--   2. set local role authenticated
--   3. Guardar resultados em temp tables
--   4. reset role  ← OBRIGATÓRIO antes de chamar funções pgTAP
--   5. Assertions com pgTAP (corre como postgres, acede a __tcache__)
-- ==============================================================
begin;

select plan(25);

-- ==============================================================
-- SETUP: dados de teste (corre como postgres/superuser)
-- ==============================================================
insert into auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role)
values
  ('00000000-0000-0000-0000-000000000001', 'senior@test.com',    'x', now(), now(), now(), '{}', '{}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000002', 'volunteer@test.com', 'x', now(), now(), now(), '{}', '{}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000003', 'caretaker@test.com', 'x', now(), now(), now(), '{}', '{}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000004', 'senior2@test.com',   'x', now(), now(), now(), '{}', '{}', 'authenticated', 'authenticated')
on conflict do nothing;

insert into public.users (id, email, password_hash, name, role, auth_user_id)
values
  (1001, 'senior@test.com',    'hash', 'Senior Teste',    'SENIOR',    '00000000-0000-0000-0000-000000000001'),
  (1002, 'volunteer@test.com', 'hash', 'Volunteer Teste', 'VOLUNTEER', '00000000-0000-0000-0000-000000000002'),
  (1003, 'caretaker@test.com', 'hash', 'Caretaker Teste', 'CARETAKER', '00000000-0000-0000-0000-000000000003'),
  (1004, 'senior2@test.com',   'hash', 'Senior 2 Teste',  'SENIOR',    '00000000-0000-0000-0000-000000000004')
on conflict do nothing;

insert into public.senior_caretaker (id_senior, id_caretaker) values (1001, 1003) on conflict do nothing;

insert into public.requests (id, state, id_senior, id_volunteer, id_caretaker)
values
  (9001, 'PENDING',   1001, null, null),
  (9002, 'ACCEPTED',  1001, 1002, null),
  (9003, 'COMPLETED', 1001, 1002, null),
  (9004, 'PENDING',   1004, null, null)
on conflict do nothing;

insert into public.monitoring (id, id_senior, type, value) values (8001, 1001, 'HEART RATE', 72) on conflict do nothing;
insert into public.notifications (id, description, id_senior) values (7001, 'Notif senior', 1001) on conflict do nothing;
insert into public.notifications (id, description, id_volunteer) values (7002, 'Notif volunteer', 1002) on conflict do nothing;
insert into public.vouchers (id, store_name, value) values (6001, 'Loja Teste', 10.00) on conflict do nothing;
insert into public.vouchers_volunteer (id_voucher, id_volunteer) values (6001, 1002) on conflict do nothing;
insert into public.evaluations (id, evaluation, id_senior, id_volunteer, id_request) values (5001, 'SATISFIED', 1001, 1002, 9003) on conflict do nothing;

-- ==============================================================
-- BLOCO 1: SENIOR (1001)
-- ==============================================================
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;

create temp table t1_users      as select id from public.users;
create temp table t1_requests   as select id from public.requests order by id;
create temp table t1_monitoring as select id from public.monitoring;
create temp table t1_notifs     as select id from public.notifications;
create temp table t1_vouchers   as select id from public.vouchers;
create temp table t1_sc         as select id_senior, id_caretaker from public.senior_caretaker;
create temp table t1_evals      as select id from public.evaluations;

reset role; -- ← SEMPRE antes de chamar pgTAP

select results_eq('select id from t1_users', ARRAY[1001],         'SENIOR vê só o seu próprio perfil');
select results_eq('select id from t1_requests', ARRAY[9001,9002,9003], 'SENIOR vê os seus 3 pedidos');
select is_empty('select id from t1_requests where id = 9004',     'SENIOR não vê pedidos de outro senior');
select results_eq('select id from t1_monitoring', ARRAY[8001],    'SENIOR vê o seu monitoring');
select results_eq('select id from t1_notifs', ARRAY[7001],        'SENIOR vê as suas notificações');
select results_eq('select id from t1_vouchers', ARRAY[6001],      'SENIOR vê o catálogo de vouchers');
select ok((select count(*) from t1_sc where id_senior = 1001) = 1,'SENIOR vê a sua relação com caretaker');
select results_eq('select id from t1_evals', ARRAY[5001],         'SENIOR vê avaliações dos seus pedidos');

-- ==============================================================
-- BLOCO 2: VOLUNTEER (1002)
-- ==============================================================
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;

create temp table t2_users       as select id from public.users;
create temp table t2_requests    as select id, state, id_volunteer from public.requests order by id;
create temp table t2_monitoring  as select id from public.monitoring;
create temp table t2_notifs      as select id from public.notifications;
create temp table t2_vv          as select id_voucher from public.vouchers_volunteer;
create temp table t2_evals       as select id from public.evaluations;

reset role;

select results_eq('select id from t2_users', ARRAY[1002],          'VOLUNTEER vê só o seu próprio perfil');
select ok((select count(*) from t2_requests where state = 'PENDING') >= 1, 'VOLUNTEER vê pedidos PENDING');
select ok((select count(*) from t2_requests where id = 9002) = 1,   'VOLUNTEER vê pedido ACCEPTED onde é executante');
select is_empty('select id from t2_monitoring',                      'VOLUNTEER não vê monitoring de ninguém');
select results_eq('select id from t2_notifs', ARRAY[7002],          'VOLUNTEER vê só as suas notificações');
select results_eq('select id_voucher from t2_vv', ARRAY[6001],      'VOLUNTEER vê a sua carteira de vouchers');
select results_eq('select id from t2_evals', ARRAY[5001],           'VOLUNTEER vê avaliações onde participou');

-- ==============================================================
-- BLOCO 3: CARETAKER (1003)
-- ==============================================================
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000003","role":"authenticated"}', true);
set local role authenticated;

create temp table t3_users      as select id from public.users;
create temp table t3_requests   as select id, state from public.requests order by id;
create temp table t3_monitoring as select id from public.monitoring;
create temp table t3_sc         as select id_senior, id_caretaker from public.senior_caretaker;

reset role;

select results_eq('select id from t3_users', ARRAY[1003],             'CARETAKER vê só o seu próprio perfil');
select ok((select count(*) from t3_requests where state = 'PENDING') >= 1, 'CARETAKER vê pedidos PENDING');
select results_eq('select id from t3_monitoring', ARRAY[8001],        'CARETAKER vê monitoring do seu senior');
select ok((select count(*) from t3_sc where id_caretaker = 1003) = 1, 'CARETAKER vê a sua relação com senior');

-- ==============================================================
-- BLOCO 4: SENIOR 2 (1004) — utilizador sem relações
-- ==============================================================
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000004","role":"authenticated"}', true);
set local role authenticated;

create temp table t4_users      as select id from public.users;
create temp table t4_requests   as select id from public.requests order by id;
create temp table t4_monitoring as select id from public.monitoring;
create temp table t4_notifs     as select id from public.notifications;
create temp table t4_evals      as select id from public.evaluations;
create temp table t4_sc         as select id_senior, id_caretaker from public.senior_caretaker;

reset role;

select results_eq('select id from t4_users', ARRAY[1004],    'SENIOR2 vê só o seu perfil');
select results_eq('select id from t4_requests', ARRAY[9004], 'SENIOR2 vê só o seu pedido');
select is_empty('select id from t4_monitoring',              'SENIOR2 não vê monitoring do SENIOR1');
select is_empty('select id from t4_notifs',                  'SENIOR2 não vê notificações do SENIOR1');
select is_empty('select id from t4_evals',                   'SENIOR2 não vê avaliações de outros');
select is_empty('select id_senior from t4_sc',               'SENIOR2 sem relação caretaker não vê senior_caretaker');

-- ==============================================================
-- FINALIZAR (como postgres)
-- ==============================================================
select * from finish();

rollback;
