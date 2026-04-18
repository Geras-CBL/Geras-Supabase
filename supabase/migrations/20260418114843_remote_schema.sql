


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."eval_rate" AS ENUM (
    'SATISFIED',
    'NEUTRAL',
    'DISSATISFIED'
);


ALTER TYPE "public"."eval_rate" OWNER TO "postgres";


CREATE TYPE "public"."med_status" AS ENUM (
    'LATE',
    'ALREADY TAKEN',
    'TO TAKE'
);


ALTER TYPE "public"."med_status" OWNER TO "postgres";


CREATE TYPE "public"."req_state" AS ENUM (
    'PENDING',
    'ACCEPTED',
    'COMPLETED',
    'CANCELLED'
);


ALTER TYPE "public"."req_state" OWNER TO "postgres";


CREATE TYPE "public"."type_monitoring" AS ENUM (
    'BLOOD PRESSURE',
    'HEART RATE',
    'TEMPERATURE'
);


ALTER TYPE "public"."type_monitoring" OWNER TO "postgres";


CREATE TYPE "public"."user_gender" AS ENUM (
    'FEMALE',
    'MALE',
    'NON-BINARY',
    'PREFER NOT TO SAY'
);


ALTER TYPE "public"."user_gender" OWNER TO "postgres";


CREATE TYPE "public"."user_role" AS ENUM (
    'SENIOR',
    'CARETAKER',
    'VOLUNTEER'
);


ALTER TYPE "public"."user_role" OWNER TO "postgres";


CREATE TYPE "public"."vouch_status" AS ENUM (
    'AVAILABLE',
    'UNAVAILABLE',
    'EXPIRED'
);


ALTER TYPE "public"."vouch_status" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rls_auto_enable"() RETURNS "event_trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."rls_auto_enable"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."evaluations" (
    "id" integer NOT NULL,
    "description" character varying,
    "evaluation" "public"."eval_rate" NOT NULL,
    "id_senior" integer,
    "id_volunteer" integer,
    "id_request" integer
);


ALTER TABLE "public"."evaluations" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."evaluations_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."evaluations_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."evaluations_id_seq" OWNED BY "public"."evaluations"."id";



CREATE TABLE IF NOT EXISTS "public"."groceries" (
    "id" integer NOT NULL,
    "name" character varying NOT NULL,
    "category" character varying,
    "unit" integer,
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."groceries" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."groceries_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."groceries_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."groceries_id_seq" OWNED BY "public"."groceries"."id";



CREATE TABLE IF NOT EXISTS "public"."medicine" (
    "id" integer NOT NULL,
    "name" character varying NOT NULL,
    "description" character varying,
    "dosage" numeric,
    "frequency" integer,
    "start_date" "date",
    "end_date" "date",
    "scheduled_time" timestamp without time zone,
    "status" "public"."med_status",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."medicine" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."medicine_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."medicine_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."medicine_id_seq" OWNED BY "public"."medicine"."id";



CREATE TABLE IF NOT EXISTS "public"."monitoring" (
    "id" integer NOT NULL,
    "id_senior" integer,
    "custom_metric_name" character varying,
    "custom_metric_value" numeric,
    "type" "public"."type_monitoring",
    "value" numeric
);


ALTER TABLE "public"."monitoring" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."monitoring_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."monitoring_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."monitoring_id_seq" OWNED BY "public"."monitoring"."id";



CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" integer NOT NULL,
    "type" character varying,
    "description" character varying NOT NULL,
    "id_senior" integer,
    "id_caretaker" integer,
    "id_volunteer" integer
);


ALTER TABLE "public"."notifications" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."notifications_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."notifications_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."notifications_id_seq" OWNED BY "public"."notifications"."id";



CREATE TABLE IF NOT EXISTS "public"."request_item" (
    "id" integer NOT NULL,
    "id_request" integer,
    "id_groceries" integer,
    "id_medicine" integer,
    CONSTRAINT "chk_exclusive_item" CHECK (((("id_groceries" IS NOT NULL) AND ("id_medicine" IS NULL)) OR (("id_groceries" IS NULL) AND ("id_medicine" IS NOT NULL))))
);


ALTER TABLE "public"."request_item" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."request_item_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."request_item_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."request_item_id_seq" OWNED BY "public"."request_item"."id";



CREATE TABLE IF NOT EXISTS "public"."requests" (
    "id" integer NOT NULL,
    "category" character varying,
    "distance" double precision,
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"(),
    "location_address" character varying,
    "description" character varying,
    "state" "public"."req_state" DEFAULT 'PENDING'::"public"."req_state",
    "id_senior" integer,
    "id_caretaker" integer,
    "id_volunteer" integer
);


ALTER TABLE "public"."requests" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."requests_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."requests_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."requests_id_seq" OWNED BY "public"."requests"."id";



CREATE TABLE IF NOT EXISTS "public"."senior_caretaker" (
    "id_senior" integer NOT NULL,
    "id_caretaker" integer NOT NULL
);


ALTER TABLE "public"."senior_caretaker" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users" (
    "id" integer NOT NULL,
    "email" character varying NOT NULL,
    "password_hash" "text" NOT NULL,
    "name" character varying NOT NULL,
    "role" "public"."user_role" NOT NULL,
    "gender" "public"."user_gender",
    "address" character varying,
    "zip_code" character varying,
    "local" character varying,
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"(),
    "action_radius" double precision,
    "rating" double precision,
    "profile_picture" json
);


ALTER TABLE "public"."users" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."users_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."users_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."users_id_seq" OWNED BY "public"."users"."id";



CREATE TABLE IF NOT EXISTS "public"."vouchers" (
    "id" integer NOT NULL,
    "store_name" character varying NOT NULL,
    "address" character varying,
    "zip_code" character varying,
    "value" numeric NOT NULL,
    "needed_tasks" integer
);


ALTER TABLE "public"."vouchers" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."vouchers_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."vouchers_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."vouchers_id_seq" OWNED BY "public"."vouchers"."id";



CREATE TABLE IF NOT EXISTS "public"."vouchers_volunteer" (
    "id_voucher" integer NOT NULL,
    "id_volunteer" integer NOT NULL,
    "status" "public"."vouch_status" DEFAULT 'AVAILABLE'::"public"."vouch_status"
);


ALTER TABLE "public"."vouchers_volunteer" OWNER TO "postgres";


ALTER TABLE ONLY "public"."evaluations" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."evaluations_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."groceries" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."groceries_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."medicine" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."medicine_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."monitoring" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."monitoring_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."notifications" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."notifications_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."request_item" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."request_item_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."requests" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."requests_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."users" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."users_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."vouchers" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."vouchers_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."evaluations"
    ADD CONSTRAINT "evaluations_id_key" UNIQUE ("id");



ALTER TABLE ONLY "public"."evaluations"
    ADD CONSTRAINT "evaluations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."groceries"
    ADD CONSTRAINT "groceries_id_key" UNIQUE ("id");



ALTER TABLE ONLY "public"."groceries"
    ADD CONSTRAINT "groceries_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."medicine"
    ADD CONSTRAINT "medicine_id_key" UNIQUE ("id");



ALTER TABLE ONLY "public"."medicine"
    ADD CONSTRAINT "medicine_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."monitoring"
    ADD CONSTRAINT "monitoring_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."request_item"
    ADD CONSTRAINT "request_item_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."requests"
    ADD CONSTRAINT "requests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."senior_caretaker"
    ADD CONSTRAINT "senior_caretaker_pkey" PRIMARY KEY ("id_senior", "id_caretaker");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vouchers"
    ADD CONSTRAINT "vouchers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vouchers_volunteer"
    ADD CONSTRAINT "vouchers_volunteer_pkey" PRIMARY KEY ("id_voucher", "id_volunteer");



ALTER TABLE ONLY "public"."evaluations"
    ADD CONSTRAINT "evaluations_id_request_fkey" FOREIGN KEY ("id_request") REFERENCES "public"."requests"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."evaluations"
    ADD CONSTRAINT "evaluations_id_senior_fkey" FOREIGN KEY ("id_senior") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."evaluations"
    ADD CONSTRAINT "evaluations_id_volunteer_fkey" FOREIGN KEY ("id_volunteer") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."monitoring"
    ADD CONSTRAINT "monitoring_id_senior_fkey" FOREIGN KEY ("id_senior") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_id_caretaker_fkey" FOREIGN KEY ("id_caretaker") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_id_senior_fkey" FOREIGN KEY ("id_senior") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_id_volunteer_fkey" FOREIGN KEY ("id_volunteer") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."request_item"
    ADD CONSTRAINT "request_item_id_groceries_fkey" FOREIGN KEY ("id_groceries") REFERENCES "public"."groceries"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."request_item"
    ADD CONSTRAINT "request_item_id_medicine_fkey" FOREIGN KEY ("id_medicine") REFERENCES "public"."medicine"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."request_item"
    ADD CONSTRAINT "request_item_id_request_fkey" FOREIGN KEY ("id_request") REFERENCES "public"."requests"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."requests"
    ADD CONSTRAINT "requests_id_caretaker_fkey" FOREIGN KEY ("id_caretaker") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."requests"
    ADD CONSTRAINT "requests_id_senior_fkey" FOREIGN KEY ("id_senior") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."requests"
    ADD CONSTRAINT "requests_id_volunteer_fkey" FOREIGN KEY ("id_volunteer") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."senior_caretaker"
    ADD CONSTRAINT "senior_caretaker_id_caretaker_fkey" FOREIGN KEY ("id_caretaker") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."senior_caretaker"
    ADD CONSTRAINT "senior_caretaker_id_senior_fkey" FOREIGN KEY ("id_senior") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."vouchers_volunteer"
    ADD CONSTRAINT "vouchers_volunteer_id_volunteer_fkey" FOREIGN KEY ("id_volunteer") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."vouchers_volunteer"
    ADD CONSTRAINT "vouchers_volunteer_id_voucher_fkey" FOREIGN KEY ("id_voucher") REFERENCES "public"."vouchers"("id") ON DELETE CASCADE;



ALTER TABLE "public"."evaluations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."groceries" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."medicine" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."monitoring" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."request_item" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."requests" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."senior_caretaker" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."vouchers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."vouchers_volunteer" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

























































































































































GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "anon";
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "service_role";


















GRANT ALL ON TABLE "public"."evaluations" TO "anon";
GRANT ALL ON TABLE "public"."evaluations" TO "authenticated";
GRANT ALL ON TABLE "public"."evaluations" TO "service_role";



GRANT ALL ON SEQUENCE "public"."evaluations_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."evaluations_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."evaluations_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."groceries" TO "anon";
GRANT ALL ON TABLE "public"."groceries" TO "authenticated";
GRANT ALL ON TABLE "public"."groceries" TO "service_role";



GRANT ALL ON SEQUENCE "public"."groceries_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."groceries_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."groceries_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."medicine" TO "anon";
GRANT ALL ON TABLE "public"."medicine" TO "authenticated";
GRANT ALL ON TABLE "public"."medicine" TO "service_role";



GRANT ALL ON SEQUENCE "public"."medicine_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."medicine_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."medicine_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."monitoring" TO "anon";
GRANT ALL ON TABLE "public"."monitoring" TO "authenticated";
GRANT ALL ON TABLE "public"."monitoring" TO "service_role";



GRANT ALL ON SEQUENCE "public"."monitoring_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."monitoring_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."monitoring_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."notifications" TO "anon";
GRANT ALL ON TABLE "public"."notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."notifications" TO "service_role";



GRANT ALL ON SEQUENCE "public"."notifications_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."notifications_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."notifications_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."request_item" TO "anon";
GRANT ALL ON TABLE "public"."request_item" TO "authenticated";
GRANT ALL ON TABLE "public"."request_item" TO "service_role";



GRANT ALL ON SEQUENCE "public"."request_item_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."request_item_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."request_item_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."requests" TO "anon";
GRANT ALL ON TABLE "public"."requests" TO "authenticated";
GRANT ALL ON TABLE "public"."requests" TO "service_role";



GRANT ALL ON SEQUENCE "public"."requests_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."requests_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."requests_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."senior_caretaker" TO "anon";
GRANT ALL ON TABLE "public"."senior_caretaker" TO "authenticated";
GRANT ALL ON TABLE "public"."senior_caretaker" TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";



GRANT ALL ON SEQUENCE "public"."users_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."users_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."users_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."vouchers" TO "anon";
GRANT ALL ON TABLE "public"."vouchers" TO "authenticated";
GRANT ALL ON TABLE "public"."vouchers" TO "service_role";



GRANT ALL ON SEQUENCE "public"."vouchers_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."vouchers_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."vouchers_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."vouchers_volunteer" TO "anon";
GRANT ALL ON TABLE "public"."vouchers_volunteer" TO "authenticated";
GRANT ALL ON TABLE "public"."vouchers_volunteer" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";



































drop extension if exists "pg_net";


