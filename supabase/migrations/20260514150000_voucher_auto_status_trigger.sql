-- Trigger para atualizar automaticamente o status do voucher
-- UNAVAILABLE -> AVAILABLE quando current_tasks >= needed_tasks
-- Mantém UNAVAILABLE enquanto as tarefas não forem concluídas
-- Não altera vouchers com status 'USED' (já foram descontados)

CREATE OR REPLACE FUNCTION public.update_voucher_status()
RETURNS TRIGGER AS $$
DECLARE
  required_tasks integer;
BEGIN
  IF NEW.status = 'USED' THEN
    RETURN NEW;
  END IF;

  SELECT needed_tasks INTO required_tasks
  FROM public.vouchers
  WHERE id = NEW.id_voucher;

  IF NEW.current_tasks >= required_tasks THEN
    NEW.status := 'AVAILABLE';
  ELSE
    NEW.status := 'UNAVAILABLE';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_voucher_auto_status ON public.vouchers_volunteer;
CREATE TRIGGER trg_voucher_auto_status
BEFORE INSERT OR UPDATE ON public.vouchers_volunteer
FOR EACH ROW
EXECUTE FUNCTION public.update_voucher_status();
