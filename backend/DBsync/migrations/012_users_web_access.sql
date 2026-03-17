-- Pridanie stĺpca web_access: ak false, používateľ sa nemôže prihlásiť na web.
-- PC appka sync automaticky nevytvorí web prístup – admin ho musí povoliť manuálne.
ALTER TABLE users ADD COLUMN IF NOT EXISTS web_access BOOLEAN NOT NULL DEFAULT false;

-- Existujúci admin účty (role = 'admin') dostanú web_access automaticky.
UPDATE users SET web_access = true WHERE role = 'admin';
