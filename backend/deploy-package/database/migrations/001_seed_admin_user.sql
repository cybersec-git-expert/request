-- Seed a default admin user if none exists
-- Adjust email/password before production. Password: Admin@123 (hashed)

INSERT INTO users (email, password_hash, display_name, role, is_active, email_verified, phone_verified, country_code)
SELECT 'admin@example.com', crypt('Admin@123', gen_salt('bf', 12)), 'Super Admin', 'admin', TRUE, TRUE, TRUE, 'LK'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE role = 'admin');
