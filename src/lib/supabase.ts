import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.SUPABASE_URL || '';
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY || '';

if (!supabaseUrl || !supabaseAnonKey) {
  console.error("ERRO: SUPABASE_URL ou SUPABASE_ANON_KEY não estão definidas no .env");
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey);
