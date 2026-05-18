-- Migração para inserir dados de teste para a página Health
-- Data: 2026-04-28

DO $$
DECLARE
    target_senior_id integer;
BEGIN
    -- 1. Tentar encontrar o primeiro utilizador SENIOR na tabela public.users
    -- Se não houver nenhum, a migração não insere nada para evitar erros de FK.
    SELECT id INTO target_senior_id FROM public.users WHERE role = 'SENIOR' LIMIT 1;

    IF target_senior_id IS NOT NULL THEN
        RAISE NOTICE 'Inserindo dados para o utilizador senior ID: %', target_senior_id;

        -- 2. Inserir Medicamentos (tabela medicine)
        -- Nota: A coluna id_senior foi adicionada na migração 20260418115000_fix_groceries_medicine.sql
        INSERT INTO public.medicine (name, description, dosage, scheduled_time, status, id_senior)
        VALUES 
        ('Losartan', 'Para a pressão arterial', 50, (CURRENT_DATE + TIME '10:00:00')::timestamp, 'TO TAKE', target_senior_id),
        ('Multivitamínico', 'Suplemento diário', 1, (CURRENT_DATE + TIME '13:00:00')::timestamp, 'TO TAKE', target_senior_id),
        ('Atorvastatina', 'Para o colesterol', 20, (CURRENT_DATE + TIME '21:00:00')::timestamp, 'TO TAKE', target_senior_id)
        ON CONFLICT DO NOTHING;

        -- 3. Inserir Monitorização (tabela monitoring)
        INSERT INTO public.monitoring (id_senior, custom_metric_name, custom_metric_value, type, value)
        VALUES 
        (target_senior_id, 'Pressão Arterial', 12.8, 'BLOOD PRESSURE', 12.8),
        (target_senior_id, 'Ritmo Cardíaco', 72, 'HEART RATE', 72)
        ON CONFLICT DO NOTHING;

        -- 4. Inserir Notificações (tabela notifications)
        INSERT INTO public.notifications (description, type, id_senior)
        VALUES 
        ('Hora de tomar o seu medicamento da manhã (Losartan).', 'medication', target_senior_id),
        ('A consulta com o Dr. Manuel é amanhã às 15:30.', 'appointment', target_senior_id)
        ON CONFLICT DO NOTHING;

    ELSE
        RAISE WARNING 'Nenhum utilizador SENIOR encontrado na tabela public.users. Por favor, crie um utilizador primeiro.';
    END IF;
END $$;
