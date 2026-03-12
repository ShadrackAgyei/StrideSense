part of '../main.dart';

class SessionController extends ChangeNotifier {
  SessionController({BackendApiClient? apiClient, SyncApiClient? syncClient})
    : _apiClient = apiClient ?? BackendApiClient(),
      _syncWorker = SyncWorker(
        client:
            syncClient ?? BackendSyncApiClient(apiClient ?? BackendApiClient()),
      ) {
    unawaited(_bootstrap());
  }

  bool isAuthenticated = false;
  bool isBootstrapping = true;
  PendingDestination? _pending;
  final BackendApiClient _apiClient;
  final SyncWorker _syncWorker;
  AuthTokens? _tokens;
  ProfileData profile = ProfileData.defaults;
  DashboardSummary dashboard = DashboardSummary.defaults;
  String? lastError;

  void setPendingDestination(String route, {Object? arguments}) {
    _pending = PendingDestination(route, arguments: arguments);
  }

  PendingDestination? consumePendingDestination() {
    final pending = _pending;
    _pending = null;
    return pending;
  }

  Future<bool> login(String email, String password) async {
    try {
      lastError = null;
      final auth = await _apiClient
          .login(email: email, password: password)
          .timeout(const Duration(seconds: 2));
      await _setAuthenticated(auth);
      return true;
    } on TimeoutException {
      if (!bool.fromEnvironment('dart.vm.product')) {
        await _setLocalFallbackAuth();
        return true;
      }
      lastError = 'Login timed out';
      notifyListeners();
      return false;
    } on DioException catch (e) {
      if (_canUseOfflineFallback(e)) {
        await _setLocalFallbackAuth();
        return true;
      }
      lastError = _readError(e);
      notifyListeners();
      return false;
    } catch (e) {
      lastError = _readError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    try {
      lastError = null;
      final auth = await _apiClient
          .register(
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName,
            phone: phone,
          )
          .timeout(const Duration(seconds: 2));
      await _setAuthenticated(auth);
      return true;
    } on TimeoutException {
      if (!bool.fromEnvironment('dart.vm.product')) {
        await _setLocalFallbackAuth();
        return true;
      }
      lastError = 'Signup timed out';
      notifyListeners();
      return false;
    } on DioException catch (e) {
      if (_canUseOfflineFallback(e)) {
        await _setLocalFallbackAuth();
        return true;
      }
      lastError = _readError(e);
      notifyListeners();
      return false;
    } catch (e) {
      lastError = _readError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    final refreshToken = _tokens?.refreshToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _apiClient.logout(refreshToken: refreshToken);
      } catch (_) {}
    }
    await AuthTokenStore.clear();
    _syncWorker.stop();
    _tokens = null;
    isAuthenticated = false;
    profile = ProfileData.defaults;
    dashboard = DashboardSummary.defaults;
    lastError = null;
    notifyListeners();
  }

  Future<void> refreshMeAndDashboard() async {
    if (!isAuthenticated) return;
    try {
      await _refreshProfileAndDashboard();
    } catch (e) {
      lastError = _readError(e);
      notifyListeners();
    }
  }

  Future<bool> syncProfileNow() async {
    _syncWorker.kick();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final current = await LocalProfileStore.load();
    if (!current.dirty) {
      profile = current;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> enableLocalAuthFallback() async {
    await _setLocalFallbackAuth();
  }

  Future<String?> uploadProfilePhoto(XFile file) async {
    try {
      final avatarUrl = await _withAuthRetry(
        (token) => _apiClient.uploadAvatar(accessToken: token, file: file),
      );
      if (avatarUrl.isEmpty) return null;
      profile = profile.copyWith(avatarUrl: avatarUrl, dirty: false);
      await LocalProfileStore.save(
        profile,
        markDirty: false,
        enqueueSync: false,
      );
      notifyListeners();
      return avatarUrl;
    } catch (e) {
      lastError = _readError(e);
      notifyListeners();
      return null;
    }
  }

  Future<int?> startWorkoutSession({
    required DateTime startedAt,
    required String activityType,
  }) async {
    try {
      return await _withAuthRetry(
        (token) => _apiClient.startWorkout(
          accessToken: token,
          startedAt: startedAt,
          activityType: activityType,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> pauseWorkoutSession(int workoutId, DateTime pausedAt) async {
    await _withAuthRetry(
      (token) => _apiClient.pauseWorkout(
        accessToken: token,
        workoutId: workoutId,
        pausedAt: pausedAt,
      ),
    );
  }

  Future<void> resumeWorkoutSession(int workoutId, DateTime resumedAt) async {
    await _withAuthRetry(
      (token) => _apiClient.resumeWorkout(
        accessToken: token,
        workoutId: workoutId,
        resumedAt: resumedAt,
      ),
    );
  }

  Future<void> uploadWorkoutSamples(
    int workoutId,
    List<RoutePoint> routePoints,
    int elapsedSeconds,
    double distanceKm,
  ) async {
    if (routePoints.isEmpty) return;
    final now = DateTime.now().toUtc();
    final eachDistance = routePoints.isEmpty
        ? 0.0
        : (distanceKm * 1000) / routePoints.length;
    final samples = <Map<String, dynamic>>[];
    for (var i = 0; i < routePoints.length; i++) {
      final p = routePoints[i];
      samples.add({
        'captured_at': now
            .subtract(
              Duration(seconds: elapsedSeconds - i.clamp(0, elapsedSeconds)),
            )
            .toIso8601String(),
        'latitude': p.lat,
        'longitude': p.lng,
        'distance_m': (eachDistance * (i + 1)).toStringAsFixed(2),
        'source': 'gps',
      });
    }
    await _withAuthRetry(
      (token) => _apiClient.uploadWorkoutSamples(
        accessToken: token,
        workoutId: workoutId,
        samples: samples,
      ),
    );
  }

  Future<void> completeWorkoutSession({
    required int workoutId,
    required DateTime endedAt,
    required int durationSec,
    required double distanceKm,
    required double paceMinutesPerKm,
    String? category,
  }) async {
    await _withAuthRetry(
      (token) => _apiClient.completeWorkout(
        accessToken: token,
        workoutId: workoutId,
        endedAt: endedAt,
        durationSec: durationSec,
        distanceM: distanceKm * 1000,
        avgPaceSecPerKm: paceMinutesPerKm * 60,
        category: category,
      ),
    );
    await refreshMeAndDashboard();
  }

  Future<void> recordWorkoutLocally({
    required DateTime endedAt,
    required int durationSec,
    required double distanceKm,
    required double paceMinutesPerKm,
    String? category,
  }) async {
    final safeDuration = durationSec < 0 ? 0 : durationSec;
    final startedAt = endedAt.subtract(Duration(seconds: safeDuration));
    final item = WorkoutHistoryItem(
      id: -DateTime.now().millisecondsSinceEpoch,
      status: 'completed',
      startedAt: startedAt,
      distanceM: distanceKm * 1000,
      avgPaceSecPerKm: paceMinutesPerKm > 0 ? paceMinutesPerKm * 60 : 0,
      category: (category ?? '').trim(),
    );
    final merged = [item, ...dashboard.recentWorkouts];
    final totalDistanceM =
        (dashboard.totalDistanceKm * 1000) + (distanceKm * 1000);
    final workoutsCount = dashboard.workoutsCount + 1;
    dashboard = DashboardSummary.fromData(
      totalDistanceM: totalDistanceM,
      workoutsCount: workoutsCount,
      workouts: merged,
    );
    await LocalDashboardStore.save(dashboard);
    notifyListeners();
  }

  Future<List<LeaderboardEntry>> loadLeaderboard({
    required LeaderboardFilter filter,
  }) async {
    if (_tokens == null) return const [];
    try {
      return await _withAuthRetry(
        (token) => _apiClient.getLeaderboard(
          accessToken: token,
          period: filter == LeaderboardFilter.weekly ? 'weekly' : 'monthly',
        ),
      );
    } catch (e) {
      lastError = _readError(e);
      notifyListeners();
      return const [];
    }
  }

  Future<List<ChallengeSummary>> loadChallenges() async {
    if (_tokens == null) return const [];
    try {
      return await _withAuthRetry(
        (token) => _apiClient.getChallenges(accessToken: token),
      );
    } catch (e) {
      lastError = _readError(e);
      notifyListeners();
      return const [];
    }
  }

  Future<ChallengeDetails?> loadChallengeDetail(int challengeId) async {
    if (_tokens == null) return null;
    try {
      return await _withAuthRetry(
        (token) => _apiClient.getChallengeDetail(
          accessToken: token,
          challengeId: challengeId,
        ),
      );
    } catch (e) {
      lastError = _readError(e);
      notifyListeners();
      return null;
    }
  }

  Future<List<ClubSummary>> loadClubs() async {
    if (_tokens == null) return const [];
    try {
      return await _withAuthRetry(
        (token) => _apiClient.getClubs(accessToken: token),
      );
    } catch (e) {
      lastError = _readError(e);
      notifyListeners();
      return const [];
    }
  }

  Future<ClubDetails?> loadClubDetail(int clubId) async {
    if (_tokens == null) return null;
    try {
      return await _withAuthRetry(
        (token) => _apiClient.getClubDetail(accessToken: token, clubId: clubId),
      );
    } catch (e) {
      lastError = _readError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> joinChallenge(int challengeId) async {
    if (_tokens == null) return false;
    try {
      await _withAuthRetry(
        (token) => _apiClient.joinChallenge(
          accessToken: token,
          challengeId: challengeId,
        ),
      );
      return true;
    } catch (e) {
      lastError = _readError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> joinClub(int clubId) async {
    if (_tokens == null) return false;
    try {
      await _withAuthRetry(
        (token) => _apiClient.joinClub(accessToken: token, clubId: clubId),
      );
      return true;
    } catch (e) {
      lastError = _readError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> createClub(String name, String description) async {
    if (_tokens == null) return false;
    try {
      await _withAuthRetry(
        (token) => _apiClient.createClub(
          accessToken: token,
          name: name,
          description: description,
        ),
      );
      return true;
    } catch (e) {
      lastError = _readError(e);
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _syncWorker.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final cachedProfile = await LocalProfileStore.load();
    profile = cachedProfile;
    final cachedDashboard = await LocalDashboardStore.load();
    dashboard = cachedDashboard;
    notifyListeners();

    final tokens = await AuthTokenStore.read();
    if (tokens == null) {
      if (isAuthenticated) {
        isBootstrapping = false;
        notifyListeners();
        return;
      }
      isAuthenticated = false;
      isBootstrapping = false;
      notifyListeners();
      return;
    }

    _tokens = tokens;
    isAuthenticated = true;
    _syncWorker.start();
    notifyListeners();

    try {
      await _refreshProfileAndDashboard();
    } catch (e) {
      lastError = _readError(e);
    } finally {
      isBootstrapping = false;
      notifyListeners();
    }
  }

  Future<void> _setAuthenticated(AuthSession auth) async {
    _tokens = auth.tokens;
    isAuthenticated = true;
    await AuthTokenStore.write(auth.tokens);
    profile = auth.profile;
    await LocalProfileStore.save(profile, markDirty: false, enqueueSync: false);
    if (auth.tokens.accessToken.isNotEmpty) {
      _syncWorker.start();
    }
    notifyListeners();
    await _refreshProfileAndDashboard();
  }

  Future<void> _setLocalFallbackAuth() async {
    isAuthenticated = true;
    _tokens = null;
    profile = await LocalProfileStore.load();
    dashboard = await LocalDashboardStore.load();
    notifyListeners();
  }

  Future<void> _refreshProfileAndDashboard() async {
    final me = await _withAuthRetry(
      (token) => _apiClient.getMe(accessToken: token),
    );
    profile = me.profile;
    await LocalProfileStore.save(profile, markDirty: false, enqueueSync: false);
    final history = await _withAuthRetry(
      (token) => _apiClient.getWorkoutHistory(accessToken: token, limit: 50),
    );
    dashboard = DashboardSummary.fromData(
      totalDistanceM: me.totalDistanceM,
      workoutsCount: me.workoutsCount,
      workouts: history,
    );
    await LocalDashboardStore.save(dashboard);
    notifyListeners();
  }

  Future<T> _withAuthRetry<T>(
    Future<T> Function(String accessToken) action,
  ) async {
    final tokens = _tokens;
    if (tokens == null) throw StateError('Not authenticated');
    try {
      return await action(tokens.accessToken);
    } on DioException catch (e) {
      if (e.response?.statusCode != 401) rethrow;
      final refreshed = await _apiClient.refresh(
        refreshToken: tokens.refreshToken,
      );
      _tokens = refreshed;
      await AuthTokenStore.write(refreshed);
      return action(refreshed.accessToken);
    }
  }

  String _readError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] is Map) {
        return ((data['error'] as Map)['message'] as String?) ??
            'Request failed';
      }
      return error.message ?? 'Request failed';
    }
    return error.toString();
  }

  bool _canUseOfflineFallback(DioException e) {
    if (bool.fromEnvironment('dart.vm.product')) {
      return false;
    }
    final status = e.response?.statusCode;
    final noServerResponse =
        status == null ||
        status == 400 ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout;
    return noServerResponse;
  }
}

class SessionScope extends InheritedNotifier<SessionController> {
  const SessionScope({
    super.key,
    required SessionController controller,
    required super.child,
  }) : super(notifier: controller);

  static SessionController of(BuildContext context) {
    final SessionScope? scope = context
        .dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope was not found in the widget tree.');
    return scope!.notifier!;
  }
}

class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
  };

  static AuthTokens fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: (json['access_token'] as String?) ?? '',
      refreshToken: (json['refresh_token'] as String?) ?? '',
    );
  }
}

class AuthSession {
  const AuthSession({required this.tokens, required this.profile});

  final AuthTokens tokens;
  final ProfileData profile;
}

class MeResponse {
  const MeResponse({
    required this.profile,
    required this.totalDistanceM,
    required this.workoutsCount,
  });

  final ProfileData profile;
  final double totalDistanceM;
  final int workoutsCount;
}

class WorkoutHistoryItem {
  const WorkoutHistoryItem({
    required this.id,
    required this.status,
    required this.startedAt,
    required this.distanceM,
    required this.avgPaceSecPerKm,
    required this.category,
  });

  final int id;
  final String status;
  final DateTime? startedAt;
  final double distanceM;
  final double avgPaceSecPerKm;
  final String category;

  static WorkoutHistoryItem fromJson(Map<String, dynamic> json) {
    DateTime? startedAt;
    final raw = json['started_at'] as String?;
    if (raw != null && raw.isNotEmpty) {
      startedAt = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    }
    return WorkoutHistoryItem(
      id: _asInt(json['id']),
      status: (json['status'] as String?) ?? '',
      startedAt: startedAt,
      distanceM: _asDouble(json['distance_m']),
      avgPaceSecPerKm: _asDouble(json['avg_pace_sec_per_km']),
      category: (json['category'] as String?) ?? '',
    );
  }
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.totalDistanceM,
    required this.avgPaceSecPerKm,
    required this.activeDays,
  });

  final int userId;
  final String displayName;
  final double totalDistanceM;
  final double avgPaceSecPerKm;
  final int activeDays;

  static LeaderboardEntry fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: _asInt(json['user_id']),
      displayName: (json['display_name'] as String?) ?? 'Runner',
      totalDistanceM: _asDouble(json['total_distance_m']),
      avgPaceSecPerKm: _asDouble(json['avg_pace_sec_per_km']),
      activeDays: _asInt(json['active_days']),
    );
  }
}

class ChallengeSummary {
  const ChallengeSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.joined,
  });

  final int id;
  final String title;
  final String description;
  final String status;
  final bool joined;

  static ChallengeSummary fromJson(Map<String, dynamic> json) {
    return ChallengeSummary(
      id: _asInt(json['id']),
      title: (json['title'] as String?) ?? 'Challenge',
      description: (json['description'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      joined: _asBoolFlag(json['joined']),
    );
  }
}

class ChallengeDetails {
  const ChallengeDetails({
    required this.id,
    required this.clubId,
    required this.title,
    required this.description,
    required this.type,
    required this.targetValue,
    required this.startAt,
    required this.endAt,
    required this.status,
    required this.joined,
  });

  final int id;
  final int? clubId;
  final String title;
  final String description;
  final String type;
  final double targetValue;
  final DateTime? startAt;
  final DateTime? endAt;
  final String status;
  final bool joined;

  static ChallengeDetails fromJson(Map<String, dynamic> json) {
    return ChallengeDetails(
      id: _asInt(json['id']),
      clubId: _asNullableInt(json['club_id']),
      title: (json['title'] as String?) ?? 'Challenge',
      description: (json['description'] as String?) ?? '',
      type: (json['type'] as String?) ?? '',
      targetValue: _asDouble(json['target_value']),
      startAt: _parseServerDate(json['start_at']),
      endAt: _parseServerDate(json['end_at']),
      status: (json['status'] as String?) ?? '',
      joined: _asBoolFlag(json['joined']),
    );
  }
}

class ClubSummary {
  const ClubSummary({
    required this.id,
    required this.name,
    required this.description,
    required this.memberCount,
    required this.joined,
  });

  final int id;
  final String name;
  final String description;
  final int memberCount;
  final bool joined;

  static ClubSummary fromJson(Map<String, dynamic> json) {
    return ClubSummary(
      id: _asInt(json['id']),
      name: (json['name'] as String?) ?? 'Club',
      description: (json['description'] as String?) ?? '',
      memberCount: _asInt(json['member_count']),
      joined: _asBoolFlag(json['joined']),
    );
  }
}

class ClubDetails {
  const ClubDetails({
    required this.id,
    required this.name,
    required this.description,
    required this.memberCount,
    required this.joined,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String description;
  final int memberCount;
  final bool joined;
  final DateTime? createdAt;

  static ClubDetails fromJson(Map<String, dynamic> json) {
    return ClubDetails(
      id: _asInt(json['id']),
      name: (json['name'] as String?) ?? 'Club',
      description: (json['description'] as String?) ?? '',
      memberCount: _asInt(json['member_count']),
      joined: _asBoolFlag(json['joined']),
      createdAt: _parseServerDate(json['created_at']),
    );
  }
}

class DashboardSummary {
  const DashboardSummary({
    required this.totalDistanceKm,
    required this.weeklyDistanceKm,
    required this.weeklyAvgPaceSecPerKm,
    required this.workoutsCount,
    required this.recentWorkouts,
  });

  final double totalDistanceKm;
  final double weeklyDistanceKm;
  final double weeklyAvgPaceSecPerKm;
  final int workoutsCount;
  final List<WorkoutHistoryItem> recentWorkouts;

  static const defaults = DashboardSummary(
    totalDistanceKm: 0,
    weeklyDistanceKm: 0,
    weeklyAvgPaceSecPerKm: 0,
    workoutsCount: 0,
    recentWorkouts: [],
  );

  Map<String, dynamic> toJson() => {
    'totalDistanceKm': totalDistanceKm,
    'weeklyDistanceKm': weeklyDistanceKm,
    'weeklyAvgPaceSecPerKm': weeklyAvgPaceSecPerKm,
    'workoutsCount': workoutsCount,
    'recentWorkouts': recentWorkouts
        .map(
          (w) => {
            'id': w.id,
            'status': w.status,
            'startedAt': w.startedAt?.toIso8601String(),
            'distanceM': w.distanceM,
            'avgPaceSecPerKm': w.avgPaceSecPerKm,
            'category': w.category,
          },
        )
        .toList(),
  };

  static DashboardSummary fromJson(Map<String, dynamic> json) {
    final rawWorkouts = json['recentWorkouts'];
    final workouts = <WorkoutHistoryItem>[];
    if (rawWorkouts is List) {
      for (final item in rawWorkouts) {
        if (item is Map) {
          workouts.add(
            WorkoutHistoryItem(
              id: _asInt(item['id']),
              status: (item['status'] as String?) ?? '',
              startedAt: DateTime.tryParse(
                (item['startedAt'] as String?) ?? '',
              ),
              distanceM: _asDouble(item['distanceM']),
              avgPaceSecPerKm: _asDouble(item['avgPaceSecPerKm']),
              category: (item['category'] as String?) ?? '',
            ),
          );
        }
      }
    }

    return DashboardSummary(
      totalDistanceKm: _asDouble(json['totalDistanceKm']),
      weeklyDistanceKm: _asDouble(json['weeklyDistanceKm']),
      weeklyAvgPaceSecPerKm: _asDouble(json['weeklyAvgPaceSecPerKm']),
      workoutsCount: _asInt(json['workoutsCount']),
      recentWorkouts: workouts,
    );
  }

  static DashboardSummary fromData({
    required double totalDistanceM,
    required int workoutsCount,
    required List<WorkoutHistoryItem> workouts,
  }) {
    final now = DateTime.now().toUtc();
    final weekAgo = now.subtract(const Duration(days: 7));
    final weekly = workouts.where((w) {
      final t = w.startedAt?.toUtc();
      return t != null &&
          t.isAfter(weekAgo) &&
          w.status.toLowerCase() == 'completed';
    }).toList();
    final weeklyDistanceM = weekly.fold<double>(
      0,
      (sum, w) => sum + w.distanceM,
    );
    final paceValues = weekly
        .map((w) => w.avgPaceSecPerKm)
        .where((p) => p > 0)
        .toList();
    final avgPace = paceValues.isEmpty
        ? 0.0
        : paceValues.reduce((a, b) => a + b) / paceValues.length;
    return DashboardSummary(
      totalDistanceKm: totalDistanceM / 1000,
      weeklyDistanceKm: weeklyDistanceM / 1000,
      weeklyAvgPaceSecPerKm: avgPace,
      workoutsCount: workoutsCount,
      recentWorkouts: workouts.take(10).toList(),
    );
  }
}

class AuthTokenStore {
  static const _secure = FlutterSecureStorage();
  static const _spKey = 'auth_tokens_v1';

  static Future<AuthTokens?> read() async {
    try {
      final raw = await _secure.read(key: _spKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return AuthTokens.fromJson(decoded);
        }
      }
    } on MissingPluginException {
      // test fallback
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_spKey);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    return AuthTokens.fromJson(decoded);
  }

  static Future<void> write(AuthTokens tokens) async {
    final raw = jsonEncode(tokens.toJson());
    try {
      await _secure.write(key: _spKey, value: raw);
      return;
    } on MissingPluginException {
      // test fallback
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_spKey, raw);
  }

  static Future<void> clear() async {
    try {
      await _secure.delete(key: _spKey);
    } on MissingPluginException {
      // test fallback
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_spKey);
  }
}

class LocalDashboardStore {
  static const _keyDashboard = 'dashboard_summary_v1';

  static Future<DashboardSummary> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyDashboard);
    if (raw == null || raw.isEmpty) return DashboardSummary.defaults;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return DashboardSummary.defaults;
      return DashboardSummary.fromJson(decoded);
    } catch (_) {
      return DashboardSummary.defaults;
    }
  }

  static Future<void> save(DashboardSummary data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDashboard, jsonEncode(data.toJson()));
  }
}

class BackendApiClient {
  BackendApiClient({String? baseUrl})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl ?? _resolveBaseUrl(),
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
        ),
      );

  final Dio _dio;
  final Uuid _uuid = const Uuid();

  static String _resolveBaseUrl() {
    const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    return 'http://169.239.251.102:280/~shadrack.nti/api/v1';
  }

  Future<AuthSession> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    final res = await _dio.post(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
      },
    );
    return _authSessionFromResponse(res);
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return _authSessionFromResponse(res);
  }

  Future<AuthTokens> refresh({required String refreshToken}) async {
    final res = await _dio.post(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
    );
    final data = _extractData(res);
    final rawTokens =
        (data['tokens'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AuthTokens.fromJson(rawTokens);
  }

  Future<void> logout({required String refreshToken}) async {
    await _dio.post('/auth/logout', data: {'refresh_token': refreshToken});
  }

  Future<MeResponse> getMe({required String accessToken}) async {
    final res = await _dio.get(
      '/me',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = _extractData(res);
    final user = (data['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    final stats = (data['stats'] as Map?)?.cast<String, dynamic>() ?? const {};
    final profile = _profileFromServer(user);
    return MeResponse(
      profile: profile,
      totalDistanceM: _asDouble(stats['total_distance_m']),
      workoutsCount: _asInt(stats['workouts_count']),
    );
  }

  Future<ProfileData> patchProfile({
    required String accessToken,
    required ProfileData profile,
  }) async {
    final res = await _dio.patch(
      '/me/profile',
      data: {
        'first_name': profile.firstName,
        'last_name': profile.lastName,
        'phone': profile.phone,
        'bio': profile.bio,
        'city': profile.location,
        if (profile.avatarUrl.isNotEmpty) 'avatar_url': profile.avatarUrl,
      },
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = _extractData(res);
    final user = (data['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    return _profileFromServer(user);
  }

  Future<String> uploadAvatar({
    required String accessToken,
    required XFile file,
  }) async {
    final form = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(file.path, filename: file.name),
    });
    final res = await _dio.post(
      '/me/avatar',
      data: form,
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = _extractData(res);
    return (data['avatar_url'] as String?) ?? '';
  }

  Future<int> startWorkout({
    required String accessToken,
    required DateTime startedAt,
    required String activityType,
  }) async {
    final res = await _dio.post(
      '/workouts/start',
      data: {
        'started_at': startedAt.toUtc().toIso8601String(),
        'activity_type': activityType,
        'source': 'mobile',
      },
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = _extractData(res);
    final workout =
        (data['workout'] as Map?)?.cast<String, dynamic>() ?? const {};
    return _asInt(workout['id']);
  }

  Future<void> pauseWorkout({
    required String accessToken,
    required int workoutId,
    required DateTime pausedAt,
  }) async {
    await _dio.post(
      '/workouts/$workoutId/pause',
      data: {'paused_at': pausedAt.toUtc().toIso8601String()},
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  }

  Future<void> resumeWorkout({
    required String accessToken,
    required int workoutId,
    required DateTime resumedAt,
  }) async {
    await _dio.post(
      '/workouts/$workoutId/resume',
      data: {'resumed_at': resumedAt.toUtc().toIso8601String()},
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  }

  Future<void> uploadWorkoutSamples({
    required String accessToken,
    required int workoutId,
    required List<Map<String, dynamic>> samples,
  }) async {
    await _dio.post(
      '/workouts/$workoutId/samples',
      data: {'samples': samples},
      options: Options(
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Idempotency-Key': _uuid.v4(),
        },
      ),
    );
  }

  Future<void> completeWorkout({
    required String accessToken,
    required int workoutId,
    required DateTime endedAt,
    required int durationSec,
    required double distanceM,
    required double avgPaceSecPerKm,
    String? category,
  }) async {
    await _dio.post(
      '/workouts/$workoutId/complete',
      data: {
        'ended_at': endedAt.toUtc().toIso8601String(),
        'duration_sec': durationSec,
        'distance_m': distanceM,
        'avg_pace_sec_per_km': avgPaceSecPerKm,
        'category': category,
      },
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  }

  Future<List<WorkoutHistoryItem>> getWorkoutHistory({
    required String accessToken,
    int limit = 20,
  }) async {
    final res = await _dio.get(
      '/workouts/history',
      queryParameters: {'page': 1, 'limit': limit},
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = _extractData(res);
    final list = (data['workouts'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => WorkoutHistoryItem.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<List<LeaderboardEntry>> getLeaderboard({
    required String accessToken,
    required String period,
  }) async {
    final res = await _dio.get(
      '/leaderboard',
      queryParameters: {
        'period': period,
        'scope': 'global',
        'metric': 'distance',
      },
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = _extractData(res);
    final list = (data['entries'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => LeaderboardEntry.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<List<ChallengeSummary>> getChallenges({
    required String accessToken,
  }) async {
    final res = await _dio.get(
      '/challenges',
      queryParameters: {'status': 'active'},
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = _extractData(res);
    final list = (data['challenges'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => ChallengeSummary.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<void> joinChallenge({
    required String accessToken,
    required int challengeId,
  }) async {
    await _dio.post(
      '/challenges/$challengeId/join',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  }

  Future<ChallengeDetails> getChallengeDetail({
    required String accessToken,
    required int challengeId,
  }) async {
    final res = await _dio.get(
      '/challenges/$challengeId',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = _extractData(res);
    final challenge =
        (data['challenge'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ChallengeDetails.fromJson(challenge);
  }

  Future<List<ClubSummary>> getClubs({required String accessToken}) async {
    final res = await _dio.get(
      '/clubs',
      queryParameters: {'page': 1, 'limit': 50},
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = _extractData(res);
    final list = (data['clubs'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => ClubSummary.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<void> joinClub({
    required String accessToken,
    required int clubId,
  }) async {
    await _dio.post(
      '/clubs/$clubId/join',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  }

  Future<ClubDetails> getClubDetail({
    required String accessToken,
    required int clubId,
  }) async {
    final res = await _dio.get(
      '/clubs/$clubId',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = _extractData(res);
    final club = (data['club'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ClubDetails.fromJson(club);
  }

  Future<void> createClub({
    required String accessToken,
    required String name,
    required String description,
  }) async {
    await _dio.post(
      '/clubs',
      data: {'name': name, 'description': description},
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  }

  AuthSession _authSessionFromResponse(Response<dynamic> res) {
    final data = _extractData(res);
    final user = (data['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    final tokens =
        (data['tokens'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AuthSession(
      tokens: AuthTokens.fromJson(tokens),
      profile: _profileFromServer(user),
    );
  }

  Map<String, dynamic> _extractData(Response<dynamic> res) {
    final raw = res.data;
    if (raw is! Map) return const {};
    final root = raw.cast<String, dynamic>();
    final data = root['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    return const {};
  }

  ProfileData _profileFromServer(Map<String, dynamic> user) {
    final firstName = (user['first_name'] as String?) ?? '';
    final lastName = (user['last_name'] as String?) ?? '';
    final displayName = '$firstName $lastName'.trim();
    final username = _usernameFromServer(user);
    return ProfileData.defaults.copyWith(
      firstName: firstName.isNotEmpty
          ? firstName
          : ProfileData.defaults.firstName,
      lastName: lastName.isNotEmpty ? lastName : ProfileData.defaults.lastName,
      username: username,
      email: (user['email'] as String?) ?? ProfileData.defaults.email,
      phone: (user['phone'] as String?) ?? '',
      location: (user['city'] as String?) ?? ProfileData.defaults.location,
      bio: (user['bio'] as String?) ?? '',
      displayName: displayName.isNotEmpty
          ? displayName
          : ProfileData.defaults.displayName,
      avatarUrl: (user['avatar_url'] as String?) ?? '',
      dirty: false,
    );
  }

  String _usernameFromServer(Map<String, dynamic> user) {
    final direct = (user['username'] as String?)?.trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final email = (user['email'] as String?)?.trim() ?? '';
    if (email.contains('@')) {
      final local = email.split('@').first.toLowerCase();
      final normalized = local.replaceAll(RegExp(r'[^a-z0-9._]'), '');
      if (normalized.isNotEmpty) return normalized;
    }
    final id = (user['id'] as num?)?.toInt();
    if (id != null && id > 0) return 'runner$id';
    return '';
  }
}

DateTime? _parseServerDate(Object? raw) {
  final text = (raw as String?)?.trim() ?? '';
  if (text.isEmpty) return null;
  return DateTime.tryParse(text.replaceFirst(' ', 'T'));
}

int _asInt(Object? raw, {int fallback = 0}) {
  if (raw == null) return fallback;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim()) ?? fallback;
  return fallback;
}

int? _asNullableInt(Object? raw) {
  if (raw == null) return null;
  if (raw is String && raw.trim().isEmpty) return null;
  return _asInt(raw);
}

double _asDouble(Object? raw, {double fallback = 0}) {
  if (raw == null) return fallback;
  if (raw is double) return raw;
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw.trim()) ?? fallback;
  return fallback;
}

bool _asBoolFlag(Object? raw) {
  if (raw == null) return false;
  if (raw is bool) return raw;
  if (raw is num) return raw.toInt() == 1;
  if (raw is String) {
    final text = raw.trim().toLowerCase();
    return text == '1' || text == 'true' || text == 'yes';
  }
  return false;
}

class ProfileData {
  const ProfileData({
    required this.displayName,
    required this.username,
    required this.location,
    required this.bio,
    required this.occupation,
    required this.website,
    required this.avatarUrl,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.dob,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.updatedAtMs,
    required this.dirty,
  });

  final String displayName;
  final String username;
  final String location;
  final String bio;
  final String occupation;
  final String website;
  final String avatarUrl;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String dob;
  final String gender;
  final String heightCm;
  final String weightKg;
  final int updatedAtMs;
  final bool dirty;

  static const defaults = ProfileData(
    displayName: '',
    username: '',
    location: '',
    bio: '',
    occupation: '',
    website: '',
    avatarUrl: '',
    firstName: '',
    lastName: '',
    email: '',
    phone: '',
    dob: '',
    gender: '',
    heightCm: '',
    weightKg: '',
    updatedAtMs: 0,
    dirty: false,
  );

  ProfileData copyWith({
    String? displayName,
    String? username,
    String? location,
    String? bio,
    String? occupation,
    String? website,
    String? avatarUrl,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? dob,
    String? gender,
    String? heightCm,
    String? weightKg,
    int? updatedAtMs,
    bool? dirty,
  }) {
    return ProfileData(
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      location: location ?? this.location,
      bio: bio ?? this.bio,
      occupation: occupation ?? this.occupation,
      website: website ?? this.website,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      dirty: dirty ?? this.dirty,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'displayName': displayName,
      'username': username,
      'location': location,
      'bio': bio,
      'occupation': occupation,
      'website': website,
      'avatarUrl': avatarUrl,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'dob': dob,
      'gender': gender,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'updatedAtMs': updatedAtMs,
      'dirty': dirty,
    };
  }

  static ProfileData fromJson(Map<String, dynamic> json) {
    return ProfileData(
      displayName: (json['displayName'] as String?) ?? defaults.displayName,
      username: (json['username'] as String?) ?? defaults.username,
      location: (json['location'] as String?) ?? defaults.location,
      bio: (json['bio'] as String?) ?? defaults.bio,
      occupation: (json['occupation'] as String?) ?? defaults.occupation,
      website: (json['website'] as String?) ?? defaults.website,
      avatarUrl: (json['avatarUrl'] as String?) ?? '',
      firstName: (json['firstName'] as String?) ?? defaults.firstName,
      lastName: (json['lastName'] as String?) ?? defaults.lastName,
      email: (json['email'] as String?) ?? defaults.email,
      phone: (json['phone'] as String?) ?? defaults.phone,
      dob: (json['dob'] as String?) ?? defaults.dob,
      gender: (json['gender'] as String?) ?? defaults.gender,
      heightCm: (json['heightCm'] as String?) ?? defaults.heightCm,
      weightKg: (json['weightKg'] as String?) ?? defaults.weightKg,
      updatedAtMs:
          (json['updatedAtMs'] as num?)?.toInt() ?? defaults.updatedAtMs,
      dirty: (json['dirty'] as bool?) ?? defaults.dirty,
    );
  }
}

class LocalProfileStore {
  static const _keyProfile = 'profile_data_v1';

  static Future<ProfileData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyProfile);
    if (raw == null || raw.isEmpty) return ProfileData.defaults;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return ProfileData.defaults;
      return _normalizeLegacyDefaults(ProfileData.fromJson(decoded));
    } catch (_) {
      return ProfileData.defaults;
    }
  }

  static ProfileData _normalizeLegacyDefaults(ProfileData profile) {
    final isLegacySeed =
        profile.username == 'tirtamandira' ||
        profile.email == 'tirta.mandira@example.com' ||
        (profile.displayName == 'Tirta Mandira' &&
            profile.location == 'Jakarta, Indonesia');
    if (!isLegacySeed) return profile;
    return profile.copyWith(
      displayName: '',
      username: '',
      location: '',
      bio: '',
      occupation: '',
      firstName: '',
      lastName: '',
      email: '',
      phone: '',
      dob: '',
      heightCm: '',
      weightKg: '',
      dirty: false,
    );
  }

  static Future<void> save(
    ProfileData data, {
    bool markDirty = true,
    bool enqueueSync = true,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final stored = data.copyWith(
      updatedAtMs: markDirty ? nowMs : data.updatedAtMs,
      dirty: markDirty,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfile, jsonEncode(stored.toJson()));
    if (markDirty && enqueueSync) {
      await SyncQueueStore.enqueueOrReplaceProfileUpsert(stored.updatedAtMs);
    }
  }

  static Future<void> markSyncedIfUnchanged(int updatedAtMs) async {
    final current = await load();
    if (current.updatedAtMs != updatedAtMs) return;
    await save(
      current.copyWith(dirty: false),
      markDirty: false,
      enqueueSync: false,
    );
  }
}

class SyncOperationType {
  static const profileUpsert = 'profile_upsert';
}

class SyncOperation {
  const SyncOperation({
    required this.id,
    required this.type,
    required this.payload,
    required this.attempts,
    required this.nextAttemptAtMs,
    required this.createdAtMs,
    this.lastError,
  });

  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final int attempts;
  final int nextAttemptAtMs;
  final int createdAtMs;
  final String? lastError;

  SyncOperation copyWith({
    int? attempts,
    int? nextAttemptAtMs,
    String? lastError,
  }) {
    return SyncOperation(
      id: id,
      type: type,
      payload: payload,
      attempts: attempts ?? this.attempts,
      nextAttemptAtMs: nextAttemptAtMs ?? this.nextAttemptAtMs,
      createdAtMs: createdAtMs,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'payload': payload,
      'attempts': attempts,
      'nextAttemptAtMs': nextAttemptAtMs,
      'createdAtMs': createdAtMs,
      'lastError': lastError,
    };
  }

  static SyncOperation fromJson(Map<String, dynamic> json) {
    return SyncOperation(
      id: (json['id'] as String?) ?? '',
      type: (json['type'] as String?) ?? '',
      payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      nextAttemptAtMs: (json['nextAttemptAtMs'] as num?)?.toInt() ?? 0,
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      lastError: json['lastError'] as String?,
    );
  }
}

class SyncQueueStore {
  static const _keyQueue = 'sync_queue_v1';

  static Future<List<SyncOperation>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyQueue);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => SyncOperation.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> save(List<SyncOperation> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyQueue,
      jsonEncode(queue.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> enqueueOrReplaceProfileUpsert(int updatedAtMs) async {
    final queue = await load();
    final filtered = queue
        .where((op) => op.type != SyncOperationType.profileUpsert)
        .toList();
    final now = DateTime.now().millisecondsSinceEpoch;
    filtered.add(
      SyncOperation(
        id: 'profile_upsert_$now',
        type: SyncOperationType.profileUpsert,
        payload: {'updatedAtMs': updatedAtMs},
        attempts: 0,
        nextAttemptAtMs: now,
        createdAtMs: now,
      ),
    );
    await save(filtered);
  }

  static Future<void> removeById(String id) async {
    final queue = await load();
    await save(queue.where((op) => op.id != id).toList());
  }

  static Future<void> upsert(SyncOperation operation) async {
    final queue = await load();
    final updated = queue.where((op) => op.id != operation.id).toList()
      ..add(operation);
    await save(updated);
  }
}

class SyncResult {
  const SyncResult({
    required this.success,
    required this.permanentFailure,
    this.message,
  });

  final bool success;
  final bool permanentFailure;
  final String? message;

  static const ok = SyncResult(success: true, permanentFailure: false);
  static const retry = SyncResult(success: false, permanentFailure: false);
}

abstract class SyncApiClient {
  Future<SyncResult> pushProfile(ProfileData profile);
}

class NoopSyncApiClient implements SyncApiClient {
  const NoopSyncApiClient();

  @override
  Future<SyncResult> pushProfile(ProfileData profile) async {
    return const SyncResult(
      success: false,
      permanentFailure: false,
      message: 'No backend configured yet',
    );
  }
}

class BackendSyncApiClient implements SyncApiClient {
  const BackendSyncApiClient(this._apiClient);

  final BackendApiClient _apiClient;

  @override
  Future<SyncResult> pushProfile(ProfileData profile) async {
    final tokens = await AuthTokenStore.read();
    if (tokens == null || tokens.accessToken.isEmpty) {
      return const SyncResult(
        success: false,
        permanentFailure: false,
        message: 'Not authenticated',
      );
    }
    try {
      await _apiClient.patchProfile(
        accessToken: tokens.accessToken,
        profile: profile,
      );
      return SyncResult.ok;
    } on DioException catch (e) {
      final isRetryable = (e.response?.statusCode ?? 500) >= 500;
      return SyncResult(
        success: false,
        permanentFailure: !isRetryable,
        message: e.message,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        permanentFailure: false,
        message: e.toString(),
      );
    }
  }
}

class SyncWorker {
  SyncWorker({required this.client});

  final SyncApiClient client;
  Timer? _timer;
  bool _busy = false;

  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 20), (_) => kick());
    kick();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
  }

  void kick() {
    unawaited(_processDueOperations());
  }

  Future<void> _processDueOperations() async {
    if (_busy) return;
    _busy = true;
    try {
      final queue = await SyncQueueStore.load();
      if (queue.isEmpty) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      final due = queue.where((op) => op.nextAttemptAtMs <= now).toList()
        ..sort((a, b) => a.nextAttemptAtMs.compareTo(b.nextAttemptAtMs));

      if (due.isEmpty) return;
      final op = due.first;
      if (op.type == SyncOperationType.profileUpsert) {
        await _handleProfileUpsert(op);
      } else {
        await SyncQueueStore.removeById(op.id);
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _handleProfileUpsert(SyncOperation operation) async {
    final profile = await LocalProfileStore.load();
    if (!profile.dirty) {
      await SyncQueueStore.removeById(operation.id);
      return;
    }

    final result = await client.pushProfile(profile);
    if (result.success) {
      await LocalProfileStore.markSyncedIfUnchanged(profile.updatedAtMs);
      await SyncQueueStore.removeById(operation.id);
      return;
    }

    if (result.permanentFailure) {
      await SyncQueueStore.removeById(operation.id);
      return;
    }

    final attempts = operation.attempts + 1;
    final backoffSeconds = attempts <= 1
        ? 5
        : attempts == 2
        ? 15
        : attempts == 3
        ? 30
        : attempts == 4
        ? 60
        : 120;
    final retryAt = DateTime.now()
        .add(Duration(seconds: backoffSeconds))
        .millisecondsSinceEpoch;
    await SyncQueueStore.upsert(
      operation.copyWith(
        attempts: attempts,
        nextAttemptAtMs: retryAt,
        lastError: result.message ?? 'Retry scheduled',
      ),
    );
  }
}
