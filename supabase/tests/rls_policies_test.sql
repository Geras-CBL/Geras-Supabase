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

select plan(32);

-- ==============================================================
-- SETUP: dados de teste (corre como postgres/superuser)
--
-- NOTA: O trigger sync_user_auth_id() insere automaticamente em
-- public.users quando inserimos em auth.users (com on conflict
-- (email) do update). Por isso NÃO inserimos diretamente em
-- public.users com IDs hard-coded — usamos os IDs gerados
-- pelo trigger e guardamo-los em variáveis via temp table.
-- ==============================================================
insert into auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role)
values
  ('00000000-0000-0000-0000-000000000001', 'senior@test.com',    'x', now(), now(), now(), '{}', '{"name":"Senior Teste",   "role":"SENIOR"}',    'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000002', 'volunteer@test.com', 'x', now(), now(), now(), '{}', '{"name":"Volunteer Teste","role":"VOLUNTEER"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000003', 'caretaker@test.com', 'x', now(), now(), now(), '{}', '{"name":"Caretaker Teste","role":"CARETAKER"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000004', 'senior2@test.com',   'x', now(), now(), now(), '{}', '{"name":"Senior 2 Teste", "role":"SENIOR"}',    'authenticated', 'authenticated')
on conflict do nothing;

-- Guardar os IDs reais gerados pelo trigger numa temp table
create temp table test_user_ids as
  select
    (select id from public.users where auth_user_id = '00000000-0000-0000-0000-000000000001') as id_senior,
    (select id from public.users where auth_user_id = '00000000-0000-0000-0000-000000000002') as id_volunteer,
    (select id from public.users where auth_user_id = '00000000-0000-0000-0000-000000000003') as id_caretaker,
    (select id from public.users where auth_user_id = '00000000-0000-0000-0000-000000000004') as id_senior2;

-- Inserir relação senior-caretaker usando os IDs reais
insert into public.senior_caretaker (id_senior, id_caretaker)
  select id_senior, id_caretaker from test_user_ids
on conflict do nothing;

-- Inserir pedidos usando os IDs reais
-- NOTA: is_public=true no PENDING para que VOLUNTEER o consiga ver (política requests_volunteer_select_pending_or_own)
insert into public.requests (state, description, is_public, id_senior, id_volunteer, id_caretaker)
  select 'PENDING',   'Pedido de teste PENDING senior',    true,  id_senior,  null,         null from test_user_ids;
insert into public.requests (state, description, is_public, id_senior, id_volunteer, id_caretaker)
  select 'ACCEPTED',  'Pedido de teste ACCEPTED',          false, id_senior,  id_volunteer, null from test_user_ids;
insert into public.requests (state, description, is_public, id_senior, id_volunteer, id_caretaker)
  select 'COMPLETED', 'Pedido de teste COMPLETED',         false, id_senior,  id_volunteer, null from test_user_ids;
insert into public.requests (state, description, is_public, id_senior, id_volunteer, id_caretaker)
  select 'PENDING',   'Pedido de teste PENDING senior2',   true,  id_senior2, null,         null from test_user_ids;

-- Guardar IDs dos pedidos gerados
create temp table test_request_ids as
  select
    (select id from public.requests where id_senior = (select id_senior  from test_user_ids) and state = 'PENDING'   limit 1) as id_req_pending,
    (select id from public.requests where id_senior = (select id_senior  from test_user_ids) and state = 'ACCEPTED'  limit 1) as id_req_accepted,
    (select id from public.requests where id_senior = (select id_senior  from test_user_ids) and state = 'COMPLETED' limit 1) as id_req_completed,
    (select id from public.requests where id_senior = (select id_senior2 from test_user_ids) and state = 'PENDING'   limit 1) as id_req_senior2;

-- Garantir que metric_definitions tem a entrada necessária para o teste
insert into public.metric_definitions (metric_type, unit, has_secondary, primary_label)
  values ('HEART RATE', 'bpm', false, 'Frequência Cardíaca')
on conflict do nothing;

-- Inserir monitoring para o senior
insert into public.monitoring (id_senior, metric_type, value_primary, measured_at)
  select id_senior, 'HEART RATE', 72, now() from test_user_ids;

create temp table test_monitoring_id as
  select (select id from public.monitoring where id_senior = (select id_senior from test_user_ids) limit 1) as id_mon;

-- Inserir notificações
insert into public.notifications (description, id_senior)
  select 'Notif senior', id_senior from test_user_ids;
insert into public.notifications (description, id_volunteer)
  select 'Notif volunteer', id_volunteer from test_user_ids;

create temp table test_notif_ids as
  select
    -- Identificar por description única para evitar colisões com notificações do trigger
    (select id from public.notifications where description = 'Notif senior'    limit 1) as id_notif_senior,
    (select id from public.notifications where description = 'Notif volunteer' limit 1) as id_notif_volunteer;

-- Inserir voucher
insert into public.vouchers (store_name, value) values ('Loja Teste', 10.00);
create temp table test_voucher_id as
  select (select id from public.vouchers where store_name = 'Loja Teste' limit 1) as id_voucher;

insert into public.vouchers_volunteer (id_voucher, id_volunteer)
  select (select id_voucher from test_voucher_id), (select id_volunteer from test_user_ids);

-- Inserir avaliação
insert into public.evaluations (evaluation, id_senior, id_volunteer, id_request)
  select 'SATISFIED', id_senior, id_volunteer, (select id_req_completed from test_request_ids)
  from test_user_ids;

create temp table test_eval_id as
  select (select id from public.evaluations where id_senior = (select id_senior from test_user_ids) limit 1) as id_eval;

-- ==============================================================
-- BLOCO 1: SENIOR
-- ==============================================================
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);
set local role authenticated;

create temp table t1_users      as select id from public.users;
create temp table t1_requests   as select id from public.requests order by id;
create temp table t1_monitoring as select id from public.monitoring;
create temp table t1_notifs     as select id from public.notifications;
create temp table t1_vouchers   as select id from public.vouchers;
create temp table t1_sc         as select id_senior, id_caretaker from public.senior_caretaker;
create temp table t1_evals      as select id from public.evaluations;

reset role; -- ← SEMPRE antes de chamar pgTAP

-- SENIOR vê o seu próprio perfil E o seu caretaker (política users_caretaker_select_seniors)
select ok(
  (select count(*) from t1_users where id = (select id_senior from test_user_ids)) = 1,
  'SENIOR vê o seu próprio perfil');

select ok(
  (select count(*) from t1_users where id = (select id_caretaker from test_user_ids)) = 1,
  'SENIOR vê o seu caretaker');

select ok(
  (select count(*) from t1_users where id not in (select id_senior from test_user_ids) and id != (select id_caretaker from test_user_ids)) = 0,
  'SENIOR não vê outros utilizadores');

select results_eq(
  'select id from t1_requests order by id',
  'select id from public.requests where id_senior = (select id_senior from test_user_ids) order by id',
  'SENIOR vê os seus 3 pedidos');

select is_empty(
  'select id from t1_requests where id = (select id_req_senior2 from test_request_ids)',
  'SENIOR não vê pedidos de outro senior');

select results_eq(
  'select id from t1_monitoring',
  'select id_mon from test_monitoring_id',
  'SENIOR vê o seu monitoring');

select results_eq(
  'select id from t1_notifs',
  'select id_notif_senior from test_notif_ids',
  'SENIOR vê as suas notificações');

select results_eq(
  'select id from t1_vouchers',
  'select id_voucher from test_voucher_id',
  'SENIOR vê o catálogo de vouchers');

select ok(
  (select count(*) from t1_sc where id_senior = (select id_senior from test_user_ids)) = 1,
  'SENIOR vê a sua relação com caretaker');

select results_eq(
  'select id from t1_evals',
  'select id_eval from test_eval_id',
  'SENIOR vê avaliações dos seus pedidos');

-- ==============================================================
-- BLOCO 2: VOLUNTEER
-- ==============================================================
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000002', 'role', 'authenticated')::text, true);
set local role authenticated;

create temp table t2_users      as select id from public.users;
create temp table t2_requests   as select id, state, id_volunteer from public.requests order by id;
create temp table t2_monitoring as select id from public.monitoring;
create temp table t2_notifs     as select id from public.notifications;
create temp table t2_vv         as select id_voucher from public.vouchers_volunteer;
create temp table t2_evals      as select id from public.evaluations;

reset role;

-- VOLUNTEER vê o seu perfil E o senior do pedido ACCEPTED (política users_volunteer_select_senior)
select ok(
  (select count(*) from t2_users where id = (select id_volunteer from test_user_ids)) = 1,
  'VOLUNTEER vê o seu próprio perfil');

select ok(
  (select count(*) from t2_users where id = (select id_senior from test_user_ids)) = 1,
  'VOLUNTEER vê o senior do pedido onde participa');

select ok(
  (select count(*) from t2_users where id not in (select id_volunteer from test_user_ids) and id != (select id_senior from test_user_ids)) = 0,
  'VOLUNTEER não vê outros utilizadores');

select ok(
  (select count(*) from t2_requests where state = 'PENDING') >= 1,
  'VOLUNTEER vê pedidos PENDING');

select ok(
  (select count(*) from t2_requests where id = (select id_req_accepted from test_request_ids)) = 1,
  'VOLUNTEER vê pedido ACCEPTED onde é executante');

select is_empty(
  'select id from t2_monitoring',
  'VOLUNTEER não vê monitoring de ninguém');

-- VOLUNTEER vê apenas a sua própria notificação (não vê notificações de seniors nem de outros)
select ok(
  (select count(*) from t2_notifs where id = (select id_notif_volunteer from test_notif_ids)) = 1,
  'VOLUNTEER vê a sua notificação');

select ok(
  (select count(*) from t2_notifs where id = (select id_notif_senior from test_notif_ids)) = 0,
  'VOLUNTEER não vê notificações do senior');

select results_eq(
  'select id_voucher from t2_vv',
  'select id_voucher from test_voucher_id',
  'VOLUNTEER vê a sua carteira de vouchers');

select results_eq(
  'select id from t2_evals',
  'select id_eval from test_eval_id',
  'VOLUNTEER vê avaliações onde participou');

-- ==============================================================
-- BLOCO 3: CARETAKER
-- ==============================================================
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000003', 'role', 'authenticated')::text, true);
set local role authenticated;

create temp table t3_users      as select id from public.users;
create temp table t3_requests   as select id, state from public.requests order by id;
create temp table t3_monitoring as select id from public.monitoring;
create temp table t3_sc         as select id_senior, id_caretaker from public.senior_caretaker;

reset role;

-- CARETAKER vê o seu perfil E o senior associado (política users_caretaker_select_seniors)
select ok(
  (select count(*) from t3_users where id = (select id_caretaker from test_user_ids)) = 1,
  'CARETAKER vê o seu próprio perfil');

select ok(
  (select count(*) from t3_users where id = (select id_senior from test_user_ids)) = 1,
  'CARETAKER vê o seu senior');

select ok(
  (select count(*) from t3_users where id not in (select id_caretaker from test_user_ids) and id != (select id_senior from test_user_ids)) = 0,
  'CARETAKER não vê outros utilizadores');

select ok(
  (select count(*) from t3_requests where state = 'PENDING') >= 1,
  'CARETAKER vê pedidos PENDING');

select results_eq(
  'select id from t3_monitoring',
  'select id_mon from test_monitoring_id',
  'CARETAKER vê monitoring do seu senior');

select ok(
  (select count(*) from t3_sc where id_caretaker = (select id_caretaker from test_user_ids)) = 1,
  'CARETAKER vê a sua relação com senior');

-- ==============================================================
-- BLOCO 4: SENIOR 2 — utilizador sem relações
-- ==============================================================
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000004', 'role', 'authenticated')::text, true);
set local role authenticated;

create temp table t4_users      as select id from public.users;
create temp table t4_requests   as select id from public.requests order by id;
create temp table t4_monitoring as select id from public.monitoring;
create temp table t4_notifs     as select id from public.notifications;
create temp table t4_evals      as select id from public.evaluations;
create temp table t4_sc         as select id_senior, id_caretaker from public.senior_caretaker;

reset role;

select results_eq(
  'select id from t4_users',
  'select id_senior2 from test_user_ids',
  'SENIOR2 vê só o seu perfil');

select results_eq(
  'select id from t4_requests',
  'select id_req_senior2 from test_request_ids',
  'SENIOR2 vê só o seu pedido');

select is_empty('select id from t4_monitoring',  'SENIOR2 não vê monitoring do SENIOR1');
select is_empty('select id from t4_notifs',      'SENIOR2 não vê notificações do SENIOR1');
select is_empty('select id from t4_evals',       'SENIOR2 não vê avaliações de outros');
select is_empty('select id_senior from t4_sc',   'SENIOR2 sem relação caretaker não vê senior_caretaker');

-- ==============================================================
-- FINALIZAR (como postgres)
-- ==============================================================
select * from finish();

rollback;
