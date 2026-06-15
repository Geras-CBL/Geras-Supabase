-- Add phone number column to users table
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS phone text;
