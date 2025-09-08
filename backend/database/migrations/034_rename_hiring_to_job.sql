-- Rename legacy 'hiring' request type to 'job' and update constraints

-- 1) Backfill data in requests.request_type and metadata where applicable
UPDATE requests
SET request_type = 'job'
WHERE request_type = 'hiring';

-- Optionally, update category request_type if categories used legacy markers
UPDATE categories
SET request_type = 'job_request'
WHERE request_type = 'hiring_request';

-- 2) Ensure CHECK constraint allows 'job'
DO $$
DECLARE
	v_conname text;
BEGIN
	SELECT pc.conname INTO v_conname
	FROM pg_constraint pc
	WHERE pc.conrelid = 'public.requests'::regclass AND pc.contype = 'c' AND pc.conname LIKE 'check_request_type%';

	IF v_conname IS NOT NULL THEN
		EXECUTE format('ALTER TABLE requests DROP CONSTRAINT %I', v_conname);
	END IF;
END$$ LANGUAGE plpgsql;

ALTER TABLE requests ADD CONSTRAINT check_request_type 
CHECK (request_type IN ('item', 'service', 'ride', 'rent', 'delivery', 'job'));

-- 3) Recreate trigger function to map category to request_type including job
CREATE OR REPLACE FUNCTION set_request_type_from_category()
RETURNS TRIGGER AS $$
BEGIN
		-- If request_type is not explicitly set, derive from category
		IF NEW.request_type IS NULL AND NEW.category_id IS NOT NULL THEN
				SELECT CASE 
						WHEN c.request_type = 'item_request' THEN 'item'
						WHEN c.request_type = 'service_request' THEN 'service'
						WHEN c.request_type = 'ride_request' THEN 'ride'
						WHEN c.request_type = 'rent_request' THEN 'rent'
						WHEN c.request_type = 'delivery_request' THEN 'delivery'
						WHEN c.request_type = 'job_request' THEN 'job'
						ELSE 'item'
				END INTO NEW.request_type
				FROM categories c 
				WHERE c.id = NEW.category_id;
		END IF;
    
		-- For ride requests without category
		IF NEW.request_type IS NULL AND NEW.category_id IS NULL 
			 AND NEW.metadata->>'type' LIKE '%ride%' THEN
				NEW.request_type := 'ride';
		END IF;
    
		-- Default fallback
		IF NEW.request_type IS NULL THEN
				NEW.request_type := 'item';
		END IF;
    
		RETURN NEW;
END;
$$ LANGUAGE plpgsql;

