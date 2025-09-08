-- Add permissions JSONB column to users (if not exists) and seed full permissions for super admins

ALTER TABLE users ADD COLUMN IF NOT EXISTS permissions JSONB;

-- Seed permissions for any user currently with role super_admin (or legacy admin) that has NULL permissions
UPDATE users
SET permissions = '{
  "adminUsersManagement": true,
  "brandManagement": true,
  "businessManagement": true,
  "categoryManagement": true,
  "cityManagement": true,
  "contentManagement": true,
  "countryBrandManagement": true,
  "countryCategoryManagement": true,
  "countryPageManagement": true,
  "countryProductManagement": true,
  "countrySubcategoryManagement": true,
  "countryVariableTypeManagement": true,
  "countryVehicleTypeManagement": true,
  "driverManagement": true,
  "driverVerification": true,
  "legalDocumentManagement": true,
  "legalDocuments": true,
  "moduleManagement": true,
  "paymentMethodManagement": true,
  "paymentMethods": true,
  "priceListingManagement": true,
  "productManagement": true,
  "promoCodeManagement": true,
  "requestManagement": true,
  "responseManagement": true,
  "subcategoryManagement": true,
  "subscriptionManagement": true,
  "userManagement": true,
  "variableTypeManagement": true,
  "vehicleManagement": true
}'::jsonb
WHERE (role = 'super_admin' OR role = 'admin') AND (permissions IS NULL OR jsonb_typeof(permissions) IS DISTINCT FROM 'object');

CREATE INDEX IF NOT EXISTS idx_users_permissions ON users USING GIN (permissions);
