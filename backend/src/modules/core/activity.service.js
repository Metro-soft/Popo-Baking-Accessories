const { pool } = require('../../config/db');

exports.logAction = async (userId, action, entityType = null, entityId = null, details = {}) => {
    try {
        await pool.query(
            `INSERT INTO activity_logs (user_id, action, entity_type, entity_id, details) 
       VALUES ($1, $2, $3, $4, $5)`,
            [userId, action, entityType, entityId?.toString(), JSON.stringify(details)]
        );
    } catch (error) {
        console.error('Failed to log activity:', error);
        // Don't throw - logging failure shouldn't break the main flow
    }
};

exports.getLogs = async ({ limit = 50, offset = 0, userId, action, startDate, endDate }) => {
    let query = `
    SELECT al.*, u.username, u.full_name 
    FROM activity_logs al
    LEFT JOIN users u ON al.user_id = u.id
    WHERE 1=1
  `;
    const params = [];
    let paramIdx = 1;

    if (userId) {
        query += ` AND al.user_id = $${paramIdx++}`;
        params.push(userId);
    }
    if (action) {
        query += ` AND al.action = $${paramIdx++}`;
        params.push(action);
    }
    if (startDate) {
        query += ` AND al.created_at >= $${paramIdx++}`;
        params.push(startDate);
    }
    if (endDate) {
        query += ` AND al.created_at <= $${paramIdx++}`;
        params.push(endDate);
    }

    query += ` ORDER BY al.created_at DESC LIMIT $${paramIdx++} OFFSET $${paramIdx++}`;
    params.push(limit, offset);

    const result = await pool.query(query, params);
    return result.rows;
};
