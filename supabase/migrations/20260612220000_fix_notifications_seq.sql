-- Sincronizar a sequence da tabela notifications com o ID máximo atual
SELECT setval(
  pg_get_serial_sequence('public.notifications', 'id'),
  COALESCE(MAX(id), 1)
) FROM public.notifications;
