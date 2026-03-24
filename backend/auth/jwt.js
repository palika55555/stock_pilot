/**
 * JWT auth: sign access/refresh tokens, verify and extract userId.
 * Requires env JWT_SECRET (min 32 chars in production).
 */
const crypto = require('crypto');
const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-change-in-production-min-32-chars';
const ACCESS_EXPIRY = '24h';       // 24 hours
const REFRESH_EXPIRY = '30d';     // 30 days
const REMEMBER_ME_ACCESS = '7d';   // 7 days when remember me
/** Po úspešnom 2FA: token na preskočenie ďalšieho 2FA pri prihlásení (24h). */
const TWOFA_TRUST_EXPIRY = '24h';
const TWOFA_DEVICE_ID_MIN = 8;
const TWOFA_DEVICE_ID_MAX = 128;

/**
 * Stabilné ID klienta (prehliadač / inštalácia apky). Nie je heslo – len väzba na zariadenie.
 * @returns {string|null}
 */
function normalizeClientDeviceId(raw) {
  if (raw == null) return null;
  const s = String(raw).trim();
  if (s.length < TWOFA_DEVICE_ID_MIN || s.length > TWOFA_DEVICE_ID_MAX) return null;
  return s;
}

/**
 * HMAC väzba userId + deviceId – deviceId nie je v JWT v čitateľnej podobe.
 * @returns {string|null} base64url
 */
function computeTwofaTrustBinding(userId, deviceId) {
  const normDev = normalizeClientDeviceId(deviceId);
  if (!normDev) return null;
  return crypto
    .createHmac('sha256', JWT_SECRET)
    .update(`${String(userId)}|${normDev}`)
    .digest('base64url');
}

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

/**
 * Vydá token na preskočenie 2FA pri ďalšom prihlásení (platnosť 24h), naviazaný na zariadenie.
 * @param {string|number} userId
 * @param {string} deviceId – rovnaké ako v tele POST /auth/login
 * @returns {string|null}
 */
function signTwoFactorTrustToken(userId, deviceId) {
  const binding = computeTwofaTrustBinding(userId, deviceId);
  if (!binding) return null;
  return jwt.sign(
    { userId, type: 'twofa_trust', binding },
    JWT_SECRET,
    { expiresIn: TWOFA_TRUST_EXPIRY }
  );
}

/**
 * Overenie trust tokenu + zhoda zariadenia (klient musí poslať rovnaké deviceId ako pri vydaní).
 * @returns {{ userId: string|number, type: string }|null}
 */
function verifyTwoFactorTrustToken(token, deviceId) {
  if (!token || typeof token !== 'string') return null;
  try {
    const decoded = jwt.verify(token.trim(), JWT_SECRET);
    if (decoded.type !== 'twofa_trust' || decoded.userId == null || !decoded.binding) return null;
    const expected = computeTwofaTrustBinding(decoded.userId, deviceId);
    if (!expected || decoded.binding !== expected) return null;
    return decoded;
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
  verifyTwoFactorTrustToken,
  signTwoFactorTrustToken,
  normalizeClientDeviceId,
  getSecret,
  ACCESS_EXPIRY,
  REFRESH_EXPIRY,
  TWOFA_TRUST_EXPIRY,
};
