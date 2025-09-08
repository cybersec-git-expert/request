-- Price Staging System Migration
-- This system allows businesses to update prices multiple times per day,
-- but only pushes the latest changes to the main price_listings table once daily at 1 AM

-- Create price_staging table for temporary price updates
CREATE TABLE IF NOT EXISTS price_staging (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL,
    price_listing_id UUID NOT NULL REFERENCES price_listings(id) ON DELETE CASCADE,
    master_product_id UUID NOT NULL REFERENCES master_products(id),
    
    -- Price information
    staged_price DECIMAL(12,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'LKR',
    
    -- Additional fields that can be updated
    staged_stock_quantity INTEGER DEFAULT 1,
    staged_is_available BOOLEAN DEFAULT true,
    staged_whatsapp_number VARCHAR(20),
    staged_product_link TEXT,
    staged_model_number VARCHAR(100),
    staged_selected_variables JSONB DEFAULT '{}',
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Status tracking
    is_processed BOOLEAN DEFAULT false,
    processed_at TIMESTAMP WITH TIME ZONE,
    
    -- Ensure one staging record per price listing
    UNIQUE(price_listing_id)
);

-- Create index for efficient queries
CREATE INDEX IF NOT EXISTS idx_price_staging_business_id ON price_staging(business_id);
CREATE INDEX IF NOT EXISTS idx_price_staging_processed ON price_staging(is_processed);
CREATE INDEX IF NOT EXISTS idx_price_staging_created_at ON price_staging(created_at);

-- Create price_update_history table to track all changes
CREATE TABLE IF NOT EXISTS price_update_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    price_listing_id UUID NOT NULL,
    business_id UUID NOT NULL,
    
    -- Price change information
    old_price DECIMAL(12,2),
    new_price DECIMAL(12,2) NOT NULL,
    price_change_percentage DECIMAL(5,2),
    
    -- Change metadata
    change_type VARCHAR(20) NOT NULL CHECK (change_type IN ('staged', 'applied', 'reverted')),
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    applied_by VARCHAR(50) DEFAULT 'system', -- 'user' or 'system'
    
    -- Additional context
    notes TEXT,
    
    FOREIGN KEY (price_listing_id) REFERENCES price_listings(id) ON DELETE CASCADE
);

-- Create index for price history
CREATE INDEX IF NOT EXISTS idx_price_history_listing_id ON price_update_history(price_listing_id);
CREATE INDEX IF NOT EXISTS idx_price_history_business_id ON price_update_history(business_id);
CREATE INDEX IF NOT EXISTS idx_price_history_applied_at ON price_update_history(applied_at);

-- Add trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_price_staging_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_price_staging_updated_at
    BEFORE UPDATE ON price_staging
    FOR EACH ROW
    EXECUTE FUNCTION update_price_staging_updated_at();

-- Create function to apply staged prices to main table
CREATE OR REPLACE FUNCTION apply_staged_prices()
RETURNS INTEGER AS $$
DECLARE
    updated_count INTEGER := 0;
    staging_record RECORD;
BEGIN
    -- Loop through all unprocessed staging records
    FOR staging_record IN 
        SELECT * FROM price_staging WHERE is_processed = false
    LOOP
        -- Update the main price_listings table
        UPDATE price_listings 
        SET 
            price = staging_record.staged_price,
            stock_quantity = staging_record.staged_stock_quantity,
            is_available = staging_record.staged_is_available,
            whatsapp_number = staging_record.staged_whatsapp_number,
            product_link = staging_record.staged_product_link,
            model_number = staging_record.staged_model_number,
            selected_variables = staging_record.staged_selected_variables,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = staging_record.price_listing_id;
        
        -- Record the price change in history
        INSERT INTO price_update_history (
            price_listing_id,
            business_id,
            old_price,
            new_price,
            price_change_percentage,
            change_type,
            applied_by
        )
        SELECT 
            staging_record.price_listing_id,
            staging_record.business_id,
            pl.price,
            staging_record.staged_price,
            CASE 
                WHEN pl.price > 0 THEN 
                    ROUND(((staging_record.staged_price - pl.price) / pl.price * 100)::NUMERIC, 2)
                ELSE 0 
            END,
            'applied',
            'system'
        FROM price_listings pl 
        WHERE pl.id = staging_record.price_listing_id;
        
        -- Mark staging record as processed
        UPDATE price_staging 
        SET 
            is_processed = true,
            processed_at = CURRENT_TIMESTAMP
        WHERE id = staging_record.id;
        
        updated_count := updated_count + 1;
    END LOOP;
    
    RETURN updated_count;
END;
$$ LANGUAGE plpgsql;

-- Create function to get business price staging summary
CREATE OR REPLACE FUNCTION get_business_staging_summary(business_uuid UUID)
RETURNS TABLE(
    total_staged INTEGER,
    total_value DECIMAL(12,2),
    last_update TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_staged,
        COALESCE(SUM(staged_price), 0) as total_value,
        MAX(updated_at) as last_update
    FROM price_staging ps
    WHERE ps.business_id = business_uuid AND ps.is_processed = false;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE price_staging IS 'Temporary storage for price updates that will be applied daily at 1 AM';
COMMENT ON TABLE price_update_history IS 'Historical record of all price changes for auditing and analytics';
COMMENT ON FUNCTION apply_staged_prices() IS 'Function to apply all staged prices to main price_listings table - called by daily scheduler';
