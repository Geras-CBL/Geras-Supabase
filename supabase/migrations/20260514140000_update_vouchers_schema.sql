-- Adicionar status 'USED' ao enum public.vouch_status
-- Nota: ALTER TYPE ADD VALUE não pode ser executado dentro de um bloco transacional em algumas versões do Postgres.
ALTER TYPE public.vouch_status ADD VALUE IF NOT EXISTS 'USED';

-- Adicionar coluna de progresso (current_tasks) à tabela vouchers_volunteer
ALTER TABLE public.vouchers_volunteer ADD COLUMN IF NOT EXISTS current_tasks integer DEFAULT 0;
