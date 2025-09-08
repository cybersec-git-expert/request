-- Seed a minimal set of subscription plans if table is empty
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM subscription_plans_new) THEN
    INSERT INTO subscription_plans_new (code, name, type, plan_type, description, price, currency, duration_days, features, limitations, is_active, is_default_plan)
    VALUES
  ('free', 'Free', 'rider', 'monthly', 'Free tier with 3 monthly responses', 0, 'LKR', 30, '[]'::jsonb, '{"response_limit": 3}'::jsonb, true, true),
  ('rider_10', '10 Responses', 'rider', 'monthly', '10 responses per month with notifications & contact', 5000, 'LKR', 30, '[]'::jsonb, '{"response_limit": 10, "notifications": true, "show_contact": true}'::jsonb, true, false),
  ('rider_unlimited', 'Unlimited', 'rider', 'monthly', 'Unlimited monthly responses with notifications & contact', 10000, 'LKR', 30, '[]'::jsonb, '{"response_limit": -1, "notifications": true, "show_contact": true}'::jsonb, true, false),
      ('business_ppc', 'Business PPC', 'business', 'pay_per_click', 'Pay-per-click for businesses', 0, 'LKR', 30, '["PPC billing"]'::jsonb, '{}'::jsonb, true, false),
      ('business_monthly', 'Business Monthly', 'business', 'monthly', 'Monthly subscription for businesses', 4990, 'LKR', 30, '["Lead access","Business tools"]'::jsonb, '{}'::jsonb, true, false);
  END IF;
END$$;
