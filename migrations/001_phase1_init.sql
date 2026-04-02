-- StrideSense backend phase 1 migration
-- Run with MySQL 8+

CREATE TABLE users (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  phone VARCHAR(30),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE user_profiles (
  user_id BIGINT UNSIGNED PRIMARY KEY,
  bio VARCHAR(500),
  avatar_url VARCHAR(500),
  city VARCHAR(120),
  privacy_level ENUM('public', 'friends', 'private') NOT NULL DEFAULT 'public',
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_user_profiles_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE auth_access_tokens (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  token_hash VARCHAR(255) NOT NULL UNIQUE,
  issued_at DATETIME NOT NULL,
  expires_at DATETIME NOT NULL,
  revoked_at DATETIME NULL,
  user_agent VARCHAR(255),
  ip_address VARCHAR(64),
  CONSTRAINT fk_access_tokens_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_access_user (user_id),
  INDEX idx_access_expires (expires_at)
);

CREATE TABLE auth_refresh_tokens (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  token_hash VARCHAR(255) NOT NULL UNIQUE,
  issued_at DATETIME NOT NULL,
  expires_at DATETIME NOT NULL,
  revoked_at DATETIME NULL,
  user_agent VARCHAR(255),
  ip_address VARCHAR(64),
  CONSTRAINT fk_refresh_tokens_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_refresh_user (user_id),
  INDEX idx_refresh_expires (expires_at)
);

CREATE TABLE clubs (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(160) NOT NULL UNIQUE,
  description TEXT,
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_clubs_created_by FOREIGN KEY (created_by) REFERENCES users(id)
);

CREATE TABLE club_members (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  club_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  role ENUM('owner', 'admin', 'member') NOT NULL DEFAULT 'member',
  joined_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_club_member (club_id, user_id),
  CONSTRAINT fk_club_members_club FOREIGN KEY (club_id) REFERENCES clubs(id) ON DELETE CASCADE,
  CONSTRAINT fk_club_members_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE challenges (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  club_id BIGINT UNSIGNED NULL,
  title VARCHAR(180) NOT NULL,
  description TEXT,
  type ENUM('distance', 'count', 'time') NOT NULL DEFAULT 'distance',
  target_value DECIMAL(10,2) NOT NULL,
  start_at DATETIME NOT NULL,
  end_at DATETIME NOT NULL,
  status ENUM('upcoming', 'active', 'completed', 'cancelled') NOT NULL DEFAULT 'upcoming',
  created_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_challenges_club FOREIGN KEY (club_id) REFERENCES clubs(id) ON DELETE SET NULL,
  CONSTRAINT fk_challenges_creator FOREIGN KEY (created_by) REFERENCES users(id),
  INDEX idx_challenges_status (status)
);

CREATE TABLE challenge_participants (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  challenge_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  joined_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_challenge_user (challenge_id, user_id),
  CONSTRAINT fk_challenge_participants_challenge FOREIGN KEY (challenge_id) REFERENCES challenges(id) ON DELETE CASCADE,
  CONSTRAINT fk_challenge_participants_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE workouts (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  challenge_id BIGINT UNSIGNED NULL,
  activity_type ENUM('run', 'walk', 'cycle', 'workout') NOT NULL DEFAULT 'run',
  status ENUM('running', 'paused', 'completed', 'abandoned') NOT NULL DEFAULT 'running',
  started_at DATETIME NOT NULL,
  ended_at DATETIME NULL,
  duration_sec INT UNSIGNED NULL,
  distance_m DECIMAL(10,2) NULL,
  avg_pace_sec_per_km DECIMAL(10,2) NULL,
  calories_kcal DECIMAL(10,2) NULL,
  category VARCHAR(120) NULL,
  source ENUM('mobile', 'healthkit', 'health_connect', 'manual') NOT NULL DEFAULT 'mobile',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_workouts_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_workouts_challenge FOREIGN KEY (challenge_id) REFERENCES challenges(id) ON DELETE SET NULL,
  INDEX idx_workouts_user_time (user_id, started_at),
  INDEX idx_workouts_status (status)
);

CREATE TABLE workout_events (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  workout_id BIGINT UNSIGNED NOT NULL,
  event_type ENUM('start', 'pause', 'resume', 'complete') NOT NULL,
  event_at DATETIME NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_workout_events_workout FOREIGN KEY (workout_id) REFERENCES workouts(id) ON DELETE CASCADE,
  INDEX idx_workout_events_workout_time (workout_id, event_at)
);

CREATE TABLE workout_samples (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  workout_id BIGINT UNSIGNED NOT NULL,
  captured_at DATETIME NOT NULL,
  latitude DECIMAL(10,7) NULL,
  longitude DECIMAL(10,7) NULL,
  altitude_m DECIMAL(8,2) NULL,
  distance_m DECIMAL(10,2) NULL,
  pace_sec_per_km DECIMAL(10,2) NULL,
  heart_rate_bpm SMALLINT UNSIGNED NULL,
  steps INT UNSIGNED NULL,
  calories_kcal DECIMAL(10,2) NULL,
  source ENUM('gps', 'healthkit', 'health_connect', 'manual') NOT NULL DEFAULT 'gps',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_workout_samples_workout FOREIGN KEY (workout_id) REFERENCES workouts(id) ON DELETE CASCADE,
  INDEX idx_samples_workout_time (workout_id, captured_at)
);

-- Optional starter seed data
INSERT INTO challenges (club_id, title, description, type, target_value, start_at, end_at, status, created_by)
SELECT NULL, 'Marathon Madness', 'Run 42 km in 4 weeks', 'distance', 42000, UTC_TIMESTAMP(), DATE_ADD(UTC_TIMESTAMP(), INTERVAL 28 DAY), 'active', u.id
FROM users u LIMIT 1;
