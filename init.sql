CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    joined TIMESTAMP NOT NULL DEFAULT now(),
    bio TEXT
);
CREATE TABLE auth_codes (
  code_hash TEXT NOT NULL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  code_challenge TEXT NOT NULL,
  code_challenge_method TEXT NOT NULL CHECK (
    code_challenge_method IN ('S256')
  ),
  expires_at TIMESTAMP NOT NULL DEFAULT (now() + INTERVAL '10 minutes'),
  used_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT now()
);
CREATE TABLE sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  expires_at TIMESTAMP NOT NULL,
  revoked_at TIMESTAMP
);
CREATE TABLE guilds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  owner_id UUID REFERENCES users(id) ON DELETE SET NULL,
  icon_url TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT now()
);
CREATE TABLE guild_members (
  guild_id UUID REFERENCES guilds(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  nickname VARCHAR(100) NOT NULL,
  joined_at TIMESTAMP NOT NULL DEFAULT now(),
  PRIMARY KEY (guild_id, user_id)
);
CREATE TABLE channels (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  guild_id UUID NOT NULL REFERENCES guilds(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  position INT DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT now()
);
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  author_id UUID REFERENCES channels(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_messages_channel_created ON messages(channel_id, created_at DESC);
CREATE INDEX idx_sessions_user_id ON sessions(user_id);
