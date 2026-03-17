-- Existujúci používatelia (pred zavedením web_access) dostanú prístup na web.
-- Noví používatelia synced cez PC appku budú mať web_access = false (default).
UPDATE users SET web_access = true WHERE web_access = false;
