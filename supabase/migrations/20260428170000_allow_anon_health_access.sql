-- Migração para permitir acesso anónimo (leitura) às tabelas de saúde
-- Útil enquanto o sistema de login não está finalizado.

-- 1. Permitir SELECT anónimo na tabela medicine
DROP POLICY IF EXISTS "Allow anon select on medicine" ON public.medicine;
CREATE POLICY "Allow anon select on medicine" 
ON public.medicine FOR SELECT 
TO anon 
USING (true);

-- 2. Permitir SELECT anónimo na tabela monitoring
DROP POLICY IF EXISTS "Allow anon select on monitoring" ON public.monitoring;
CREATE POLICY "Allow anon select on monitoring" 
ON public.monitoring FOR SELECT 
TO anon 
USING (true);

-- 3. Permitir SELECT anónimo na tabela notifications
DROP POLICY IF EXISTS "Allow anon select on notifications" ON public.notifications;
CREATE POLICY "Allow anon select on notifications" 
ON public.notifications FOR SELECT 
TO anon 
USING (true);

-- Garantir que o RLS está ativo (caso não esteja)
ALTER TABLE public.medicine ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.monitoring ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Dar permissão explicita de SELECT ao role anon (por vezes necessário dependendo da config do schema)
GRANT SELECT ON public.medicine TO anon;
GRANT SELECT ON public.monitoring TO anon;
GRANT SELECT ON public.notifications TO anon;
