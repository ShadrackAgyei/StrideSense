<?php

declare(strict_types=1);

use StrideSense\ApiController;
use StrideSense\AuthService;
use StrideSense\Database;
use StrideSense\Env;
use StrideSense\Http;

require_once __DIR__ . '/../src/Env.php';
require_once __DIR__ . '/../src/Database.php';
require_once __DIR__ . '/../src/Http.php';
require_once __DIR__ . '/../src/AuthService.php';
require_once __DIR__ . '/../src/ApiController.php';

Env::load(__DIR__ . '/../.env');

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Authorization, Content-Type, Idempotency-Key');
header('Access-Control-Allow-Methods: GET, POST, PATCH, DELETE, OPTIONS');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

set_exception_handler(function (Throwable $e): void {
    Http::error(500, 'INTERNAL_ERROR', $e->getMessage());
});

$pdo = Database::pdo();
$auth = new AuthService($pdo);
$api = new ApiController($pdo, $auth);

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$uri = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);
$path = rtrim((string) $uri, '/');
$path = $path === '' ? '/' : $path;

// Support deployments behind a URL prefix (e.g. /~user/api/index.php/v1/...).
$v1Pos = strpos($path, '/v1/');
if ($v1Pos !== false) {
    $path = substr($path, $v1Pos);
} elseif (str_ends_with($path, '/v1')) {
    $path = '/v1';
}

if ($path === '/v1/health' && $method === 'GET') {
    Http::data(200, ['ok' => true, 'service' => 'stridesense-backend']);
}

if ($path === '/v1/auth/register' && $method === 'POST') {
    $api->register();
}
if ($path === '/v1/auth/login' && $method === 'POST') {
    $api->login();
}
if ($path === '/v1/auth/refresh' && $method === 'POST') {
    $api->refresh();
}
if ($path === '/v1/auth/logout' && $method === 'POST') {
    $api->logout();
}
if ($path === '/v1/me' && $method === 'GET') {
    $api->me();
}
if ($path === '/v1/me/profile' && $method === 'PATCH') {
    $api->patchProfile();
}
if ($path === '/v1/me/avatar' && $method === 'POST') {
    $api->uploadAvatar();
}
if ($path === '/v1/clubs' && $method === 'GET') {
    $api->listClubs();
}
if ($path === '/v1/clubs' && $method === 'POST') {
    $api->createClub();
}
if (preg_match('#^/v1/clubs/(\d+)$#', $path, $m) && $method === 'GET') {
    $api->clubDetail((int) $m[1]);
}
if (preg_match('#^/v1/clubs/(\d+)/join$#', $path, $m) && $method === 'POST') {
    $api->joinClub((int) $m[1]);
}
if (preg_match('#^/v1/clubs/(\d+)/leave$#', $path, $m) && $method === 'POST') {
    $api->leaveClub((int) $m[1]);
}
if ($path === '/v1/challenges' && $method === 'GET') {
    $api->listChallenges();
}
if (preg_match('#^/v1/challenges/(\d+)$#', $path, $m) && $method === 'GET') {
    $api->challengeDetail((int) $m[1]);
}
if (preg_match('#^/v1/challenges/(\d+)/join$#', $path, $m) && $method === 'POST') {
    $api->joinChallenge((int) $m[1]);
}
if ($path === '/v1/leaderboard' && $method === 'GET') {
    $api->leaderboard();
}
if ($path === '/v1/workouts/start' && $method === 'POST') {
    $api->workoutStart();
}
if ($path === '/v1/workouts/history' && $method === 'GET') {
    $api->workoutHistory();
}
if (preg_match('#^/v1/workouts/(\d+)/pause$#', $path, $m) && $method === 'POST') {
    $api->workoutPause((int) $m[1]);
}
if (preg_match('#^/v1/workouts/(\d+)/resume$#', $path, $m) && $method === 'POST') {
    $api->workoutResume((int) $m[1]);
}
if (preg_match('#^/v1/workouts/(\d+)/complete$#', $path, $m) && $method === 'POST') {
    $api->workoutComplete((int) $m[1]);
}
if (preg_match('#^/v1/workouts/(\d+)/samples$#', $path, $m) && $method === 'POST') {
    $api->workoutSamples((int) $m[1]);
}
if (preg_match('#^/v1/workouts/(\d+)$#', $path, $m) && $method === 'GET') {
    $api->workoutDetail((int) $m[1]);
}

Http::error(404, 'NOT_FOUND', 'route not found');
