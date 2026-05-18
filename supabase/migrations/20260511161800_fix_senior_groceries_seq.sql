-- Fix senior_groceries ID sequence 
-- This fixes the "duplicate key value violates unique constraint 'senior_groceries_pkey'" error
-- caused by manual insertions with hardcoded IDs that leave the sequence behind.

SELECT setval('senior_groceries_id_seq', COALESCE((SELECT MAX(id) FROM public.senior_groceries), 1), true);
SELECT setval('requests_id_seq', COALESCE((SELECT MAX(id) FROM public.requests), 1), true);
