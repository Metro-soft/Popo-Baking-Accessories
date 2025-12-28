-- 007_setup_auth.sql
-- 1. Ensure Users table has necessary fields
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS username VARCHAR(50) UNIQUE,
ADD COLUMN IF NOT EXISTS email VARCHAR(100) UNIQUE,
ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255), -- We will use BCrypt
ADD COLUMN IF NOT EXISTS role VARCHAR(20) DEFAULT 'staff', -- admin, manager, staff
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

-- 2. Create Default Admin User (Password: 'admin123' - hash generated separately)
-- Using a placeholder hash for 'admin123' (bcrypt cost 10)
-- $2b$10$w/uFp/u... is typically how it looks.
-- I'll use a known hash for 'admin123' -> $2b$10$7ZkQfD0Q... (Example, but best to generate in JS seeder. For now, I will insert/update via migration if I can, or rely on a JS script.
-- Let's just create the columns first. The JS runner can handle seeding or I can put a dummy hash.
-- Hash for 'password': $2b$10$yF/w./. (Too risky to hardcode unknown salt).
-- I'll rely on the Run Migration script to seed, or just create the columns and let the first run of the app handle init?
-- Better: I'll include a JS seeder script.

-- Just columns for now.
