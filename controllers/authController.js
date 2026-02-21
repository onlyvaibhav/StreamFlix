const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'default-secret-change-me';
const ADMIN_USERNAME = process.env.ADMIN_USERNAME || 'admin';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'admin123';

exports.login = async (req, res) => {
  try {
    const { username, password } = req.body;

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

    // Guest access
    const token = jwt.sign(
      { username: 'guest', role: 'viewer' },
      JWT_SECRET,
      { expiresIn: '12h' }
    );

    return res.json({
      success: true,
      token,
      user: { username: 'guest', role: 'viewer' }
    });
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