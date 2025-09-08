-- Migration: Normalize legacy 'admin' role to 'super_admin'
-- Safe / idempotent: only updates rows where role exactly 'admin'

UPDATE users
SET role = 'super_admin'
WHERE role = 'admin';

-- Optionally ensure at least one super admin exists (fallback seed)
INSERT INTO users (email, password_hash, display_name, role, is_active, email_verified, phone_verified, country_code)
SELECT 'superadmin@example.com', crypt('Admin@123', gen_salt('bf', 12)), 'Super Admin', 'super_admin', TRUE, TRUE, TRUE, 'LK'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE role = 'super_admin');
