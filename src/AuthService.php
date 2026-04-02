<?php

declare(strict_types=1);

namespace StrideSense;

use DateInterval;
use DateTimeImmutable;
use PDO;
use RuntimeException;

final class AuthService
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    public function register(array $payload): array
    {
        $email = strtolower(trim((string) ($payload['email'] ?? '')));
        $password = (string) ($payload['password'] ?? '');
        $firstName = trim((string) ($payload['first_name'] ?? ''));
        $lastName = trim((string) ($payload['last_name'] ?? ''));
        $phone = trim((string) ($payload['phone'] ?? ''));

        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            Http::error(422, 'VALIDATION_ERROR', 'email is invalid', ['field' => 'email']);
        }
        if (strlen($password) < 8) {
            Http::error(422, 'VALIDATION_ERROR', 'password must be at least 8 chars', ['field' => 'password']);
        }
        if ($firstName === '' || $lastName === '') {
            Http::error(422, 'VALIDATION_ERROR', 'first_name and last_name are required');
        }
        if ($phone === '') {
            Http::error(422, 'VALIDATION_ERROR', 'phone is required', ['field' => 'phone']);
        }
        $digitsOnly = preg_replace('/\D+/', '', $phone) ?? '';
        if (strlen($digitsOnly) < 10 || strlen($digitsOnly) > 15) {
            Http::error(422, 'VALIDATION_ERROR', 'phone must contain 10 to 15 digits', ['field' => 'phone']);
        }

        $stmt = $this->pdo->prepare('SELECT id FROM users WHERE email = :email LIMIT 1');
        $stmt->execute(['email' => $email]);
        if ($stmt->fetch()) {
            Http::error(409, 'CONFLICT', 'email already registered');
        }

        $hash = password_hash($password, PASSWORD_ARGON2ID);
        if ($hash === false) {
            throw new RuntimeException('Failed to hash password');
        }

        $ins = $this->pdo->prepare(
            'INSERT INTO users (email, password_hash, first_name, last_name, phone) VALUES (:email, :password_hash, :first_name, :last_name, :phone)'
        );
        $ins->execute([
            'email' => $email,
            'password_hash' => $hash,
            'first_name' => $firstName,
            'last_name' => $lastName,
            'phone' => $phone !== '' ? $phone : null,
        ]);

        $userId = (int) $this->pdo->lastInsertId();

        $profileIns = $this->pdo->prepare('INSERT INTO user_profiles (user_id) VALUES (:user_id)');
        $profileIns->execute(['user_id' => $userId]);

        return $this->issueTokensForUser($userId);
    }

    public function login(array $payload): array
    {
        $email = strtolower(trim((string) ($payload['email'] ?? '')));
        $password = (string) ($payload['password'] ?? '');

        $stmt = $this->pdo->prepare('SELECT id, password_hash FROM users WHERE email = :email LIMIT 1');
        $stmt->execute(['email' => $email]);
        $row = $stmt->fetch();
        if (!$row || !password_verify($password, (string) $row['password_hash'])) {
            Http::error(401, 'UNAUTHORIZED', 'invalid credentials');
        }

        return $this->issueTokensForUser((int) $row['id']);
    }

    public function refresh(array $payload): array
    {
        $refreshToken = (string) ($payload['refresh_token'] ?? '');
        if ($refreshToken === '') {
            Http::error(422, 'VALIDATION_ERROR', 'refresh_token is required', ['field' => 'refresh_token']);
        }

        $tokenHash = hash('sha256', $refreshToken);
        $stmt = $this->pdo->prepare(
            'SELECT id, user_id, expires_at, revoked_at FROM auth_refresh_tokens WHERE token_hash = :token_hash LIMIT 1'
        );
        $stmt->execute(['token_hash' => $tokenHash]);
        $row = $stmt->fetch();

        if (!$row || $row['revoked_at'] !== null || new DateTimeImmutable((string) $row['expires_at']) < new DateTimeImmutable()) {
            Http::error(401, 'UNAUTHORIZED', 'invalid refresh token');
        }

        $this->revokeRefreshToken((int) $row['id']);

        return $this->issueTokensForUser((int) $row['user_id']);
    }

    public function logout(array $payload): void
    {
        $refreshToken = (string) ($payload['refresh_token'] ?? '');
        if ($refreshToken === '') {
            Http::noContent();
        }

        $tokenHash = hash('sha256', $refreshToken);
        $stmt = $this->pdo->prepare('UPDATE auth_refresh_tokens SET revoked_at = NOW() WHERE token_hash = :token_hash');
        $stmt->execute(['token_hash' => $tokenHash]);

        Http::noContent();
    }

    public function requireUserId(): int
    {
        $token = Http::bearerToken();
        if ($token === null || $token === '') {
            Http::error(401, 'UNAUTHORIZED', 'missing bearer token');
        }
        $tokenHash = hash('sha256', $token);
        $stmt = $this->pdo->prepare(
            'SELECT user_id, expires_at, revoked_at FROM auth_access_tokens WHERE token_hash = :token_hash LIMIT 1'
        );
        $stmt->execute(['token_hash' => $tokenHash]);
        $row = $stmt->fetch();
        if (!$row || $row['revoked_at'] !== null || new DateTimeImmutable((string) $row['expires_at']) < new DateTimeImmutable()) {
            Http::error(401, 'UNAUTHORIZED', 'invalid or expired access token');
        }
        return (int) $row['user_id'];
    }

    private function issueTokensForUser(int $userId): array
    {
        $accessRaw = bin2hex(random_bytes(32));
        $refreshRaw = bin2hex(random_bytes(48));
        $accessHash = hash('sha256', $accessRaw);
        $refreshHash = hash('sha256', $refreshRaw);

        $accessTtl = Env::int('ACCESS_TOKEN_TTL_MINUTES', 15);
        $refreshTtl = Env::int('REFRESH_TOKEN_TTL_DAYS', 30);

        $now = new DateTimeImmutable('now');
        $accessExpires = $now->add(new DateInterval('PT' . $accessTtl . 'M'));
        $refreshExpires = $now->add(new DateInterval('P' . $refreshTtl . 'D'));

        $accIns = $this->pdo->prepare(
            'INSERT INTO auth_access_tokens (user_id, token_hash, issued_at, expires_at, user_agent, ip_address)
             VALUES (:user_id, :token_hash, :issued_at, :expires_at, :user_agent, :ip_address)'
        );
        $accIns->execute([
            'user_id' => $userId,
            'token_hash' => $accessHash,
            'issued_at' => $now->format('Y-m-d H:i:s'),
            'expires_at' => $accessExpires->format('Y-m-d H:i:s'),
            'user_agent' => substr((string) ($_SERVER['HTTP_USER_AGENT'] ?? ''), 0, 255),
            'ip_address' => substr((string) ($_SERVER['REMOTE_ADDR'] ?? ''), 0, 64),
        ]);

        $refIns = $this->pdo->prepare(
            'INSERT INTO auth_refresh_tokens (user_id, token_hash, issued_at, expires_at, user_agent, ip_address)
             VALUES (:user_id, :token_hash, :issued_at, :expires_at, :user_agent, :ip_address)'
        );
        $refIns->execute([
            'user_id' => $userId,
            'token_hash' => $refreshHash,
            'issued_at' => $now->format('Y-m-d H:i:s'),
            'expires_at' => $refreshExpires->format('Y-m-d H:i:s'),
            'user_agent' => substr((string) ($_SERVER['HTTP_USER_AGENT'] ?? ''), 0, 255),
            'ip_address' => substr((string) ($_SERVER['REMOTE_ADDR'] ?? ''), 0, 64),
        ]);

        $userStmt = $this->pdo->prepare(
            'SELECT id, email, first_name, last_name, phone, created_at, updated_at FROM users WHERE id = :id'
        );
        $userStmt->execute(['id' => $userId]);
        $user = $userStmt->fetch();
        if (!$user) {
            throw new RuntimeException('Unable to load user after token issue');
        }

        return [
            'user' => $user,
            'tokens' => [
                'access_token' => $accessRaw,
                'refresh_token' => $refreshRaw,
                'access_expires_at' => $accessExpires->format(DATE_ATOM),
                'refresh_expires_at' => $refreshExpires->format(DATE_ATOM),
                'token_type' => 'Bearer',
            ],
        ];
    }

    private function revokeRefreshToken(int $id): void
    {
        $stmt = $this->pdo->prepare('UPDATE auth_refresh_tokens SET revoked_at = NOW() WHERE id = :id');
        $stmt->execute(['id' => $id]);
    }
}
