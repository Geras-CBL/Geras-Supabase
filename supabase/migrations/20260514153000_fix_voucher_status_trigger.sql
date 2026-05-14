-- FIX: Cast explícito para text na comparação do enum
-- O trigger anterior não reconhecia 'USED' porque o enum não era comparado corretamente

CREATE OR REPLACE FUNCTION public.update_voucher_status()
RETURNS TRIGGER AS $$
DECLARE
  required_tasks integer;
BEGIN
  -- Não mexer em vouchers já utilizados (cast para text para garantir comparação correta)
  IF NEW.status::text = 'USED' THEN
    RETURN NEW;
  END IF;

  -- Buscar o número de tarefas necessárias
  SELECT needed_tasks INTO required_tasks
  FROM public.vouchers
  WHERE id = NEW.id_voucher;

  -- Atualizar o status com base no progresso
  IF NEW.current_tasks >= required_tasks THEN
    NEW.status := 'AVAILABLE';
  ELSE
    NEW.status := 'UNAVAILABLE';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
