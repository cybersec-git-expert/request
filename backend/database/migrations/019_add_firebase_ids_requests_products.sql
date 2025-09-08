-- Add firebase_id columns + unique indexes for requests, master_products, business_products
-- Idempotent and safe to re-run

ALTER TABLE requests ADD COLUMN IF NOT EXISTS firebase_id VARCHAR(255);
ALTER TABLE master_products ADD COLUMN IF NOT EXISTS firebase_id VARCHAR(255);
ALTER TABLE business_products ADD COLUMN IF NOT EXISTS firebase_id VARCHAR(255);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='requests_firebase_id_key') THEN
    EXECUTE 'CREATE UNIQUE INDEX requests_firebase_id_key ON requests(firebase_id)';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='master_products_firebase_id_key') THEN
    EXECUTE 'CREATE UNIQUE INDEX master_products_firebase_id_key ON master_products(firebase_id)';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='business_products_firebase_id_key') THEN
    EXECUTE 'CREATE UNIQUE INDEX business_products_firebase_id_key ON business_products(firebase_id)';
  END IF;
END$$;
