-- ==============================================================
-- Atualizar o trigger sync_user_auth_id para fazer INSERT
-- de novos utilizadores com base nos metadados do Supabase Auth.
-- ==============================================================

create or replace function public.sync_user_auth_id()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Faz o INSERT. O raw_user_meta_data é enviado do Frontend no signUp.
  insert into public.users (
    auth_user_id, 
    email, 
    password_hash, 
    name, 
    role
  )
  values (
    new.id,
    new.email,
    'handled_by_supabase_auth', -- Campo obrigatório na DB, mas inutilizado
    coalesce(new.raw_user_meta_data->>'name', 'Sem Nome'),
    cast(coalesce(new.raw_user_meta_data->>'role', 'SENIOR') as public.user_role)
  )
  on conflict (email) do update
  set auth_user_id = excluded.auth_user_id,
      name = excluded.name,
      role = excluded.role;

  return new;
end;
$$;
