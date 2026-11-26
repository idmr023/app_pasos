const axios = require('axios');
const { encrypt, decrypt } = require('../utils/tokenEncryption');

const STRAVA_API = 'https://www.strava.com/api/v3';

class StravaError extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}

function hasStrava(user) {
  return !!(user && user.strava && user.strava.accessToken);
}

/**
 * Devuelve un access token válido de Strava para el usuario, refrescándolo
 * (y persistiéndolo cifrado) si expiró. Lanza StravaError si no hay conexión.
 */
async function getStravaAccessToken(user) {
  if (!hasStrava(user)) {
    throw new StravaError('Strava no está conectado', 400);
  }

  let token = decrypt(user.strava.accessToken);
  const expired = !user.strava.expiresAt || Date.now() / 1000 > user.strava.expiresAt - 60;

  if (token && !expired) return token;

  const refreshToken = decrypt(user.strava.refreshToken);
  if (!refreshToken) {
    throw new StravaError('La conexión con Strava expiró, vuelve a conectar', 401);
  }

  try {
    const refreshRes = await axios.post('https://www.strava.com/oauth/token', {
      client_id: process.env.STRAVA_CLIENT_ID,
      client_secret: process.env.STRAVA_CLIENT_SECRET,
      grant_type: 'refresh_token',
      refresh_token: refreshToken
    });
    token = refreshRes.data.access_token;
    user.strava.accessToken = encrypt(token);
    user.strava.refreshToken = encrypt(refreshRes.data.refresh_token);
    user.strava.expiresAt = refreshRes.data.expires_at;
    await user.save();
    return token;
  } catch (err) {
    throw new StravaError('La conexión con Strava expiró, vuelve a conectar', 401);
  }
}

async function stravaGet(token, path, params) {
  const res = await axios.get(`${STRAVA_API}${path}`, {
    headers: { Authorization: `Bearer ${token}` },
    params,
    timeout: 20000
  });
  return res.data;
}

module.exports = { StravaError, hasStrava, getStravaAccessToken, stravaGet };
