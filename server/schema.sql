-- PostgreSQL schema for the production store.
-- The server currently ships an in-memory Store (lib/src/store.dart); this file is the
-- target schema for a Postgres-backed implementation of the same interface.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token_hash    CHAR(64) NOT NULL UNIQUE,          -- SHA-256 of the session token
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at  TIMESTAMPTZ
);

CREATE TABLE profiles (
  user_id     UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  username    VARCHAR(20) NOT NULL,
  avatar      SMALLINT NOT NULL DEFAULT 0,
  balance     BIGINT NOT NULL DEFAULT 10000 CHECK (balance >= 0)   -- virtual chips only
);

CREATE TABLE rooms (
  code         CHAR(7) PRIMARY KEY,
  host_id      UUID NOT NULL REFERENCES users(id),
  max_players  SMALLINT NOT NULL CHECK (max_players BETWEEN 2 AND 6),
  boot         INTEGER NOT NULL CHECK (boot > 0),
  is_public    BOOLEAN NOT NULL DEFAULT false,
  status       VARCHAR(12) NOT NULL DEFAULT 'waiting',
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE room_players (
  room_code  CHAR(7) NOT NULL REFERENCES rooms(code) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES users(id),
  joined_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (room_code, user_id)
);
CREATE INDEX room_players_user_idx ON room_players(user_id);

CREATE TABLE games (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_code    CHAR(7) NOT NULL,
  started_at   TIMESTAMPTZ NOT NULL,
  ended_at     TIMESTAMPTZ,
  pot          BIGINT,
  hand_name    VARCHAR(20)
);
CREATE INDEX games_room_idx ON games(room_code, started_at DESC);

CREATE TABLE game_players (
  game_id     UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES users(id),
  start_chips BIGINT NOT NULL,
  end_chips   BIGINT,
  is_winner   BOOLEAN NOT NULL DEFAULT false,
  PRIMARY KEY (game_id, user_id)
);
CREATE INDEX game_players_user_idx ON game_players(user_id);

CREATE TABLE game_rounds (
  game_id   UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  turn_no   INTEGER NOT NULL,
  stake     BIGINT NOT NULL,
  pot       BIGINT NOT NULL,
  PRIMARY KEY (game_id, turn_no)
);

-- Append-only audit trail of every client action, accepted or not (anti-cheat forensics).
CREATE TABLE game_actions (
  id         BIGSERIAL PRIMARY KEY,
  at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  room_code  CHAR(7) NOT NULL,
  user_id    UUID NOT NULL REFERENCES users(id),
  action_id  VARCHAR(64) NOT NULL,
  action     JSONB NOT NULL,
  accepted   BOOLEAN NOT NULL,
  error      TEXT,
  UNIQUE (room_code, user_id, action_id)               -- idempotency key
);
CREATE INDEX game_actions_user_idx ON game_actions(user_id, at DESC);

CREATE TABLE transactions (
  id        BIGSERIAL PRIMARY KEY,
  at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  user_id   UUID NOT NULL REFERENCES users(id),
  game_id   UUID REFERENCES games(id),
  delta     BIGINT NOT NULL,
  reason    VARCHAR(16) NOT NULL
);
CREATE INDEX transactions_user_idx ON transactions(user_id, at DESC);

CREATE TABLE friendships (
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  friend_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status     VARCHAR(10) NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, friend_id),
  CHECK (user_id <> friend_id)
);

CREATE TABLE game_history (
  user_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  game_id   UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  net       BIGINT NOT NULL,
  PRIMARY KEY (user_id, game_id)
);
