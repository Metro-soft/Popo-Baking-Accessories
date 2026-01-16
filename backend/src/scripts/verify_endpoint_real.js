const axios = require('axios');

const API_URL = 'http://localhost:5000/api';

// UPDATE THESE CREDENTIALS to a valid user in your local DB
const EMAIL = 'admin@popo.com';
const PASSWORD = 'pass234';

const testEndpoint = async () => {
    try {
        console.log('1. Attempting Login...');
        const loginRes = await axios.post(`${API_URL}/auth/login`, {
            email: EMAIL,
            password: PASSWORD
        });

        const token = loginRes.data.token;
        console.log('✅ Login Successful. Token received.');

        console.log('\n2. Fetching Dashboard Stats...');
        const statsRes = await axios.get(`${API_URL}/finance/stats/dashboard`, {
            headers: { Authorization: `Bearer ${token}` }
        });

        console.log('✅ Stats Received!');
        console.log('------------------------------------------------');
        // Check if chartData exists
        if (statsRes.data.chartData) {
            console.log('Chart Data Length:', statsRes.data.chartData.length);
            console.log('Chart Data (First 3 items):', statsRes.data.chartData.slice(0, 3));
            console.log('Chart Data (Last 3 items):', statsRes.data.chartData.slice(-3));

            const janData = statsRes.data.chartData.find(d => d.month === 'Jan');
            if (janData && (Number(janData.amount) > 0)) {
                console.log(`🎉 SUCCESS: Found Data for Jan: ${janData.amount}`);
            } else {
                console.log('⚠️ WARNING: Jan data is 0 or missing.');
            }
        } else {
            console.log('⚠️ CRITICAL: chartData is MISSING in response.', statsRes.data);
        }
        console.log('------------------------------------------------');

    } catch (error) {
        console.error('❌ Error:', error.response ? error.response.data : error.message);
    }
};

testEndpoint();
