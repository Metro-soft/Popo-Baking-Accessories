const jwt = require('jsonwebtoken');

const authorize = (roles = []) => {
    // roles param can be a single string (e.g. 'admin') or an array of strings (['admin', 'manager'])
    if (typeof roles === 'string') {
        roles = [roles];
    }

    return [
        // authenticate JWT (assuming authenticateToken is separate or we do it here if needed)
        // Usually, authenticateToken middleware runs BEFORE this and attaches user to req.user

        (req, res, next) => {
            if (!req.user) {
                return res.status(401).json({ error: 'Unauthorized: No user found' });
            }

            if (roles.length && !roles.includes(req.user.role)) {
                // User's role is not authorized
                return res.status(403).json({ error: "You don't have the rights to perform this task" });
            }

            // Authentication and Authorization successful
            next();
        }
    ];
};

module.exports = authorize;
