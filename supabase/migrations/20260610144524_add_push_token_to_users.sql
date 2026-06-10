-- Adicionar coluna push_token à tabela users
-- Necessário para futuras notificações push remotas (com app fechada)
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS push_token text;
