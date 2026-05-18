-- Sync the sequence for evaluations table to avoid duplicate key errors
SELECT setval('public.evaluations_id_seq', coalesce((SELECT MAX(id) FROM public.evaluations), 0) + 1, false);
