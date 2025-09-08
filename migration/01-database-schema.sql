-- AWS RDS PostgreSQL Schema for Request Marketplace
-- Generated from Firebase Collections Analysis
-- Date: 2025-08-16

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table (from Firebase users collection)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firebase_uid VARCHAR(255) UNIQUE,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    display_name VARCHAR(255),
    photo_url TEXT,
    email_verified BOOLEAN DEFAULT FALSE,
    phone_verified BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    role VARCHAR(50) DEFAULT 'user',
    country_code VARCHAR(3) DEFAULT 'LK',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP WITH TIME ZONE
);

-- Categories table
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firebase_id VARCHAR(255),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    icon VARCHAR(255),
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    country_code VARCHAR(3) DEFAULT 'LK',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Subcategories table
CREATE TABLE subcategories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firebase_id VARCHAR(255),
    category_id UUID REFERENCES categories(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    icon VARCHAR(255),
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    country_code VARCHAR(3) DEFAULT 'LK',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Cities table
CREATE TABLE cities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firebase_id VARCHAR(255),
    name VARCHAR(255) NOT NULL,
    country_code VARCHAR(3) DEFAULT 'LK',
    province VARCHAR(255),
    district VARCHAR(255),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Vehicle Types table
CREATE TABLE vehicle_types (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firebase_id VARCHAR(255),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    icon VARCHAR(255),
    passenger_capacity INTEGER DEFAULT 1,
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    country_code VARCHAR(3) DEFAULT 'LK',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Country Vehicle Types (enabled vehicles per country)
CREATE TABLE country_vehicle_types (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    country_code VARCHAR(3) NOT NULL,
    vehicle_type_id UUID REFERENCES vehicle_types(id) ON DELETE CASCADE,
    is_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(country_code, vehicle_type_id)
);

-- Variable Types table
CREATE TABLE variable_types (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firebase_id VARCHAR(255),
    name VARCHAR(255) NOT NULL,
    data_type VARCHAR(50) DEFAULT 'text',
    options JSONB,
    is_required BOOLEAN DEFAULT FALSE,
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    country_code VARCHAR(3) DEFAULT 'LK',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Requests table
CREATE TABLE requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firebase_id VARCHAR(255),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id),
    subcategory_id UUID REFERENCES subcategories(id),
    title VARCHAR(500) NOT NULL,
    description TEXT,
    budget_min DECIMAL(10, 2),
    budget_max DECIMAL(10, 2),
    currency VARCHAR(3) DEFAULT 'LKR',
    location_city_id UUID REFERENCES cities(id),
    location_address TEXT,
    location_latitude DECIMAL(10, 8),
    location_longitude DECIMAL(11, 8),
    status VARCHAR(50) DEFAULT 'active',
    priority VARCHAR(20) DEFAULT 'normal',
    expires_at TIMESTAMP WITH TIME ZONE,
    is_urgent BOOLEAN DEFAULT FALSE,
    view_count INTEGER DEFAULT 0,
    response_count INTEGER DEFAULT 0,
    country_code VARCHAR(3) DEFAULT 'LK',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Request Variables (custom fields)
CREATE TABLE request_variables (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_id UUID REFERENCES requests(id) ON DELETE CASCADE,
    variable_type_id UUID REFERENCES variable_types(id),
    value TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Business Verifications table
CREATE TABLE new_business_verifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firebase_id VARCHAR(255),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    business_name VARCHAR(255) NOT NULL,
    business_email VARCHAR(255),
    business_phone VARCHAR(20),
    business_address TEXT,
    business_registration_number VARCHAR(255),
    business_type VARCHAR(100),
    category_id UUID REFERENCES categories(id),
    subcategory_id UUID REFERENCES subcategories(id),
    city_id UUID REFERENCES cities(id),
    verification_status VARCHAR(50) DEFAULT 'pending',
    documents JSONB,
    verified_at TIMESTAMP WITH TIME ZONE,
    verified_by UUID REFERENCES users(id),
    country_code VARCHAR(3) DEFAULT 'LK',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Driver Verifications table
CREATE TABLE new_driver_verifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firebase_id VARCHAR(255),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    driver_name VARCHAR(255) NOT NULL,
    driver_email VARCHAR(255),
    driver_phone VARCHAR(20),
    driver_license_number VARCHAR(255),
    license_expiry_date DATE,
    vehicle_type_id UUID REFERENCES vehicle_types(id),
    vehicle_registration_number VARCHAR(255),
    vehicle_model VARCHAR(255),
    vehicle_year INTEGER,
    vehicle_color VARCHAR(100),
    city_id UUID REFERENCES cities(id),
    verification_status VARCHAR(50) DEFAULT 'pending',
    documents JSONB,
    vehicle_images JSONB,
    verified_at TIMESTAMP WITH TIME ZONE,
    verified_by UUID REFERENCES users(id),
    is_active BOOLEAN DEFAULT TRUE,
    country_code VARCHAR(3) DEFAULT 'LK',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Price Listings table
CREATE TABLE price_listings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firebase_id VARCHAR(255),
    business_id UUID REFERENCES new_business_verifications(id),
    category_id UUID REFERENCES categories(id),
    subcategory_id UUID REFERENCES subcategories(id),
    title VARCHAR(500) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2),
    currency VARCHAR(3) DEFAULT 'LKR',
    unit VARCHAR(100),
    city_id UUID REFERENCES cities(id),
    is_active BOOLEAN DEFAULT TRUE,
    view_count INTEGER DEFAULT 0,
    contact_count INTEGER DEFAULT 0,
    country_code VARCHAR(3) DEFAULT 'LK',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Messages/Conversations table
CREATE TABLE conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firebase_id VARCHAR(255),
    request_id UUID REFERENCES requests(id),
    requester_id UUID REFERENCES users(id),
    responder_id UUID REFERENCES users(id),
    last_message TEXT,
    last_message_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firebase_id VARCHAR(255),
    conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES users(id),
    message TEXT NOT NULL,
    message_type VARCHAR(50) DEFAULT 'text',
    is_read BOOLEAN DEFAULT FALSE,
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- OTP Verifications table
CREATE TABLE email_otp_verifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) NOT NULL,
    otp VARCHAR(6) NOT NULL,
    purpose VARCHAR(50) DEFAULT 'verification',
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_used BOOLEAN DEFAULT FALSE,
    attempts INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE phone_otp_verifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone VARCHAR(20) NOT NULL,
    otp VARCHAR(6) NOT NULL,
    purpose VARCHAR(50) DEFAULT 'verification',
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_used BOOLEAN DEFAULT FALSE,
    attempts INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Notifications table
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firebase_id VARCHAR(255),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    body TEXT,
    type VARCHAR(50) DEFAULT 'general',
    data JSONB,
    is_read BOOLEAN DEFAULT FALSE,
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Subscription Plans table
CREATE TABLE subscription_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firebase_id VARCHAR(255),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2),
    currency VARCHAR(3) DEFAULT 'LKR',
    duration_days INTEGER,
    features JSONB,
    is_active BOOLEAN DEFAULT TRUE,
    country_code VARCHAR(3) DEFAULT 'LK',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Content Pages table
CREATE TABLE content_pages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firebase_id VARCHAR(255),
    title VARCHAR(255) NOT NULL,
    content TEXT,
    slug VARCHAR(255) UNIQUE,
    page_type VARCHAR(50) DEFAULT 'general',
    is_published BOOLEAN DEFAULT FALSE,
    country_code VARCHAR(3) DEFAULT 'LK',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Response Tracking table
CREATE TABLE response_tracking (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firebase_id VARCHAR(255),
    request_id UUID REFERENCES requests(id),
    responder_id UUID REFERENCES users(id),
    response_type VARCHAR(50),
    response_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Ride Tracking table
CREATE TABLE ride_tracking (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firebase_id VARCHAR(255),
    driver_id UUID REFERENCES new_driver_verifications(id),
    passenger_id UUID REFERENCES users(id),
    pickup_location JSONB,
    dropoff_location JSONB,
    ride_status VARCHAR(50) DEFAULT 'requested',
    fare DECIMAL(10, 2),
    currency VARCHAR(3) DEFAULT 'LKR',
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_country ON users(country_code);
CREATE INDEX idx_requests_user ON requests(user_id);
CREATE INDEX idx_requests_category ON requests(category_id);
CREATE INDEX idx_requests_city ON requests(location_city_id);
CREATE INDEX idx_requests_status ON requests(status);
CREATE INDEX idx_requests_country ON requests(country_code);
CREATE INDEX idx_messages_conversation ON messages(conversation_id);
CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_otp_email ON email_otp_verifications(email);
CREATE INDEX idx_otp_phone ON phone_otp_verifications(phone);

-- Create triggers for updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply triggers to all tables with updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_categories_updated_at BEFORE UPDATE ON categories FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_subcategories_updated_at BEFORE UPDATE ON subcategories FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_cities_updated_at BEFORE UPDATE ON cities FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_vehicle_types_updated_at BEFORE UPDATE ON vehicle_types FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_country_vehicle_types_updated_at BEFORE UPDATE ON country_vehicle_types FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_variable_types_updated_at BEFORE UPDATE ON variable_types FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_requests_updated_at BEFORE UPDATE ON requests FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_business_verifications_updated_at BEFORE UPDATE ON new_business_verifications FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_driver_verifications_updated_at BEFORE UPDATE ON new_driver_verifications FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_price_listings_updated_at BEFORE UPDATE ON price_listings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_conversations_updated_at BEFORE UPDATE ON conversations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_subscription_plans_updated_at BEFORE UPDATE ON subscription_plans FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_content_pages_updated_at BEFORE UPDATE ON content_pages FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
