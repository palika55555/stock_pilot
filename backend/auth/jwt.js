/**
 * JWT auth: sign access/refresh tokens, verify and extract userId.
 * Requires env JWT_SECRET (min 32 chars in production).
 */
const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-change-in-production-min-32-chars';
const ACCESS_EXPIRY = '24h';       // 24 hours
const REFRESH_EXPIRY = '30d';     // 30 days
const REMEMBER_ME_ACCESS = '7d';   // 7 days when remember me

/**
 * @param {object} payload - { userId, email, role }
 * @param {boolean} rememberMe
 * @returns {{ accessToken: string, refreshToken: string, accessExpiresIn: string }}
 */
function signTokens(payload, rememberMe = false) {
  const accessExpiry = rememberMe ? REMEMBER_ME_ACCESS : ACCESS_EXPIRY;
  const accessToken = jwt.sign(
    { userId: payload.userId, email: payload.email || '', role: payload.role || 'user' },
    JWT_SECRET,
    { expiresIn: accessExpiry }
  );
  const refreshToken = jwt.sign(
    { userId: payload.userId, type: 'refresh' },
    JWT_SECRET,
    { expiresIn: REFRESH_EXPIRY }
  );
  return {
    accessToken,
    refreshToken,
    accessExpiresIn: accessExpiry,
  };
}

/**
 * Verify access token (Bearer <token>). Sets req.userId, req.userEmail, req.userRole.
 * @returns {object|null} decoded payload or null if invalid
 */
function verifyAccessToken(token) {
  if (!token || typeof token !== 'string') return null;
  try {
    const decoded = jwt.verify(token.trim(), JWT_SECRET);
    if (decoded.userId) return decoded;
    return null;
  } catch (err) {
    return null;
  }
}

/**
 * Verify refresh token. Returns { userId } or null.
 */
function verifyRefreshToken(token) {
  if (!token || typeof token !== 'string') return null;
  try {
    const decoded = jwt.verify(token.trim(), JWT_SECRET);
    if (decoded.type === 'refresh' && decoded.userId) return decoded;
    return null;
  } catch (err) {
    return null;
  }
}

function getSecret() {
  return JWT_SECRET;
}

module.exports = {
  signTokens,
  verifyAccessToken,
  verifyRefreshToken,
  getSecret,
  ACCESS_EXPIRY,
  REFRESH_EXPIRY,
};
