<?php

declare(strict_types=1);

namespace StrideSense;

use RuntimeException;

final class Http
{
    public static function jsonBody(): array
    {
        $raw = file_get_contents('php://input');
        if ($raw === false || trim($raw) === '') {
            return [];
        }

        $decoded = json_decode($raw, true);
        if (!is_array($decoded)) {
            throw new RuntimeException('Invalid JSON body');
        }

        return $decoded;
    }

    public static function json(int $status, array $payload): never
    {
        http_response_code($status);
        header('Content-Type: application/json');
        echo json_encode($payload, JSON_UNESCAPED_SLASHES);
        exit;
    }

    public static function data(int $status, array $data, array $meta = []): never
    {
        self::json($status, ['data' => $data, 'meta' => $meta]);
    }

    public static function noContent(): never
    {
        http_response_code(204);
        exit;
    }

    public static function error(int $status, string $code, string $message, array $details = []): never
    {
        self::json($status, [
            'error' => [
                'code' => $code,
                'message' => $message,
                'details' => $details,
            ],
        ]);
    }

    public static function bearerToken(): ?string
    {
        $candidates = [
            $_SERVER['HTTP_AUTHORIZATION'] ?? null,
            $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? null,
        ];

        if (function_exists('getallheaders')) {
            $headers = getallheaders();
            if (is_array($headers)) {
                $candidates[] = $headers['Authorization'] ?? null;
                $candidates[] = $headers['authorization'] ?? null;
            }
        }

        $header = null;
        foreach ($candidates as $candidate) {
            if (is_string($candidate) && trim($candidate) !== '') {
                $header = trim($candidate);
                break;
            }
        }

        if ($header === null) {
            return null;
        }
        if (!preg_match('/^Bearer\s+(.+)$/i', $header, $matches)) {
            return null;
        }
        return trim($matches[1]);
    }
}
