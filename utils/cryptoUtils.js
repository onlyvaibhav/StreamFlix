const crypto = require('crypto');

const ALGORITHM = 'aes-256-cbc';

// Fallback to random key if none specified, but warn
let encryptionKey;
if (process.env.SESSION_ENCRYPTION_KEY) {
  try {
    encryptionKey = Buffer.from(process.env.SESSION_ENCRYPTION_KEY, 'hex');
    if (encryptionKey.length !== 32) {
      console.warn('⚠️ SESSION_ENCRYPTION_KEY must be a 64-character hex string (32 bytes). Current byte length:', encryptionKey.length);
      // Pad or slice to 32 bytes
      const newKey = Buffer.alloc(32);
      encryptionKey.copy(newKey);
      encryptionKey = newKey;
    }
  } catch (err) {
    console.error('❌ Failed to parse SESSION_ENCRYPTION_KEY as hex:', err.message);
    encryptionKey = crypto.randomBytes(32);
  }
} else {
  console.warn('⚠️ SESSION_ENCRYPTION_KEY not set in .env. Generating a random key for this runtime.');
  encryptionKey = crypto.randomBytes(32);
}

const IV_LENGTH = 16; // AES block size in bytes

/**
 * Encrypts a plain text string.
 * Returns IV + Ciphertext in format "iv_hex:ciphertext_hex".
 */
function encrypt(text) {
  if (!text) return '';
  try {
    const iv = crypto.randomBytes(IV_LENGTH);
    const cipher = crypto.createCipheriv(ALGORITHM, encryptionKey, iv);
    let encrypted = cipher.update(text, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    return iv.toString('hex') + ':' + encrypted;
  } catch (error) {
    console.error('❌ Encryption failed:', error.message);
    throw error;
  }
}

/**
 * Decrypts an encrypted string of format "iv_hex:ciphertext_hex".
 */
function decrypt(text) {
  if (!text) return '';
  try {
    const parts = text.split(':');
    if (parts.length !== 2) {
      throw new Error('Format must be iv:ciphertext');
    }
    const iv = Buffer.from(parts[0], 'hex');
    const encryptedText = Buffer.from(parts[1], 'hex');
    const decipher = crypto.createDecipheriv(ALGORITHM, encryptionKey, iv);
    let decrypted = decipher.update(encryptedText, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
  } catch (error) {
    console.error('❌ Decryption failed:', error.message);
    throw error;
  }
}

module.exports = {
  encrypt,
  decrypt
};
