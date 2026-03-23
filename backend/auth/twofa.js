const crypto = require('crypto');

const ISSUER = process.env.TWOFA_ISSUER || 'StockPilot';
const STEP_SECONDS = 30;
const DIGITS = 6;
const TOTP_WINDOW = 1; // allow +/- 1 step for mild clock skew

function _normalizeEncryptionKey() {
  const raw = process.env.TWOFA_ENCRYPTION_KEY || '';
  if (!raw) {
    throw new Error('Missing TWOFA_ENCRYPTION_KEY');
  }
  const trimmed = raw.trim();
  if (/^[0-9a-fA-F]{64}$/.test(trimmed)) {
    return Buffer.from(trimmed, 'hex');
  }
  const b64 = Buffer.from(trimmed, 'base64');
  if (b64.length === 32) return b64;
  throw new Error('Invalid TWOFA_ENCRYPTION_KEY (must be 32-byte base64 or 64-char hex)');
}

const ENCRYPTION_KEY = _normalizeEncryptionKey();

function _base32Encode(buffer) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let bits = 0;
  let value = 0;
  let output = '';
  for (let i = 0; i < buffer.length; i++) {
    value = (value << 8) | buffer[i];
    bits += 8;
    while (bits >= 5) {
      output += alphabet[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits > 0) {
    output += alphabet[(value << (5 - bits)) & 31];
  }
  return output;
}

function _base32Decode(base32) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  const normalized = (base32 || '').toUpperCase().replace(/=+$/g, '');
  let bits = 0;
  let value = 0;
  const bytes = [];
  for (let i = 0; i < normalized.length; i++) {
    const idx = alphabet.indexOf(normalized[i]);
    if (idx < 0) continue;
    value = (value << 5) | idx;
    bits += 5;
    if (bits >= 8) {
      bytes.push((value >>> (bits - 8)) & 255);
      bits -= 8;
    }
  }
  return Buffer.from(bytes);
}

function _hotp(secretBase32, counter) {
  const key = _base32Decode(secretBase32);
  const buf = Buffer.alloc(8);
  const big = BigInt(counter);
  buf.writeBigUInt64BE(big);
  const hmac = crypto.createHmac('sha1', key).update(buf).digest();
  const offset = hmac[hmac.length - 1] & 0x0f;
  const code =
    ((hmac[offset] & 0x7f) << 24) |
    ((hmac[offset + 1] & 0xff) << 16) |
    ((hmac[offset + 2] & 0xff) << 8) |
    (hmac[offset + 3] & 0xff);
  return String(code % 10 ** DIGITS).padStart(DIGITS, '0');
}

function _currentStep(nowMs = Date.now()) {
  return Math.floor(nowMs / 1000 / STEP_SECONDS);
}

function verifyTotpCode(secretBase32, code, nowMs = Date.now()) {
  const normalized = String(code || '').replace(/\s+/g, '');
  if (!/^\d{6}$/.test(normalized)) {
    return { ok: false, step: null };
  }
  const baseStep = _currentStep(nowMs);
  for (let delta = -TOTP_WINDOW; delta <= TOTP_WINDOW; delta++) {
    const step = baseStep + delta;
    if (_hotp(secretBase32, step) === normalized) {
      return { ok: true, step };
    }
  }
  return { ok: false, step: null };
}

function _sha256(input) {
  return crypto.createHash('sha256').update(input).digest('hex');
}

function _encodeURIComponentStrict(v) {
  return encodeURIComponent(v).replace(/[!'()*]/g, (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`);
}

function generateTotpSecret(accountName) {
  const secret = _base32Encode(crypto.randomBytes(20));
  const label = `${ISSUER}:${accountName || 'user'}`;
  const uri = `otpauth://totp/${_encodeURIComponentStrict(label)}?secret=${secret}&issuer=${_encodeURIComponentStrict(
    ISSUER
  )}&algorithm=SHA1&digits=${DIGITS}&period=${STEP_SECONDS}`;
  return { secret, otpauthUri: uri };
}

function encryptSecret(secretBase32) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', ENCRYPTION_KEY, iv);
  const encrypted = Buffer.concat([cipher.update(secretBase32, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return {
    encrypted: Buffer.concat([encrypted, tag]).toString('base64'),
    iv: iv.toString('base64'),
  };
}

function decryptSecret(encryptedB64, ivB64) {
  const payload = Buffer.from(encryptedB64 || '', 'base64');
  const iv = Buffer.from(ivB64 || '', 'base64');
  if (!payload.length || iv.length !== 12) {
    throw new Error('Invalid encrypted secret payload');
  }
  const tag = payload.subarray(payload.length - 16);
  const ciphertext = payload.subarray(0, payload.length - 16);
  const decipher = crypto.createDecipheriv('aes-256-gcm', ENCRYPTION_KEY, iv);
  decipher.setAuthTag(tag);
  const decrypted = Buffer.concat([decipher.update(ciphertext), decipher.final()]);
  return decrypted.toString('utf8');
}

function generateBackupCodes(count = 8) {
  const codes = [];
  for (let i = 0; i < count; i++) {
    const raw = crypto.randomBytes(4).toString('hex').toUpperCase();
    codes.push(`${raw.slice(0, 4)}-${raw.slice(4)}`);
  }
  return codes;
}

function hashBackupCodes(codes) {
  const map = {};
  for (const code of codes || []) {
    map[_sha256(String(code).replace(/\s+/g, '').toUpperCase())] = false;
  }
  return map;
}

function consumeBackupCode(hashedCodesMap, providedCode) {
  const normalized = String(providedCode || '').replace(/\s+/g, '').toUpperCase();
  if (!normalized) return { ok: false, map: hashedCodesMap || null };
  const key = _sha256(normalized);
  const map = { ...(hashedCodesMap || {}) };
  if (!Object.prototype.hasOwnProperty.call(map, key)) {
    return { ok: false, map };
  }
  if (map[key] === true) {
    return { ok: false, map };
  }
  map[key] = true;
  return { ok: true, map };
}

function signLoginChallenge(payload, expiresInMs = 5 * 60 * 1000) {
  const exp = Date.now() + expiresInMs;
  const serialized = JSON.stringify({ ...payload, exp });
  const sig = crypto.createHmac('sha256', ENCRYPTION_KEY).update(serialized).digest('base64url');
  return Buffer.from(serialized).toString('base64url') + '.' + sig;
}

function verifyLoginChallenge(token) {
  const parts = String(token || '').split('.');
  if (parts.length !== 2) return null;
  const [payloadB64, sig] = parts;
  const serialized = Buffer.from(payloadB64, 'base64url').toString('utf8');
  const expected = crypto.createHmac('sha256', ENCRYPTION_KEY).update(serialized).digest('base64url');
  if (sig !== expected) return null;
  const payload = JSON.parse(serialized);
  if (!payload || !payload.exp || Date.now() > Number(payload.exp)) return null;
  return payload;
}

module.exports = {
  generateTotpSecret,
  verifyTotpCode,
  encryptSecret,
  decryptSecret,
  generateBackupCodes,
  hashBackupCodes,
  consumeBackupCode,
  signLoginChallenge,
  verifyLoginChallenge,
};
