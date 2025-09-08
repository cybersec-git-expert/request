-- Create business_verifications table
CREATE TABLE IF NOT EXISTS business_verifications (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Business Details
    business_name VARCHAR(255) NOT NULL,
    business_email VARCHAR(255) NOT NULL,
    business_phone VARCHAR(20) NOT NULL,
    business_address TEXT NOT NULL,
    business_category VARCHAR(100) NOT NULL,
    business_description TEXT,
    license_number VARCHAR(50),
    tax_id VARCHAR(50),
    country VARCHAR(2) DEFAULT 'LK',
    country_name VARCHAR(100) DEFAULT 'Sri Lanka',
    
    -- Document URLs
    business_logo_url TEXT,
    business_license_url TEXT,
    insurance_document_url TEXT,
    tax_certificate_url TEXT,
    
    -- Individual Document Statuses
    business_logo_status VARCHAR(20) DEFAULT 'pending' CHECK (business_logo_status IN ('pending', 'approved', 'rejected')),
    business_license_status VARCHAR(20) DEFAULT 'pending' CHECK (business_license_status IN ('pending', 'approved', 'rejected')),
    insurance_document_status VARCHAR(20) DEFAULT 'pending' CHECK (insurance_document_status IN ('pending', 'approved', 'rejected')),
    tax_certificate_status VARCHAR(20) DEFAULT 'pending' CHECK (tax_certificate_status IN ('pending', 'approved', 'rejected')),
    
    -- Rejection Reasons
    business_logo_rejection_reason TEXT,
    business_license_rejection_reason TEXT,
    insurance_document_rejection_reason TEXT,
    tax_certificate_rejection_reason TEXT,
    
    -- Document Verification Structure (JSON)
    document_verification JSONB DEFAULT '{}',
    
    -- Overall Status
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    is_verified BOOLEAN DEFAULT FALSE,
    
    -- Contact Verification Requirements
    phone_verified BOOLEAN DEFAULT FALSE,
    email_verified BOOLEAN DEFAULT FALSE,
    
    -- Admin Review
    reviewed_by UUID REFERENCES admin_users(id),
    reviewed_date TIMESTAMP,
    notes TEXT,
    
    -- Timestamps
    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    approved_at TIMESTAMP,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Indexes for performance
    CONSTRAINT unique_user_business_verification UNIQUE (user_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_business_verifications_user_id ON business_verifications(user_id);
CREATE INDEX IF NOT EXISTS idx_business_verifications_status ON business_verifications(status);
CREATE INDEX IF NOT EXISTS idx_business_verifications_is_verified ON business_verifications(is_verified);
CREATE INDEX IF NOT EXISTS idx_business_verifications_submitted_at ON business_verifications(submitted_at);

-- Add trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_business_verifications_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_business_verifications_updated_at
    BEFORE UPDATE ON business_verifications
    FOR EACH ROW
    EXECUTE FUNCTION update_business_verifications_updated_at();

-- Add comments for documentation
COMMENT ON TABLE business_verifications IS 'Business verification records with document statuses and approval workflow';
COMMENT ON COLUMN business_verifications.phone_verified IS 'Must be true for full approval';
COMMENT ON COLUMN business_verifications.email_verified IS 'Must be true for full approval';
COMMENT ON COLUMN business_verifications.is_verified IS 'True only when status=approved AND phone_verified=true AND email_verified=true';
