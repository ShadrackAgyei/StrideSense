<?php

declare(strict_types=1);

namespace StrideSense;

use PDO;

final class ApiController
{
    public function __construct(
        private readonly PDO $pdo,
        private readonly AuthService $auth
    ) {
    }

    public function register(): never
    {
        $payload = Http::jsonBody();
        Http::data(201, $this->auth->register($payload));
    }

    public function login(): never
    {
        $payload = Http::jsonBody();
        Http::data(200, $this->auth->login($payload));
    }

    public function refresh(): never
    {
        $payload = Http::jsonBody();
        Http::data(200, $this->auth->refresh($payload));
    }

    public function logout(): never
    {
        $payload = Http::jsonBody();
        $this->auth->logout($payload);
    }

    public function me(): never
    {
        $userId = $this->auth->requireUserId();

        $stmt = $this->pdo->prepare(
            'SELECT
                u.id, u.email, u.first_name, u.last_name, u.phone, u.created_at, u.updated_at,
                p.bio, p.avatar_url, p.city, p.privacy_level
             FROM users u
             LEFT JOIN user_profiles p ON p.user_id = u.id
             WHERE u.id = :id
             LIMIT 1'
        );
        $stmt->execute(['id' => $userId]);
        $user = $stmt->fetch();
        if (!$user) {
            Http::error(404, 'NOT_FOUND', 'user not found');
        }

        $statsStmt = $this->pdo->prepare(
            'SELECT
                COALESCE(SUM(distance_m), 0) AS total_distance_m,
                COUNT(*) AS workouts_count
             FROM workouts
             WHERE user_id = :user_id AND status = "completed"'
        );
        $statsStmt->execute(['user_id' => $userId]);
        $stats = $statsStmt->fetch() ?: ['total_distance_m' => 0, 'workouts_count' => 0];

        Http::data(200, [
            'user' => $user,
            'stats' => $stats,
        ]);
    }

    public function patchProfile(): never
    {
        $userId = $this->auth->requireUserId();
        $payload = Http::jsonBody();

        $firstName = isset($payload['first_name']) ? trim((string) $payload['first_name']) : null;
        $lastName = isset($payload['last_name']) ? trim((string) $payload['last_name']) : null;
        $phone = isset($payload['phone']) ? trim((string) $payload['phone']) : null;
        $bio = isset($payload['bio']) ? trim((string) $payload['bio']) : null;
        $city = isset($payload['city']) ? trim((string) $payload['city']) : null;
        $avatarUrl = isset($payload['avatar_url']) ? trim((string) $payload['avatar_url']) : null;

        if ($firstName !== null) {
            $stmt = $this->pdo->prepare('UPDATE users SET first_name = :first_name WHERE id = :id');
            $stmt->execute(['first_name' => $firstName, 'id' => $userId]);
        }
        if ($lastName !== null) {
            $stmt = $this->pdo->prepare('UPDATE users SET last_name = :last_name WHERE id = :id');
            $stmt->execute(['last_name' => $lastName, 'id' => $userId]);
        }
        if ($phone !== null) {
            $stmt = $this->pdo->prepare('UPDATE users SET phone = :phone WHERE id = :id');
            $stmt->execute(['phone' => $phone, 'id' => $userId]);
        }
        if ($bio !== null || $city !== null || $avatarUrl !== null) {
            $stmt = $this->pdo->prepare(
                'INSERT INTO user_profiles (user_id, bio, city, avatar_url)
                 VALUES (:user_id, :bio, :city, :avatar_url)
                 ON DUPLICATE KEY UPDATE
                  bio = COALESCE(:bio_update, bio),
                  city = COALESCE(:city_update, city),
                  avatar_url = COALESCE(:avatar_url_update, avatar_url)'
            );
            $stmt->execute([
                'user_id' => $userId,
                'bio' => $bio,
                'city' => $city,
                'avatar_url' => $avatarUrl,
                'bio_update' => $bio,
                'city_update' => $city,
                'avatar_url_update' => $avatarUrl,
            ]);
        }

        $this->me();
    }

    public function uploadAvatar(): never
    {
        $userId = $this->auth->requireUserId();
        if (!isset($_FILES['avatar'])) {
            Http::error(422, 'VALIDATION_ERROR', 'avatar file is required', ['field' => 'avatar']);
        }

        $file = $_FILES['avatar'];
        if (!is_array($file)) {
            Http::error(422, 'VALIDATION_ERROR', 'invalid avatar payload', ['field' => 'avatar']);
        }

        if (($file['error'] ?? UPLOAD_ERR_OK) !== UPLOAD_ERR_OK) {
            Http::error(422, 'VALIDATION_ERROR', 'avatar upload failed', ['field' => 'avatar']);
        }

        $tmpPath = (string) ($file['tmp_name'] ?? '');
        if ($tmpPath === '' || !is_uploaded_file($tmpPath)) {
            Http::error(422, 'VALIDATION_ERROR', 'invalid uploaded file', ['field' => 'avatar']);
        }

        $sizeBytes = (int) ($file['size'] ?? 0);
        if ($sizeBytes <= 0 || $sizeBytes > 5 * 1024 * 1024) {
            Http::error(422, 'VALIDATION_ERROR', 'avatar must be <= 5MB', ['field' => 'avatar']);
        }

        $finfo = new \finfo(FILEINFO_MIME_TYPE);
        $mime = (string) $finfo->file($tmpPath);
        $ext = match ($mime) {
            'image/jpeg' => 'jpg',
            'image/png' => 'png',
            'image/webp' => 'webp',
            default => null,
        };
        if ($ext === null) {
            Http::error(422, 'VALIDATION_ERROR', 'avatar must be jpeg/png/webp', ['field' => 'avatar']);
        }

        $filename = sprintf('u%d_%s.%s', $userId, bin2hex(random_bytes(8)), $ext);
        $relativeUploadPath = 'uploads/avatars';
        $requestPath = (string) parse_url((string) ($_SERVER['REQUEST_URI'] ?? ''), PHP_URL_PATH);
        $userPrefix = '';
        if (preg_match('#^(/~[^/]+)#', $requestPath, $m) === 1) {
            $userPrefix = $m[1];
        }

        $candidateDirs = [];
        $scriptFilename = (string) ($_SERVER['SCRIPT_FILENAME'] ?? '');
        $scriptName = (string) ($_SERVER['SCRIPT_NAME'] ?? '');
        $scriptPrefix = rtrim(str_replace('\\', '/', dirname($scriptName)), '/');
        if ($scriptPrefix === '.' || $scriptPrefix === '/') {
            $scriptPrefix = '';
        }

        if ($scriptFilename !== '') {
            $candidateDirs[] = [
                'dir' => dirname($scriptFilename) . '/' . $relativeUploadPath,
                'url_prefix' => ($scriptPrefix !== '' ? $scriptPrefix : '') . '/uploads/avatars',
            ];
            $candidateDirs[] = [
                'dir' => dirname(dirname($scriptFilename)) . '/' . $relativeUploadPath,
                'url_prefix' => ($userPrefix !== '' ? $userPrefix : '') . '/uploads/avatars',
            ];
        }
        $candidateDirs[] = [
            'dir' => dirname(__DIR__) . '/public/' . $relativeUploadPath,
            'url_prefix' => ($scriptPrefix !== '' ? $scriptPrefix : '') . '/uploads/avatars',
        ];

        $publicDir = null;
        $avatarUrlPrefix = '';
        foreach ($candidateDirs as $candidate) {
            $dir = (string) ($candidate['dir'] ?? '');
            if ((is_dir($dir) || @mkdir($dir, 0775, true)) && is_writable($dir)) {
                $publicDir = $dir;
                $avatarUrlPrefix = (string) ($candidate['url_prefix'] ?? '/uploads/avatars');
                break;
            }
        }
        if ($publicDir === null) {
            Http::error(500, 'INTERNAL_ERROR', 'unable to create avatar directory');
        }
        $targetPath = $publicDir . '/' . $filename;
        if (!move_uploaded_file($tmpPath, $targetPath)) {
            Http::error(500, 'INTERNAL_ERROR', 'unable to store avatar');
        }

        $avatarPath = rtrim($avatarUrlPrefix, '/') . '/' . $filename;

        $baseUrl = rtrim((string) Env::get('APP_URL', ''), '/');
        $requestHost = trim((string) ($_SERVER['HTTP_HOST'] ?? ''));
        $forwardedProto = trim((string) ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? ''));
        $httpsFlag = (string) ($_SERVER['HTTPS'] ?? '');
        $requestScheme = $forwardedProto !== ''
            ? strtolower($forwardedProto)
            : (($httpsFlag !== '' && strtolower($httpsFlag) !== 'off') ? 'https' : 'http');
        if ($requestHost !== '' && (
            $baseUrl === '' ||
            str_contains($baseUrl, 'localhost') ||
            str_contains($baseUrl, '127.0.0.1')
        )) {
            $baseUrl = $requestScheme . '://' . $requestHost;
        }
        $avatarUrl = $baseUrl !== ''
            ? $baseUrl . $avatarPath
            : $avatarPath;

        $stmt = $this->pdo->prepare(
            'INSERT INTO user_profiles (user_id, avatar_url)
             VALUES (:user_id, :avatar_url)
             ON DUPLICATE KEY UPDATE avatar_url = :avatar_url_update'
        );
        $stmt->execute([
            'user_id' => $userId,
            'avatar_url' => $avatarUrl,
            'avatar_url_update' => $avatarUrl,
        ]);

        Http::data(200, ['avatar_url' => $avatarUrl]);
    }

    public function listClubs(): never
    {
        $userId = $this->auth->requireUserId();
        $q = trim((string) ($_GET['q'] ?? ''));
        $page = max(1, (int) ($_GET['page'] ?? 1));
        $limit = min(100, max(1, (int) ($_GET['limit'] ?? 20)));
        $offset = ($page - 1) * $limit;

        if ($q !== '') {
            $stmt = $this->pdo->prepare(
                'SELECT
                    c.id,
                    c.name,
                    c.description,
                    c.created_at,
                    COUNT(cm.id) AS member_count,
                    MAX(CASE WHEN my.user_id IS NULL THEN 0 ELSE 1 END) AS joined
                 FROM clubs c
                 LEFT JOIN club_members cm ON cm.club_id = c.id
                 LEFT JOIN club_members my ON my.club_id = c.id AND my.user_id = :user_id
                 WHERE c.name LIKE :q
                 GROUP BY c.id
                 ORDER BY c.created_at DESC
                 LIMIT :limit OFFSET :offset'
            );
            $stmt->bindValue(':user_id', $userId, PDO::PARAM_INT);
            $stmt->bindValue(':q', '%' . $q . '%');
        } else {
            $stmt = $this->pdo->prepare(
                'SELECT
                    c.id,
                    c.name,
                    c.description,
                    c.created_at,
                    COUNT(cm.id) AS member_count,
                    MAX(CASE WHEN my.user_id IS NULL THEN 0 ELSE 1 END) AS joined
                 FROM clubs c
                 LEFT JOIN club_members cm ON cm.club_id = c.id
                 LEFT JOIN club_members my ON my.club_id = c.id AND my.user_id = :user_id
                 GROUP BY c.id
                 ORDER BY c.created_at DESC
                 LIMIT :limit OFFSET :offset'
            );
            $stmt->bindValue(':user_id', $userId, PDO::PARAM_INT);
        }

        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
        $stmt->execute();
        $rows = $stmt->fetchAll();

        Http::data(200, ['clubs' => $rows], ['page' => $page, 'limit' => $limit]);
    }

    public function createClub(): never
    {
        $userId = $this->auth->requireUserId();
        $payload = Http::jsonBody();
        $name = trim((string) ($payload['name'] ?? ''));
        $description = trim((string) ($payload['description'] ?? ''));

        if ($name === '') {
            Http::error(422, 'VALIDATION_ERROR', 'name is required', ['field' => 'name']);
        }

        $stmt = $this->pdo->prepare(
            'INSERT INTO clubs (name, description, created_by) VALUES (:name, :description, :created_by)'
        );
        $stmt->execute([
            'name' => $name,
            'description' => $description !== '' ? $description : null,
            'created_by' => $userId,
        ]);
        $clubId = (int) $this->pdo->lastInsertId();

        $joinStmt = $this->pdo->prepare(
            'INSERT INTO club_members (club_id, user_id, role) VALUES (:club_id, :user_id, :role)'
        );
        $joinStmt->execute([
            'club_id' => $clubId,
            'user_id' => $userId,
            'role' => 'owner',
        ]);

        Http::data(201, [
            'club' => [
                'id' => $clubId,
                'name' => $name,
                'description' => $description,
            ],
        ]);
    }

    public function joinClub(int $clubId): never
    {
        $userId = $this->auth->requireUserId();
        $stmt = $this->pdo->prepare('INSERT IGNORE INTO club_members (club_id, user_id, role) VALUES (:club_id, :user_id, :role)');
        $stmt->execute([
            'club_id' => $clubId,
            'user_id' => $userId,
            'role' => 'member',
        ]);
        Http::data(200, ['membership' => ['club_id' => $clubId, 'user_id' => $userId, 'role' => 'member']]);
    }

    public function leaveClub(int $clubId): never
    {
        $userId = $this->auth->requireUserId();
        $stmt = $this->pdo->prepare(
            'DELETE FROM club_members WHERE club_id = :club_id AND user_id = :user_id'
        );
        $stmt->execute([
            'club_id' => $clubId,
            'user_id' => $userId,
        ]);
        Http::noContent();
    }

    public function clubDetail(int $clubId): never
    {
        $userId = $this->auth->requireUserId();
        $stmt = $this->pdo->prepare(
            'SELECT
                c.id,
                c.name,
                c.description,
                c.created_at,
                COUNT(cm.id) AS member_count,
                MAX(CASE WHEN my.user_id IS NULL THEN 0 ELSE 1 END) AS joined
             FROM clubs c
             LEFT JOIN club_members cm ON cm.club_id = c.id
             LEFT JOIN club_members my ON my.club_id = c.id AND my.user_id = :user_id
             WHERE c.id = :id
             GROUP BY c.id
             LIMIT 1'
        );
        $stmt->execute([
            'id' => $clubId,
            'user_id' => $userId,
        ]);
        $club = $stmt->fetch();
        if (!$club) {
            Http::error(404, 'NOT_FOUND', 'club not found');
        }

        Http::data(200, ['club' => $club]);
    }

    public function listChallenges(): never
    {
        $userId = $this->auth->requireUserId();

        $status = trim((string) ($_GET['status'] ?? ''));
        $clubId = isset($_GET['club_id']) ? (int) $_GET['club_id'] : null;

        $query = 'SELECT
                    c.id,
                    c.club_id,
                    c.title,
                    c.description,
                    c.type,
                    c.target_value,
                    c.start_at,
                    c.end_at,
                    c.status,
                    CASE WHEN cp.user_id IS NULL THEN 0 ELSE 1 END AS joined
                  FROM challenges c
                  LEFT JOIN challenge_participants cp
                    ON cp.challenge_id = c.id AND cp.user_id = :user_id
                  WHERE 1=1';
        $params = ['user_id' => $userId];

        if ($status !== '') {
            $query .= ' AND status = :status';
            $params['status'] = $status;
        }
        if ($clubId !== null && $clubId > 0) {
            $query .= ' AND club_id = :club_id';
            $params['club_id'] = $clubId;
        }
        $query .= ' ORDER BY start_at DESC LIMIT 200';

        $stmt = $this->pdo->prepare($query);
        $stmt->execute($params);
        Http::data(200, ['challenges' => $stmt->fetchAll()]);
    }

    public function joinChallenge(int $challengeId): never
    {
        $userId = $this->auth->requireUserId();
        $stmt = $this->pdo->prepare(
            'INSERT IGNORE INTO challenge_participants (challenge_id, user_id) VALUES (:challenge_id, :user_id)'
        );
        $stmt->execute([
            'challenge_id' => $challengeId,
            'user_id' => $userId,
        ]);
        Http::data(200, ['participant' => ['challenge_id' => $challengeId, 'user_id' => $userId]]);
    }

    public function challengeDetail(int $challengeId): never
    {
        $userId = $this->auth->requireUserId();
        $stmt = $this->pdo->prepare(
            'SELECT
                c.id,
                c.club_id,
                c.title,
                c.description,
                c.type,
                c.target_value,
                c.start_at,
                c.end_at,
                c.status,
                CASE WHEN cp.user_id IS NULL THEN 0 ELSE 1 END AS joined
             FROM challenges c
             LEFT JOIN challenge_participants cp
               ON cp.challenge_id = c.id AND cp.user_id = :user_id
             WHERE c.id = :id
             LIMIT 1'
        );
        $stmt->execute([
            'id' => $challengeId,
            'user_id' => $userId,
        ]);
        $challenge = $stmt->fetch();
        if (!$challenge) {
            Http::error(404, 'NOT_FOUND', 'challenge not found');
        }

        Http::data(200, ['challenge' => $challenge]);
    }

    public function leaderboard(): never
    {
        $userId = $this->auth->requireUserId();
        $period = trim((string) ($_GET['period'] ?? 'weekly'));
        $scope = trim((string) ($_GET['scope'] ?? 'global'));
        $scopeId = (int) ($_GET['scope_id'] ?? 0);
        $metric = trim((string) ($_GET['metric'] ?? 'distance'));

        if (($scope === 'club' || $scope === 'challenge') && $scopeId <= 0) {
            Http::error(422, 'VALIDATION_ERROR', 'scope_id is required for club/challenge scope', ['field' => 'scope_id']);
        }

        $windowSql = $period === 'monthly'
            ? 'w.started_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 30 DAY)'
            : 'w.started_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 7 DAY)';

        $join = '';
        $where = "WHERE w.status = 'completed' AND $windowSql";
        if ($scope === 'club' && $scopeId > 0) {
            $join = 'INNER JOIN club_members cmm ON cmm.user_id = w.user_id';
            $where .= ' AND cmm.club_id = :scope_id';
        } elseif ($scope === 'challenge' && $scopeId > 0) {
            $where .= ' AND w.challenge_id = :scope_id';
        }

        $metricExpr = match ($metric) {
            'pace' => 'AVG(NULLIF(w.avg_pace_sec_per_km, 0))',
            'consistency' => 'COUNT(DISTINCT DATE(w.started_at))',
            default => 'COALESCE(SUM(w.distance_m), 0)',
        };
        $orderBy = $metric === 'pace' ? 'metric_value ASC' : 'metric_value DESC';

        $selectDistance = 'COALESCE(SUM(w.distance_m), 0)';
        $selectPace = 'AVG(NULLIF(w.avg_pace_sec_per_km, 0))';
        $selectConsistency = 'COUNT(DISTINCT DATE(w.started_at))';

        if (!in_array($metric, ['distance', 'pace', 'consistency'], true)) {
            Http::error(422, 'VALIDATION_ERROR', 'unsupported metric', ['field' => 'metric']);
        }

        $sql = "SELECT
                    u.id AS user_id,
                    CONCAT(u.first_name, ' ', u.last_name) AS display_name,
                    $metricExpr AS metric_value,
                    $selectDistance AS total_distance_m,
                    $selectPace AS avg_pace_sec_per_km,
                    $selectConsistency AS active_days,
                    COUNT(w.id) AS workout_count
                FROM workouts w
                INNER JOIN users u ON u.id = w.user_id
                $join
                $where
                GROUP BY u.id
                ORDER BY $orderBy
                LIMIT 100";

        $stmt = $this->pdo->prepare($sql);
        if ($scope === 'club' && $scopeId > 0) {
            $stmt->bindValue(':scope_id', $scopeId, PDO::PARAM_INT);
        }
        $stmt->execute();
        $entries = $stmt->fetchAll();

        $myRank = null;
        foreach ($entries as $index => $entry) {
            if ((int) $entry['user_id'] === $userId) {
                $myRank = $index + 1;
                break;
            }
        }

        Http::data(200, [
            'entries' => $entries,
            'me' => [
                'user_id' => $userId,
                'rank' => $myRank,
            ],
            'period' => $period,
            'scope' => $scope,
            'scope_id' => $scopeId > 0 ? $scopeId : null,
            'metric' => $metric,
        ]);
    }

    public function workoutStart(): never
    {
        $userId = $this->auth->requireUserId();
        $payload = Http::jsonBody();

        $startedAt = trim((string) ($payload['started_at'] ?? ''));
        $activityType = trim((string) ($payload['activity_type'] ?? 'run'));
        $source = trim((string) ($payload['source'] ?? 'mobile'));
        $challengeId = isset($payload['challenge_id']) ? (int) $payload['challenge_id'] : null;

        if ($startedAt === '') {
            Http::error(422, 'VALIDATION_ERROR', 'started_at is required', ['field' => 'started_at']);
        }

        $stmt = $this->pdo->prepare(
            'INSERT INTO workouts (user_id, challenge_id, activity_type, status, started_at, source)
             VALUES (:user_id, :challenge_id, :activity_type, :status, :started_at, :source)'
        );
        $stmt->execute([
            'user_id' => $userId,
            'challenge_id' => $challengeId,
            'activity_type' => $activityType,
            'status' => 'running',
            'started_at' => gmdate('Y-m-d H:i:s', strtotime($startedAt)),
            'source' => $source,
        ]);
        $workoutId = (int) $this->pdo->lastInsertId();

        $event = $this->pdo->prepare(
            'INSERT INTO workout_events (workout_id, event_type, event_at) VALUES (:workout_id, :event_type, :event_at)'
        );
        $event->execute([
            'workout_id' => $workoutId,
            'event_type' => 'start',
            'event_at' => gmdate('Y-m-d H:i:s', strtotime($startedAt)),
        ]);

        Http::data(201, [
            'workout' => [
                'id' => $workoutId,
                'status' => 'running',
                'started_at' => $startedAt,
            ],
        ]);
    }

    public function workoutPause(int $workoutId): never
    {
        $this->changeWorkoutState($workoutId, 'paused', 'pause', 'paused_at');
    }

    public function workoutResume(int $workoutId): never
    {
        $this->changeWorkoutState($workoutId, 'running', 'resume', 'resumed_at');
    }

    public function workoutComplete(int $workoutId): never
    {
        $userId = $this->auth->requireUserId();
        $payload = Http::jsonBody();
        $endedAt = trim((string) ($payload['ended_at'] ?? ''));
        if ($endedAt === '') {
            Http::error(422, 'VALIDATION_ERROR', 'ended_at is required', ['field' => 'ended_at']);
        }

        $durationSec = isset($payload['duration_sec']) ? (int) $payload['duration_sec'] : null;
        $distanceM = isset($payload['distance_m']) ? (float) $payload['distance_m'] : null;
        $avgPace = isset($payload['avg_pace_sec_per_km']) ? (float) $payload['avg_pace_sec_per_km'] : null;
        $calories = isset($payload['calories_kcal']) ? (float) $payload['calories_kcal'] : null;
        $category = isset($payload['category']) ? trim((string) $payload['category']) : null;

        $w = $this->pdo->prepare('SELECT id FROM workouts WHERE id = :id AND user_id = :user_id LIMIT 1');
        $w->execute(['id' => $workoutId, 'user_id' => $userId]);
        if (!$w->fetch()) {
            Http::error(404, 'NOT_FOUND', 'workout not found');
        }

        $stmt = $this->pdo->prepare(
            'UPDATE workouts
             SET status = :status,
                 ended_at = :ended_at,
                 duration_sec = :duration_sec,
                 distance_m = :distance_m,
                 avg_pace_sec_per_km = :avg_pace,
                 calories_kcal = :calories,
                 category = :category
             WHERE id = :id'
        );
        $stmt->execute([
            'status' => 'completed',
            'ended_at' => gmdate('Y-m-d H:i:s', strtotime($endedAt)),
            'duration_sec' => $durationSec,
            'distance_m' => $distanceM,
            'avg_pace' => $avgPace,
            'calories' => $calories,
            'category' => $category,
            'id' => $workoutId,
        ]);

        $event = $this->pdo->prepare(
            'INSERT INTO workout_events (workout_id, event_type, event_at) VALUES (:workout_id, :event_type, :event_at)'
        );
        $event->execute([
            'workout_id' => $workoutId,
            'event_type' => 'complete',
            'event_at' => gmdate('Y-m-d H:i:s', strtotime($endedAt)),
        ]);

        Http::data(200, [
            'workout' => [
                'id' => $workoutId,
                'status' => 'completed',
                'ended_at' => $endedAt,
            ],
        ]);
    }

    public function workoutSamples(int $workoutId): never
    {
        $userId = $this->auth->requireUserId();
        $payload = Http::jsonBody();
        $samples = $payload['samples'] ?? null;
        if (!is_array($samples) || $samples === []) {
            Http::error(422, 'VALIDATION_ERROR', 'samples array is required', ['field' => 'samples']);
        }

        $w = $this->pdo->prepare('SELECT id FROM workouts WHERE id = :id AND user_id = :user_id LIMIT 1');
        $w->execute(['id' => $workoutId, 'user_id' => $userId]);
        if (!$w->fetch()) {
            Http::error(404, 'NOT_FOUND', 'workout not found');
        }

        $stmt = $this->pdo->prepare(
            'INSERT INTO workout_samples
             (workout_id, captured_at, latitude, longitude, altitude_m, distance_m, pace_sec_per_km, heart_rate_bpm, steps, calories_kcal, source)
             VALUES
             (:workout_id, :captured_at, :latitude, :longitude, :altitude_m, :distance_m, :pace_sec_per_km, :heart_rate_bpm, :steps, :calories_kcal, :source)'
        );

        $accepted = 0;
        foreach ($samples as $sample) {
            if (!is_array($sample) || !isset($sample['captured_at'])) {
                continue;
            }
            $stmt->execute([
                'workout_id' => $workoutId,
                'captured_at' => gmdate('Y-m-d H:i:s', strtotime((string) $sample['captured_at'])),
                'latitude' => $sample['latitude'] ?? null,
                'longitude' => $sample['longitude'] ?? null,
                'altitude_m' => $sample['altitude_m'] ?? null,
                'distance_m' => $sample['distance_m'] ?? null,
                'pace_sec_per_km' => $sample['pace_sec_per_km'] ?? null,
                'heart_rate_bpm' => $sample['heart_rate_bpm'] ?? null,
                'steps' => $sample['steps'] ?? null,
                'calories_kcal' => $sample['calories_kcal'] ?? null,
                'source' => $sample['source'] ?? 'gps',
            ]);
            $accepted++;
        }

        Http::data(200, ['accepted' => $accepted]);
    }

    public function workoutHistory(): never
    {
        $userId = $this->auth->requireUserId();
        $page = max(1, (int) ($_GET['page'] ?? 1));
        $limit = min(100, max(1, (int) ($_GET['limit'] ?? 20)));
        $offset = ($page - 1) * $limit;
        $from = trim((string) ($_GET['from'] ?? ''));
        $to = trim((string) ($_GET['to'] ?? ''));

        $where = 'WHERE user_id = :user_id';
        $params = ['user_id' => $userId];
        if ($from !== '') {
            $where .= ' AND started_at >= :from_at';
            $params['from_at'] = gmdate('Y-m-d H:i:s', strtotime($from));
        }
        if ($to !== '') {
            $where .= ' AND started_at <= :to_at';
            $params['to_at'] = gmdate('Y-m-d H:i:s', strtotime($to));
        }

        $stmt = $this->pdo->prepare(
            'SELECT id, activity_type, status, started_at, ended_at, duration_sec, distance_m, avg_pace_sec_per_km, calories_kcal, category
             FROM workouts
             ' . $where . '
             ORDER BY started_at DESC
             LIMIT :limit OFFSET :offset'
        );
        foreach ($params as $key => $value) {
            if ($key === 'user_id') {
                $stmt->bindValue(':' . $key, $value, PDO::PARAM_INT);
            } else {
                $stmt->bindValue(':' . $key, $value, PDO::PARAM_STR);
            }
        }
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
        $stmt->execute();

        Http::data(200, ['workouts' => $stmt->fetchAll()], ['page' => $page, 'limit' => $limit, 'from' => $from, 'to' => $to]);
    }

    public function workoutDetail(int $workoutId): never
    {
        $userId = $this->auth->requireUserId();
        $w = $this->pdo->prepare(
            'SELECT id, activity_type, status, started_at, ended_at, duration_sec, distance_m, avg_pace_sec_per_km, calories_kcal, category
             FROM workouts
             WHERE id = :id AND user_id = :user_id
             LIMIT 1'
        );
        $w->execute(['id' => $workoutId, 'user_id' => $userId]);
        $workout = $w->fetch();
        if (!$workout) {
            Http::error(404, 'NOT_FOUND', 'workout not found');
        }

        $samples = $this->pdo->prepare(
            'SELECT captured_at, latitude, longitude, distance_m, pace_sec_per_km, heart_rate_bpm
             FROM workout_samples
             WHERE workout_id = :workout_id
             ORDER BY captured_at ASC
             LIMIT 2000'
        );
        $samples->execute(['workout_id' => $workoutId]);

        Http::data(200, [
            'workout' => $workout,
            'samples' => $samples->fetchAll(),
        ]);
    }

    private function changeWorkoutState(
        int $workoutId,
        string $status,
        string $eventType,
        string $timestampField
    ): never {
        $userId = $this->auth->requireUserId();
        $payload = Http::jsonBody();
        $eventAt = trim((string) ($payload[$timestampField] ?? ''));
        if ($eventAt === '') {
            Http::error(422, 'VALIDATION_ERROR', $timestampField . ' is required', ['field' => $timestampField]);
        }

        $w = $this->pdo->prepare('SELECT id FROM workouts WHERE id = :id AND user_id = :user_id LIMIT 1');
        $w->execute(['id' => $workoutId, 'user_id' => $userId]);
        if (!$w->fetch()) {
            Http::error(404, 'NOT_FOUND', 'workout not found');
        }

        $stmt = $this->pdo->prepare('UPDATE workouts SET status = :status WHERE id = :id');
        $stmt->execute(['status' => $status, 'id' => $workoutId]);

        $event = $this->pdo->prepare(
            'INSERT INTO workout_events (workout_id, event_type, event_at) VALUES (:workout_id, :event_type, :event_at)'
        );
        $event->execute([
            'workout_id' => $workoutId,
            'event_type' => $eventType,
            'event_at' => gmdate('Y-m-d H:i:s', strtotime($eventAt)),
        ]);

        Http::data(200, ['workout' => ['id' => $workoutId, 'status' => $status]]);
    }
}
