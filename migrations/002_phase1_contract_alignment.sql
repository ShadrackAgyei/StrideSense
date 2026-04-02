-- StrideSense backend phase 1 contract alignment
-- Adds idempotency key storage used by sample/complete APIs

CREATE TABLE IF NOT EXISTS idempotency_keys (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  key_value VARCHAR(128) NOT NULL UNIQUE,
  user_id BIGINT UNSIGNED NOT NULL,
  endpoint VARCHAR(120) NOT NULL,
  response_code SMALLINT UNSIGNED NOT NULL,
  response_body JSON NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at DATETIME NOT NULL,
  CONSTRAINT fk_idempotency_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_idempotency_expiry (expires_at)
);
