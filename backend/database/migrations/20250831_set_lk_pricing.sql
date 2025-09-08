-- Set pricing for Sri Lanka (LK) for all 4 plans
-- Clear existing LK pricing
DELETE FROM subscription_country_settings WHERE country_code = 'LK';

-- Get plan IDs
DO $$
DECLARE
    pro_responder_id INTEGER;
    pro_driver_id INTEGER;
    pro_seller_monthly_id INTEGER;
    pro_seller_ppc_id INTEGER;
BEGIN
    -- Get plan IDs
    SELECT id INTO pro_responder_id FROM subscription_plans WHERE code = 'pro_responder';
    SELECT id INTO pro_driver_id FROM subscription_plans WHERE code = 'pro_driver';
    SELECT id INTO pro_seller_monthly_id FROM subscription_plans WHERE code = 'pro_seller_monthly';
    SELECT id INTO pro_seller_ppc_id FROM subscription_plans WHERE code = 'pro_seller_ppc';

    -- Insert pricing for LK
    -- Pro Responder - Rs 5000/month
    INSERT INTO subscription_country_settings (plan_id, country_code, currency, price, responses_per_month, ppc_price, is_active)
    VALUES (pro_responder_id, 'LK', 'LKR', 5000.00, NULL, NULL, true);

    -- Pro Driver - Rs 7500/month
    INSERT INTO subscription_country_settings (plan_id, country_code, currency, price, responses_per_month, ppc_price, is_active)
    VALUES (pro_driver_id, 'LK', 'LKR', 7500.00, NULL, NULL, true);

    -- Pro Seller Monthly - Rs 4500/month
    INSERT INTO subscription_country_settings (plan_id, country_code, currency, price, responses_per_month, ppc_price, is_active)
    VALUES (pro_seller_monthly_id, 'LK', 'LKR', 4500.00, NULL, NULL, true);

    -- Pro Seller PPC - Rs 100/click
    INSERT INTO subscription_country_settings (plan_id, country_code, currency, price, responses_per_month, ppc_price, is_active)
    VALUES (pro_seller_ppc_id, 'LK', 'LKR', NULL, 3, 100.00, true);

END $$;
