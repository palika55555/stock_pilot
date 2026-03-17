-- Pridanie stĺpca is_blocked pre blokovanie používateľov (admin môže zablokovať prihlásenie).
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_blocked BOOLEAN NOT NULL DEFAULT false;
