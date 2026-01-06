const activityService = require('./activity.service');

exports.getLogs = async (req, res) => {
    try {
        const { limit, offset, user_id, action, start_date, end_date } = req.query;

        // Convert params
        const logs = await activityService.getLogs({
            limit: limit ? parseInt(limit) : 50,
            offset: offset ? parseInt(offset) : 0,
            userId: user_id,
            action: action,
            startDate: start_date,
            endDate: end_date
        });

        res.json(logs);
    } catch (error) {
        console.error('Error fetching activity logs:', error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
};
