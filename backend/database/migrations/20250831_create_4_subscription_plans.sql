-- Insert the 4 subscription plans for all countries
-- Clear existing plans first
DELETE FROM subscription_plans WHERE code IN ('pro_responder', 'pro_driver', 'pro_seller_monthly', 'pro_seller_ppc');

-- 1. Pro Responder - Monthly 5000
INSERT INTO subscription_plans (code, name, description, plan_type, default_responses_per_month, status)
VALUES (
  'pro_responder',
  'Pro Responder',
  'Unlimited responses for general businesses - Monthly Rs 5000',
  'unlimited',
  NULL,
  'active'
);

-- 2. Pro Driver - Monthly 7500  
INSERT INTO subscription_plans (code, name, description, plan_type, default_responses_per_month, status)
VALUES (
  'pro_driver',
  'Pro Driver',
  'Unlimited responses for drivers (ride + common requests) - Monthly Rs 7500',
  'unlimited',
  NULL,
  'active'
);

-- 3. Pro Seller Monthly - Monthly 4500
INSERT INTO subscription_plans (code, name, description, plan_type, default_responses_per_month, status)
VALUES (
  'pro_seller_monthly',
  'Pro Seller Monthly',
  'Unlimited responses + price comparison access - Monthly Rs 4500',
  'unlimited',
  NULL,
  'active'
);

-- 4. Pro Seller PPC - Pay per click 100
INSERT INTO subscription_plans (code, name, description, plan_type, default_responses_per_month, status)
VALUES (
  'pro_seller_ppc',
  'Pro Seller PPC',
  'Pay per click for price comparison - Rs 100 per click',
  'ppc',
  3,
  'active'
);
