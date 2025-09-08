const database = require('./services/database');

async function createDriverVerificationsTable() {
  try {
    console.log('Creating driver_verifications table...');
    
    const createTableQuery = `
      CREATE TABLE IF NOT EXISTS driver_verifications (
        id SERIAL PRIMARY KEY,
        user_id VARCHAR(255) NOT NULL,
        
        -- Personal Information
        first_name VARCHAR(255),
        last_name VARCHAR(255),
        full_name VARCHAR(255) NOT NULL,
        date_of_birth DATE NOT NULL,
        gender VARCHAR(10) NOT NULL,
        nic_number VARCHAR(50) NOT NULL,
        phone_number VARCHAR(20) NOT NULL,
        secondary_mobile VARCHAR(20),
        email VARCHAR(255),
        
        -- Location (using actual IDs from our database)
        city_id UUID,
        city_name VARCHAR(255),
        country VARCHAR(10) DEFAULT 'LK',
        
        -- Driver License Information
        license_number VARCHAR(100),
        license_expiry DATE,
        license_has_no_expiry BOOLEAN DEFAULT FALSE,
        
        -- Vehicle Information (using actual IDs from our database)
        vehicle_type_id UUID,
        vehicle_type_name VARCHAR(100),
        vehicle_model VARCHAR(100),
        vehicle_year INTEGER,
        vehicle_number VARCHAR(50),
        vehicle_color VARCHAR(50),
        is_vehicle_owner BOOLEAN DEFAULT TRUE,
        
        -- Insurance Information
        insurance_number VARCHAR(100),
        insurance_expiry DATE,
        
        -- Document URLs
        driver_image_url TEXT,
        nic_front_url TEXT,
        nic_back_url TEXT,
        license_front_url TEXT,
        license_back_url TEXT,
        license_document_url TEXT,
        vehicle_registration_url TEXT,
        insurance_document_url TEXT,
        billing_proof_url TEXT,
        vehicle_image_urls JSONB, -- Array of vehicle image URLs
        
        -- Document Verification Status
        driver_image_status VARCHAR(20) DEFAULT 'pending',
        nic_front_status VARCHAR(20) DEFAULT 'pending',
        nic_back_status VARCHAR(20) DEFAULT 'pending',
        license_front_status VARCHAR(20) DEFAULT 'pending',
        license_back_status VARCHAR(20) DEFAULT 'pending',
        vehicle_registration_status VARCHAR(20) DEFAULT 'pending',
        vehicle_insurance_status VARCHAR(20) DEFAULT 'pending',
        billing_proof_status VARCHAR(20) DEFAULT 'pending',
        vehicle_image_verification JSONB, -- Status for each vehicle image
        
        -- Rejection Reasons
        license_front_rejection_reason TEXT,
        nic_back_rejection_reason TEXT,
        vehicle_insurance_rejection_reason TEXT,
        
        -- Document Verification Metadata
        document_verification JSONB, -- Complete documentVerification structure
        
        -- Driver Status and Metrics
        status VARCHAR(20) DEFAULT 'pending',
        availability BOOLEAN DEFAULT TRUE,
        is_active BOOLEAN DEFAULT TRUE,
        is_verified BOOLEAN DEFAULT FALSE,
        subscription_plan VARCHAR(50) DEFAULT 'free',
        rating DECIMAL(3,2) DEFAULT 0.00,
        total_rides INTEGER DEFAULT 0,
        total_earnings DECIMAL(10,2) DEFAULT 0.00,
        
        -- Timestamps
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        submission_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        reviewed_date TIMESTAMP,
        reviewed_by VARCHAR(255),
        
        -- Admin Notes
        notes TEXT,
        
        -- Foreign Key Constraints
        CONSTRAINT fk_city FOREIGN KEY (city_id) REFERENCES cities(id),
        CONSTRAINT fk_vehicle_type FOREIGN KEY (vehicle_type_id) REFERENCES vehicle_types(id)
      );
    `;

    await database.query(createTableQuery);
    console.log('✅ driver_verifications table created successfully');

    // Create indexes for better performance
    const indexQueries = [
      'CREATE INDEX IF NOT EXISTS idx_driver_verifications_user_id ON driver_verifications(user_id);',
      'CREATE INDEX IF NOT EXISTS idx_driver_verifications_country ON driver_verifications(country);',
      'CREATE INDEX IF NOT EXISTS idx_driver_verifications_status ON driver_verifications(status);',
      'CREATE INDEX IF NOT EXISTS idx_driver_verifications_submission_date ON driver_verifications(submission_date);',
      'CREATE INDEX IF NOT EXISTS idx_driver_verifications_is_verified ON driver_verifications(is_verified);',
      'CREATE INDEX IF NOT EXISTS idx_driver_verifications_availability ON driver_verifications(availability);'
    ];

    for (const query of indexQueries) {
      await database.query(query);
    }
    console.log('✅ Indexes created successfully');

    // Add trigger for updated_at
    const triggerQuery = `
      CREATE OR REPLACE FUNCTION update_driver_verifications_updated_at()
      RETURNS TRIGGER AS $$
      BEGIN
          NEW.updated_at = CURRENT_TIMESTAMP;
          RETURN NEW;
      END;
      $$ language 'plpgsql';

      DROP TRIGGER IF EXISTS update_driver_verifications_updated_at ON driver_verifications;
      
      CREATE TRIGGER update_driver_verifications_updated_at
          BEFORE UPDATE ON driver_verifications
          FOR EACH ROW
          EXECUTE FUNCTION update_driver_verifications_updated_at();
    `;

    await database.query(triggerQuery);
    console.log('✅ Updated_at trigger created successfully');

  } catch (error) {
    console.error('❌ Error creating driver_verifications table:', error);
  } finally {
    process.exit(0);
  }
}

createDriverVerificationsTable();
