CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  password TEXT,
  full_name TEXT,
  role TEXT,
  email TEXT,
  phone TEXT,
  department TEXT,
  avatar_url TEXT,
  join_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
