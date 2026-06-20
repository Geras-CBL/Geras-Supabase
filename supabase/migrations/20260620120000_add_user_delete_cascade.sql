-- Adicionar ON DELETE CASCADE à foreign key auth_user_id em public.users
-- Quando um utilizador é eliminado de auth.users, o registo em public.users
-- (e todos os dados dependentes com CASCADE já configurados) são apagados automaticamente.

-- 1. Remover a constraint antiga (sem ON DELETE CASCADE)
ALTER TABLE public.users
  DROP CONSTRAINT IF EXISTS users_auth_user_id_fkey;

-- 1.5 Limpar eventuais registos órfãos que possam causar erro na criação da FK
DELETE FROM public.users
WHERE auth_user_id IS NOT NULL 
  AND auth_user_id NOT IN (SELECT id FROM auth.users);

-- 2. Recrear a constraint com ON DELETE CASCADE
-- Nota: auth_user_id é UUID que referencia auth.users(id)
ALTER TABLE public.users
  ADD CONSTRAINT users_auth_user_id_fkey
  FOREIGN KEY (auth_user_id)
  REFERENCES auth.users(id)
  ON DELETE CASCADE;
