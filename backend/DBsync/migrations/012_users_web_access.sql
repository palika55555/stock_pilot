-- Pridanie stĺpca web_access: ak false, používateľ sa nemôže prihlásiť na web.
-- PC appka sync automaticky nevytvorí web prístup – admin ho musí povoliť manuálne.
ALTER TABLE users ADD COLUMN IF NOT EXISTS web_access BOOLEAN NOT NULL DEFAULT false;

-- Všetci existujúci používatelia dostanú web_access = true (boli tu pred týmto stĺpcom).
-- Noví používatelia vytvorení iba cez PC appku budú mať false (nastavené v userSync.js).
UPDATE users SET web_access = true;
