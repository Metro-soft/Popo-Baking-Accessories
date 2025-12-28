const db = require('../../config/db');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

const SALT_ROUNDS = 10;
const JWT_SECRET = process.env.JWT_SECRET || 'your_jwt_secret_key_change_in_production';

const AuthController = {
    // Login User
    async login(req, res) {
        const { email, password } = req.body;
        try {
            // Find user
            const result = await db.query('SELECT * FROM users WHERE email = $1', [email]);
            if (result.rows.length === 0) {
                return res.status(401).json({ error: 'Invalid credentials' });
            }

            const user = result.rows[0];

            // Compare password
            const match = await bcrypt.compare(password, user.password_hash);
            if (!match) {
                return res.status(401).json({ error: 'Invalid credentials' });
            }

            // Generate Token
            const token = jwt.sign(
                { userId: user.id, email: user.email, role: user.role, branchId: user.branch_id },
                JWT_SECRET,
                { expiresIn: '12h' }
            );

            // Audit Login
            await createAuditLog(user.id, 'LOGIN', `User ${user.email} logged in.`);

            // Return user info (excluding password)
            // delete user.password_hash; // This line is no longer needed as we construct a new user object
            res.json({
                message: 'Login successful',
                token,
                user: { id: user.id, username: user.username, role: user.role }
            });

        } catch (error) {
            console.error('Login Error:', error);
            res.status(500).json({ error: 'Internal server error' });
        }
    },

    // Register User (Admin Only usually, or public if allowed)
    async register(req, res) {
        const { username, email, password, role, branchId } = req.body;
        try {
            // Check if email exists
            const existing = await db.query('SELECT id FROM users WHERE email = $1', [email]);
            if (existing.rows.length > 0) {
                return res.status(400).json({ error: 'Email already in use' });
            }

            // Hash password
            const hash = await bcrypt.hash(password, SALT_ROUNDS);

            // Insert User
            // Depending on schema, might have branch_id
            const query = `
        INSERT INTO users (username, email, password_hash, role, branch_id)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING id, username, email, role, branch_id
      `;
            const values = [username, email, hash, role || 'staff', branchId || null];

            const result = await db.query(query, values);
            res.status(201).json(result.rows[0]);

        } catch (error) {
            console.error('Register Error:', error);
            res.status(500).json({ error: 'Failed to register user' });
        }
    },

    // Get Current User Profile
    async getProfile(req, res) {
        try {
            const result = await db.query('SELECT id, username, email, role, branch_id FROM users WHERE id = $1', [req.user.userId]);
            if (result.rows.length === 0) {
                return res.status(404).json({ error: 'User not found' });
            }
            res.json(result.rows[0]);
        } catch (error) {
            res.status(500).json({ error: 'Server error' });
        }
    }
};

module.exports = AuthController;
