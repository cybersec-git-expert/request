-- Add per-country capability toggles to country_business_types
-- Safe to re-run; uses IF NOT EXISTS

ALTER TABLE IF EXISTS country_business_types
  ADD COLUMN IF NOT EXISTS can_manage_prices boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS can_respond_item boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS can_respond_service boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS can_respond_rent boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS can_respond_tours boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS can_respond_events boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS can_respond_construction boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS can_respond_education boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS can_respond_hiring boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS can_respond_delivery boolean DEFAULT false;

-- Backfill sensible defaults by name if columns were just created
-- Product Seller manages prices; Delivery responds to delivery
UPDATE country_business_types
SET can_manage_prices = true
WHERE LOWER(name) = 'product seller';

UPDATE country_business_types
SET can_respond_delivery = true
WHERE LOWER(name) IN ('delivery','delivery service');
