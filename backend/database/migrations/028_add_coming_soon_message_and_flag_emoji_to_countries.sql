-- Adds optional coming soon message & flag emoji storage to countries
ALTER TABLE countries ADD COLUMN IF NOT EXISTS coming_soon_message TEXT;
ALTER TABLE countries ADD COLUMN IF NOT EXISTS flag_emoji VARCHAR(8);

-- Backfill: set flag_emoji from code where missing (simple 2-letter to emoji conversion in SQL via unicode math not trivial in pure SQL; leave null for app to compute)
-- Optionally set a default generic message for inactive countries if no custom message.
UPDATE countries
SET coming_soon_message = COALESCE(coming_soon_message, 'This country is coming soon. Please select an active country.')
WHERE is_active = false;
