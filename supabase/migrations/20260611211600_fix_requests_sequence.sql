-- Fix the sequence for requests table
SELECT setval('requests_id_seq', COALESCE((SELECT MAX(id) FROM public.requests), 1), true);
