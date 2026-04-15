const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'default-secret-change-me';
const ADMIN_USERNAME = process.env.ADMIN_USERNAME || 'admin';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'admin123';

exports.login = async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({ success: false, error: 'Username and password are required' });
    }

    if (username === ADMIN_USERNAME && password === ADMIN_PASSWORD) {
      const token = jwt.sign(
        { username, role: 'admin' },
        JWT_SECRET,
        { expiresIn: '24h' }
      );

      return res.json({
        success: true,
        token,
        user: { username, role: 'admin' }
      });
    }

    // Wrong credentials — reject
    return res.status(401).json({ success: false, error: 'Invalid username or password' });
  } catch (error) {
    res.status(500).json({ error: 'Login failed', message: error.message });
  }
};

exports.guestToken = async (req, res) => {
  try {
    const token = jwt.sign(
      { username: 'guest', role: 'viewer' },
      JWT_SECRET,
      { expiresIn: '12h' }
    );

    res.json({ success: true, token });
  } catch (error) {
    res.status(500).json({ error: 'Token generation failed' });
  }
};