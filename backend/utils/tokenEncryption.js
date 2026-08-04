const crypto = require('crypto');

function getKey() {
  const secret = process.env.STRAVA_TOKEN_KEY || process.env.JWT_SECRET;
  return crypto.createHash('sha256').update(String(secret)).digest();
}

function encrypt(plainText) {
  if (!plainText) return '';
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', getKey(), iv);
  const encrypted = Buffer.concat([cipher.update(String(plainText), 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `${iv.toString('base64')}:${tag.toString('base64')}:${encrypted.toString('base64')}`;
}

function decrypt(payload) {
  if (!payload || typeof payload !== 'string') return '';
  const parts = payload.split(':');
  if (parts.length !== 3) return payload;
  try {
    const [ivB64, tagB64, dataB64] = parts;
    const decipher = crypto.createDecipheriv('aes-256-gcm', getKey(), Buffer.from(ivB64, 'base64'));
    decipher.setAuthTag(Buffer.from(tagB64, 'base64'));
    const decrypted = Buffer.concat([
      decipher.update(Buffer.from(dataB64, 'base64')),
      decipher.final(),
    ]);
    return decrypted.toString('utf8');
  } catch (err) {
    return payload;
  }
}

module.exports = { encrypt, decrypt };
