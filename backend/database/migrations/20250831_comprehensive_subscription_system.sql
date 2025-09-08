-- Comprehensive Subscription System for Request Marketplace
-- Handles: General Business, Drivers, Delivery, Product Sellers
-- Multiple subscription tiers and request type access control

-- 1. Subscription Plans (Global Templates)
DROP TABLE IF EXISTS subscription_plans CASCADE;
CREATE TABLE subscription_plans (
  id SERIAL PRIMARY KEY,
  code VARCHAR(50) UNIQUE NOT NULL, -- basic, unlimited, ppc, bundle
  name VARCHAR(100) NOT NULL,
  plan_type VARCHAR(20) NOT NULL, -- 'free', 'unlimited', 'ppc', 'bundle'
  description TEXT,
  default_responses_per_month INTEGER DEFAULT 3,
  status VARCHAR(20) DEFAULT 'pending', -- pending, active, inactive
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Insert default plans
INSERT INTO subscription_plans (code, name, plan_type, default_responses_per_month, status) VALUES
('free', 'Free Plan', 'free', 3, 'active'),
('unlimited', 'Monthly Unlimited', 'unlimited', -1, 'active'),
('ppc', 'Pay Per Click', 'ppc', 3, 'active'),
('bundle', 'PPC + Unlimited Bundle', 'bundle', -1, 'active');

-- 2. Business Type Categories
DROP TABLE IF EXISTS business_type_categories CASCADE;
CREATE TABLE business_type_categories (
  id SERIAL PRIMARY KEY,
  code VARCHAR(50) UNIQUE NOT NULL,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  requires_special_registration BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO business_type_categories (code, name, requires_special_registration) VALUES
('general', 'General Business', FALSE),
('driver', 'Driver/Transport', TRUE),
('delivery', 'Delivery Service', TRUE),
('product_seller', 'Product Seller', TRUE);

-- 3. Request Types
DROP TABLE IF EXISTS request_types CASCADE;
CREATE TABLE request_types (
  id SERIAL PRIMARY KEY,
  code VARCHAR(50) UNIQUE NOT NULL,
  name VARCHAR(100) NOT NULL,
  is_common BOOLEAN DEFAULT TRUE, -- common requests available to all
  restricted_to_category VARCHAR(50), -- NULL for common, specific category for restricted
  created_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO request_types (code, name, is_common, restricted_to_category) VALUES
('item', 'Item Request', TRUE, NULL),
('service', 'Service Request', TRUE, NULL),
('rent', 'Rental Request', TRUE, NULL),
('tour', 'Tour Request', TRUE, NULL),
('construction', 'Construction Request', TRUE, NULL),
('education', 'Education Request', TRUE, NULL),
('hiring', 'Hiring Request', TRUE, NULL),
('event', 'Event Request', TRUE, NULL),
('other', 'Other Request', TRUE, NULL),
('ride', 'Ride Request', FALSE, 'driver'),
('delivery', 'Delivery Request', FALSE, 'delivery');

-- 4. Country-specific subscription pricing
DROP TABLE IF EXISTS subscription_country_settings CASCADE;
CREATE TABLE subscription_country_settings (
  id SERIAL PRIMARY KEY,
  plan_id INTEGER REFERENCES subscription_plans(id) ON DELETE CASCADE,
  country_code VARCHAR(10) NOT NULL,
  currency VARCHAR(10) NOT NULL,
  monthly_price NUMERIC(12,2), -- for unlimited/bundle plans
  ppc_price NUMERIC(12,3), -- per-click price for ppc/bundle plans
  responses_per_month INTEGER, -- override default if needed
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(plan_id, country_code)
);

-- 5. Business registration with subscription
DROP TABLE IF EXISTS business_subscriptions CASCADE;
CREATE TABLE business_subscriptions (
  id SERIAL PRIMARY KEY,
  business_id UUID NOT NULL, -- Reference to existing business table
  country_code VARCHAR(10) NOT NULL,
  business_category VARCHAR(50) REFERENCES business_type_categories(code),
  plan_id INTEGER REFERENCES subscription_plans(id),
  
  -- Subscription details
  subscription_status VARCHAR(20) DEFAULT 'active', -- active, suspended, cancelled
  responses_used_this_month INTEGER DEFAULT 0,
  monthly_limit INTEGER, -- copied from plan, can be overridden
  has_unlimited_responses BOOLEAN DEFAULT FALSE,
  has_contact_access BOOLEAN DEFAULT FALSE,
  has_messaging_access BOOLEAN DEFAULT FALSE,
  
  -- Billing
  current_period_start DATE,
  current_period_end DATE,
  next_billing_date DATE,
  
  -- Interest areas for notifications (for tour, event, etc.)
  notification_interests TEXT[], -- array of request_type codes
  
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(business_id)
);

-- 6. Request type access permissions per business
DROP TABLE IF EXISTS business_request_permissions CASCADE;
CREATE TABLE business_request_permissions (
  id SERIAL PRIMARY KEY,
  business_subscription_id INTEGER REFERENCES business_subscriptions(id) ON DELETE CASCADE,
  request_type_code VARCHAR(50) REFERENCES request_types(code),
  can_respond BOOLEAN DEFAULT TRUE,
  requires_subscription BOOLEAN DEFAULT FALSE, -- if true, needs active paid plan
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(business_subscription_id, request_type_code)
);

-- 7. Response tracking for limits
DROP TABLE IF EXISTS business_response_tracking CASCADE;
CREATE TABLE business_response_tracking (
  id SERIAL PRIMARY KEY,
  business_id UUID NOT NULL,
  request_id UUID NOT NULL, -- Reference to the request they responded to
  request_type_code VARCHAR(50),
  response_date DATE DEFAULT CURRENT_DATE,
  was_free_response BOOLEAN DEFAULT TRUE,
  ppc_charge NUMERIC(12,3), -- if this was a paid PPC response
  created_at TIMESTAMP DEFAULT NOW()
);

-- 8. Create indexes for performance
CREATE INDEX idx_business_subscriptions_business_id ON business_subscriptions(business_id);
CREATE INDEX idx_business_subscriptions_country ON business_subscriptions(country_code);
CREATE INDEX idx_business_response_tracking_business ON business_response_tracking(business_id, response_date);
CREATE INDEX idx_business_response_tracking_date ON business_response_tracking(response_date);

-- 9. Functions to check permissions and limits

-- Function to check if business can respond to a request type
CREATE OR REPLACE FUNCTION can_business_respond_to_request(
  p_business_id UUID,
  p_request_type VARCHAR(50)
) RETURNS TABLE(
  can_respond BOOLEAN,
  needs_upgrade BOOLEAN,
  responses_remaining INTEGER,
  message TEXT
) AS $$
DECLARE
  v_subscription business_subscriptions%ROWTYPE;
  v_request_type request_types%ROWTYPE;
  v_permission business_request_permissions%ROWTYPE;
  v_responses_this_month INTEGER;
BEGIN
  -- Get business subscription
  SELECT * INTO v_subscription FROM business_subscriptions WHERE business_id = p_business_id;
  
  IF NOT FOUND THEN
    RETURN QUERY SELECT FALSE, TRUE, 0, 'No subscription found'::TEXT;
    RETURN;
  END IF;
  
  -- Get request type info
  SELECT * INTO v_request_type FROM request_types WHERE code = p_request_type;
  
  IF NOT FOUND THEN
    RETURN QUERY SELECT FALSE, FALSE, 0, 'Invalid request type'::TEXT;
    RETURN;
  END IF;
  
  -- Check if request type is restricted to specific business category
  IF v_request_type.restricted_to_category IS NOT NULL AND 
     v_request_type.restricted_to_category != v_subscription.business_category THEN
    RETURN QUERY SELECT FALSE, FALSE, 0, 'Request type not available for your business category'::TEXT;
    RETURN;
  END IF;
  
  -- Check specific permissions
  SELECT * INTO v_permission 
  FROM business_request_permissions 
  WHERE business_subscription_id = v_subscription.id AND request_type_code = p_request_type;
  
  IF FOUND AND NOT v_permission.can_respond THEN
    RETURN QUERY SELECT FALSE, FALSE, 0, 'No permission for this request type'::TEXT;
    RETURN;
  END IF;
  
  -- Check subscription limits
  IF v_subscription.has_unlimited_responses THEN
    RETURN QUERY SELECT TRUE, FALSE, -1, 'Unlimited responses available'::TEXT;
    RETURN;
  END IF;
  
  -- Count responses this month
  SELECT COUNT(*) INTO v_responses_this_month
  FROM business_response_tracking
  WHERE business_id = p_business_id 
    AND response_date >= v_subscription.current_period_start
    AND response_date <= v_subscription.current_period_end;
  
  IF v_responses_this_month >= v_subscription.monthly_limit THEN
    RETURN QUERY SELECT FALSE, TRUE, 0, 'Monthly response limit reached. Upgrade to continue.'::TEXT;
    RETURN;
  END IF;
  
  RETURN QUERY SELECT TRUE, FALSE, (v_subscription.monthly_limit - v_responses_this_month), 'Response allowed'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- Function to setup default permissions when business subscribes
CREATE OR REPLACE FUNCTION setup_business_permissions(p_business_subscription_id INTEGER)
RETURNS VOID AS $$
DECLARE
  v_subscription business_subscriptions%ROWTYPE;
  v_request_type request_types%ROWTYPE;
BEGIN
  SELECT * INTO v_subscription FROM business_subscriptions WHERE id = p_business_subscription_id;
  
  -- Give access to all common request types
  FOR v_request_type IN SELECT * FROM request_types WHERE is_common = TRUE LOOP
    INSERT INTO business_request_permissions (business_subscription_id, request_type_code, can_respond)
    VALUES (p_business_subscription_id, v_request_type.code, TRUE)
    ON CONFLICT (business_subscription_id, request_type_code) DO NOTHING;
  END LOOP;
  
  -- Give access to category-specific request types
  FOR v_request_type IN 
    SELECT * FROM request_types 
    WHERE restricted_to_category = v_subscription.business_category LOOP
    
    INSERT INTO business_request_permissions (business_subscription_id, request_type_code, can_respond)
    VALUES (p_business_subscription_id, v_request_type.code, TRUE)
    ON CONFLICT (business_subscription_id, request_type_code) DO NOTHING;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Trigger to setup permissions when subscription is created
CREATE OR REPLACE FUNCTION trg_setup_business_permissions()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM setup_business_permissions(NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_business_subscription_permissions ON business_subscriptions;
CREATE TRIGGER trg_business_subscription_permissions
  AFTER INSERT ON business_subscriptions
  FOR EACH ROW EXECUTE FUNCTION trg_setup_business_permissions();
