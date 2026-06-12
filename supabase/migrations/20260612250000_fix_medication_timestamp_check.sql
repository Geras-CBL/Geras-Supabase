-- Fix: a coluna scheduled_time é TIMESTAMP, logo a comparação e conversão têm de ter isso em conta.
CREATE OR REPLACE FUNCTION public.check_medications()
RETURNS void AS $$
BEGIN
  INSERT INTO public.notifications (type, description, id_senior)
  SELECT 
    'medication',
    'Está na hora de tomar: ' || name,
    id_senior
  FROM public.medicine
  WHERE status = 'TO TAKE'
    -- Extrair a hora e minuto do scheduled_time e comparar com a hora e minuto atual
    AND to_char(scheduled_time, 'HH24:MI') = to_char(CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Lisbon', 'HH24:MI')
    -- E estar dentro da data de tratamento
    AND (start_date IS NULL OR start_date::date <= CURRENT_DATE)
    AND (end_date IS NULL OR end_date::date >= CURRENT_DATE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
