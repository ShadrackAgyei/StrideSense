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
    try {
      await _apiClient.logout();
    } catch (_) {}
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
    if (!isAuthenticated) return const [];
    try {
      return await _withAuthRetry(
        (token) => _apiClient.getLeaderboard(
          accessToken: token,
          period: filter == LeaderboardFilter.weekly
              ? 'weekly'
              : filter == LeaderboardFilter.monthly
                  ? 'monthly'
                  : 'all',
        ),
      );
    } catch (e) {
      lastError = _readError(e);
      notifyListeners();
      return const [];
    }
  }

  Future<List<ChallengeSummary>> loadChallenges() async {
    if (!isAuthenticated) return const [];
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
    if (!isAuthenticated) return null;
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
    if (!isAuthenticated) return const [];
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
    if (!isAuthenticated) return null;
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
    if (!isAuthenticated) return false;
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
    if (!isAuthenticated) return false;
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
    if (!isAuthenticated) return false;
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

  Future<bool> createChallenge({
    required String title,
    required String description,
    required String type,
    required double targetValue,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    if (!isAuthenticated) return false;
    try {
      await _withAuthRetry(
        (token) => _apiClient.createChallenge(
          accessToken: token,
          title: title,
          description: description,
          type: type,
          targetValue: targetValue,
          startAt: startAt,
          endAt: endAt,
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

    final tokens = _apiClient.currentTokens() ?? await AuthTokenStore.read();
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
    try {
      await _refreshProfileAndDashboard();
    } catch (e) {
      lastError = _readError(e);
      notifyListeners();
    }
  }

  Future<void> _setLocalFallbackAuth() async {
    isAuthenticated = true;
    _tokens = null;
    profile = await LocalProfileStore.load();
    dashboard = await LocalDashboardStore.load();
    notifyListeners();
  }

  Future<void> _refreshProfileAndDashboard() async {
    final localDashboard = await LocalDashboardStore.load();
    final me = await _withAuthRetry(
      (token) => _apiClient.getMe(accessToken: token),
    );
    profile = me.profile;
    await LocalProfileStore.save(profile, markDirty: false, enqueueSync: false);
    final history = await _withAuthRetry(
      (token) => _apiClient.getWorkoutHistory(accessToken: token, limit: 50),
    );
    final mergedWorkouts = _mergeWorkouts(
      localDashboard.recentWorkouts,
      history,
    );
    final mergedCompleted = mergedWorkouts
        .where((w) => w.status.toLowerCase() == 'completed')
        .toList();
    final mergedDistanceM = mergedCompleted.fold<double>(
      0,
      (sum, workout) => sum + workout.distanceM,
    );
    dashboard = DashboardSummary.fromData(
      totalDistanceM: math.max(me.totalDistanceM, mergedDistanceM),
      workoutsCount: math.max(me.workoutsCount, mergedCompleted.length),
      workouts: mergedWorkouts,
    );
    await LocalDashboardStore.save(dashboard);
    notifyListeners();
  }

  List<WorkoutHistoryItem> _mergeWorkouts(
    List<WorkoutHistoryItem> local,
    List<WorkoutHistoryItem> remote,
  ) {
    final merged = <String, WorkoutHistoryItem>{};
    for (final workout in [...remote, ...local]) {
      merged[_workoutKey(workout)] = workout;
    }
    final result = merged.values.toList()
      ..sort((a, b) {
        final aTime = a.startedAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.startedAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });
    return result.take(50).toList();
  }

  String _workoutKey(WorkoutHistoryItem workout) {
    final startedAt = workout.startedAt?.toUtc().toIso8601String() ?? 'unknown';
    final distance = workout.distanceM.toStringAsFixed(2);
    final pace = workout.avgPaceSecPerKm.toStringAsFixed(2);
    final category = workout.category.trim().toLowerCase();
    final status = workout.status.trim().toLowerCase();
    return '$startedAt|$distance|$pace|$category|$status';
  }

  Future<T> _withAuthRetry<T>(
    Future<T> Function(String accessToken) action,
  ) async {
    final tokens = _apiClient.currentTokens() ?? _tokens;
    if (tokens == null) throw StateError('Not authenticated');
    _tokens = tokens;
    try {
      return await action(tokens.accessToken);
    } on AuthException {
      final refreshed = await _apiClient.refresh();
      _tokens = refreshed;
      await AuthTokenStore.write(refreshed);
      return action(refreshed.accessToken);
    } on PostgrestException catch (e) {
      final message = (e.message).toLowerCase();
      final looksAuthRelated =
          message.contains('jwt') ||
          message.contains('token') ||
          message.contains('auth');
      if (!looksAuthRelated) rethrow;
      final refreshed = await _apiClient.refresh();
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
    if (error is PostgrestException) {
      return error.message.isNotEmpty ? error.message : 'Database error occurred';
    }
    if (error is StorageException) {
      final message = error.message.toLowerCase();
      if (message.contains('bucket not found')) {
        return 'Avatar storage is not configured. Ensure the "avatars" bucket and its RLS policies exist in your Supabase project.';
      }
      if (message.contains('row level security') || message.contains('policy')) {
        return 'Permission denied for avatar upload. Check storage RLS policies.';
      }
      return error.message;
    }
    if (error is AuthException) {
      return error.message;
    }
    if (error is StateError) {
      return error.message;
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

  final String userId;
  final String displayName;
  final double totalDistanceM;
  final double avgPaceSecPerKm;
  final int activeDays;

  static LeaderboardEntry fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: (json['user_id'] as String?) ?? '',
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
  BackendApiClient();

  final Uuid _uuid = const Uuid();

  AuthTokens? currentTokens() {
    final session = supabase.auth.currentSession;
    if (session == null) return null;
    return AuthTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken ?? '',
    );
  }

  Future<AuthSession> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    final response = await supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
      },
    );
    var session = response.session;
    if (session == null) {
      final signIn = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      session = signIn.session;
    }
    if (session == null) {
      throw const AuthException(
        'Sign up succeeded, but no session was returned. Disable email confirmation for now or add a verification flow.',
      );
    }
    return _authSessionFromSession(session);
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final session = response.session;
    if (session == null) {
      throw const AuthException('Login did not return a session.');
    }
    return _authSessionFromSession(session);
  }

  Future<AuthTokens> refresh() async {
    final response = await supabase.auth.refreshSession();
    final session = response.session ?? supabase.auth.currentSession;
    if (session == null) {
      throw const AuthException('Unable to refresh the current session.');
    }
    return AuthTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken ?? '',
    );
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
  }

  Future<MeResponse> getMe({required String accessToken}) async {
    final user = _requireUser();
    final profile = await _loadProfile(user.id);
    final stats = await _loadCurrentUserDashboard();
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
    final user = _requireUser();
    await supabase.from('profiles').upsert({
      'id': user.id,
      'first_name': profile.firstName,
      'last_name': profile.lastName,
      'bio': profile.bio,
      'city': profile.location,
      'avatar_url': profile.avatarUrl.isNotEmpty ? profile.avatarUrl : null,
    });
    try {
      await supabase.from('private_user_data').upsert({
        'user_id': user.id,
        'email': user.email ?? profile.email,
        'phone': profile.phone,
      });
    } on PostgrestException catch (e) {
      if (!_isMissingSchemaObject(
        e,
        objectNames: const ['private_user_data'],
      )) {
        rethrow;
      }
    }
    if ((user.email ?? '').isNotEmpty &&
        (profile.email.isNotEmpty && profile.email != user.email)) {
      await supabase.auth.updateUser(UserAttributes(email: profile.email));
    }
    await supabase.auth.updateUser(
      UserAttributes(
        data: {
          'first_name': profile.firstName,
          'last_name': profile.lastName,
          'phone': profile.phone,
        },
      ),
    );
    return _loadProfile(user.id);
  }

  Future<String> uploadAvatar({
    required String accessToken,
    required XFile file,
  }) async {
    final user = _requireUser();
    final ext = (file.name.contains('.') ? file.name.split('.').last : 'jpg').toLowerCase();
    final path = '${user.id}/${_uuid.v4()}.$ext';
    await supabase.storage.from('avatars').upload(
      path,
      File(file.path),
      fileOptions: FileOptions(contentType: _mimeTypeForExt(ext)),
    );
    final avatarUrl = supabase.storage.from('avatars').getPublicUrl(path);
    await supabase.from('profiles').upsert({
      'id': user.id,
      'avatar_url': avatarUrl,
    });
    return avatarUrl;
  }

  String _mimeTypeForExt(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  Future<int> startWorkout({
    required String accessToken,
    required DateTime startedAt,
    required String activityType,
  }) async {
    final user = _requireUser();
    final workout = await supabase
        .from('workouts')
        .insert({
          'user_id': user.id,
          'started_at': startedAt.toUtc().toIso8601String(),
          'activity_type': activityType,
          'source': 'mobile',
        })
        .select()
        .single();
    await supabase.from('workout_events').insert({
      'workout_id': workout['id'],
      'event_type': 'start',
      'event_at': startedAt.toUtc().toIso8601String(),
    });
    return _asInt(workout['id']);
  }

  Future<void> pauseWorkout({
    required String accessToken,
    required int workoutId,
    required DateTime pausedAt,
  }) async {
    await supabase
        .from('workouts')
        .update({'status': 'paused'}).eq('id', workoutId);
    await supabase.from('workout_events').insert({
      'workout_id': workoutId,
      'event_type': 'pause',
      'event_at': pausedAt.toUtc().toIso8601String(),
    });
  }

  Future<void> resumeWorkout({
    required String accessToken,
    required int workoutId,
    required DateTime resumedAt,
  }) async {
    await supabase
        .from('workouts')
        .update({'status': 'running'}).eq('id', workoutId);
    await supabase.from('workout_events').insert({
      'workout_id': workoutId,
      'event_type': 'resume',
      'event_at': resumedAt.toUtc().toIso8601String(),
    });
  }

  Future<void> uploadWorkoutSamples({
    required String accessToken,
    required int workoutId,
    required List<Map<String, dynamic>> samples,
  }) async {
    if (samples.isEmpty) return;
    final normalized = samples.map((sample) {
      return {
        'workout_id': workoutId,
        'captured_at': sample['captured_at'],
        'latitude': sample['latitude'],
        'longitude': sample['longitude'],
        'altitude_m': sample['altitude_m'],
        'distance_m': sample['distance_m'],
        'pace_sec_per_km': sample['pace_sec_per_km'],
        'heart_rate_bpm': sample['heart_rate_bpm'],
        'steps': sample['steps'],
        'calories_kcal': sample['calories_kcal'],
        'source': sample['source'] ?? 'gps',
      };
    }).toList();
    await supabase.from('workout_samples').insert(normalized);
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
    await supabase
        .from('workouts')
        .update({
          'status': 'completed',
          'ended_at': endedAt.toUtc().toIso8601String(),
          'duration_sec': durationSec,
          'distance_m': distanceM,
          'avg_pace_sec_per_km': avgPaceSecPerKm,
          'category': category,
        })
        .eq('id', workoutId);
    await supabase.from('workout_events').insert({
      'workout_id': workoutId,
      'event_type': 'complete',
      'event_at': endedAt.toUtc().toIso8601String(),
    });
  }

  Future<List<WorkoutHistoryItem>> getWorkoutHistory({
    required String accessToken,
    int limit = 20,
  }) async {
    final user = _requireUser();
    final list = await supabase
        .from('workouts')
        .select()
        .eq('user_id', user.id)
        .order('started_at', ascending: false)
        .limit(limit);
    return list
        .whereType<Map>()
        .map((e) => WorkoutHistoryItem.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<List<LeaderboardEntry>> getLeaderboard({
    required String accessToken,
    required String period,
  }) async {
    final result = await supabase.rpc(
      'leaderboard_distance',
      params: {'period': period},
    );
    final list = result is List ? result : const [];
    return list
        .whereType<Map>()
        .map((e) => LeaderboardEntry.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<List<ChallengeSummary>> getChallenges({
    required String accessToken,
  }) async {
    final user = _requireUser();
    final list = await supabase
        .from('challenges')
        .select()
        .eq('status', 'active')
        .order('start_at');
    final joinedRows = await supabase
        .from('challenge_participants')
        .select('challenge_id')
        .eq('user_id', user.id);
    final joinedIds = joinedRows
        .whereType<Map>()
        .map((e) => _asInt(e['challenge_id']))
        .toSet();
    return list
        .whereType<Map>()
        .map((e) {
          final row = e.cast<String, dynamic>();
          row['joined'] = joinedIds.contains(_asInt(row['id']));
          return ChallengeSummary.fromJson(row);
        })
        .toList();
  }

  Future<void> joinChallenge({
    required String accessToken,
    required int challengeId,
  }) async {
    final user = _requireUser();
    await supabase.from('challenge_participants').insert({
      'challenge_id': challengeId,
      'user_id': user.id,
    });
  }

  Future<ChallengeDetails> getChallengeDetail({
    required String accessToken,
    required int challengeId,
  }) async {
    final user = _requireUser();
    final challenge = await supabase
        .from('challenges')
        .select()
        .eq('id', challengeId)
        .single();
    final joined = await supabase
        .from('challenge_participants')
        .select('id')
        .eq('challenge_id', challengeId)
        .eq('user_id', user.id)
        .maybeSingle();
    final row = challenge.cast<String, dynamic>();
    row['joined'] = joined != null;
    return ChallengeDetails.fromJson(row);
  }

  Future<List<ClubSummary>> getClubs({required String accessToken}) async {
    final user = _requireUser();
    final list = await supabase.from('clubs').select().order('created_at');
    final memberRows = await supabase
        .from('club_members')
        .select('club_id,user_id');
    final joinedIds = memberRows
        .whereType<Map>()
        .where((row) => row['user_id'] == user.id)
        .map((row) => _asInt(row['club_id']))
        .toSet();
    final counts = <int, int>{};
    for (final row in memberRows.whereType<Map>()) {
      final clubId = _asInt(row['club_id']);
      counts[clubId] = (counts[clubId] ?? 0) + 1;
    }
    return list
        .whereType<Map>()
        .map((e) {
          final row = e.cast<String, dynamic>();
          final id = _asInt(row['id']);
          row['member_count'] = counts[id] ?? 0;
          row['joined'] = joinedIds.contains(id);
          return ClubSummary.fromJson(row);
        })
        .toList();
  }

  Future<void> joinClub({
    required String accessToken,
    required int clubId,
  }) async {
    final user = _requireUser();
    await supabase.from('club_members').insert({
      'club_id': clubId,
      'user_id': user.id,
    });
  }

  Future<ClubDetails> getClubDetail({
    required String accessToken,
    required int clubId,
  }) async {
    final user = _requireUser();
    final club = await supabase.from('clubs').select().eq('id', clubId).single();
    final members = await supabase
        .from('club_members')
        .select('user_id')
        .eq('club_id', clubId);
    final row = club.cast<String, dynamic>();
    row['member_count'] = members.length;
    row['joined'] = members
        .whereType<Map>()
        .any((member) => member['user_id'] == user.id);
    return ClubDetails.fromJson(row);
  }

  Future<void> createClub({
    required String accessToken,
    required String name,
    required String description,
  }) async {
    final user = _requireUser();
    final club = await supabase
        .from('clubs')
        .insert({
          'name': name,
          'description': description,
          'created_by': user.id,
        })
        .select()
        .single();
    await supabase.from('club_members').insert({
      'club_id': club['id'],
      'user_id': user.id,
      'role': 'owner',
    });
  }

  Future<void> createChallenge({
    required String accessToken,
    required String title,
    required String description,
    required String type,
    required double targetValue,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final user = _requireUser();
    final challenge = await supabase
        .from('challenges')
        .insert({
          'title': title,
          'description': description,
          'type': type,
          'target_value': targetValue,
          'start_at': startAt.toUtc().toIso8601String(),
          'end_at': endAt.toUtc().toIso8601String(),
          'status': 'active',
          'created_by': user.id,
        })
        .select()
        .single();
    // Auto-join the creator
    await supabase.from('challenge_participants').insert({
      'challenge_id': challenge['id'],
      'user_id': user.id,
    });
  }

  AuthSession _authSessionFromSession(Session session) {
    final user = session.user;
    return AuthSession(
      tokens: AuthTokens(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken ?? '',
      ),
      profile: ProfileData.defaults.copyWith(
        firstName: (user.userMetadata?['first_name'] as String?) ?? '',
        lastName: (user.userMetadata?['last_name'] as String?) ?? '',
        displayName: [
          (user.userMetadata?['first_name'] as String?) ?? '',
          (user.userMetadata?['last_name'] as String?) ?? '',
        ].join(' ').trim(),
        username: _usernameFromServer({
          'id': user.id,
          'email': user.email,
        }),
        email: user.email ?? '',
        phone: (user.userMetadata?['phone'] as String?) ?? '',
        dirty: false,
      ),
    );
  }

  Future<ProfileData> _loadProfile(String userId) async {
    final authUser = _requireUser();
    final rawProfileRow = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    Object? privateRow;
    try {
      privateRow = await supabase
          .from('private_user_data')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
    } on PostgrestException catch (e) {
      if (
          !_isMissingSchemaObject(
            e,
            objectNames: const ['private_user_data'],
          )) {
        rethrow;
      }
      privateRow = null;
    }
    final profileMap = rawProfileRow is Map
        ? Map<String, dynamic>.from(rawProfileRow as Map)
        : const <String, dynamic>{};
    final privateMap = privateRow is Map
        ? Map<String, dynamic>.from(privateRow)
        : const <String, dynamic>{};
    final metadata = authUser.userMetadata ?? const <String, dynamic>{};
    final firstName =
        (profileMap['first_name'] as String?)?.trim().isNotEmpty == true
        ? profileMap['first_name'] as String
        : (metadata['first_name'] as String?)?.trim() ?? '';
    final lastName =
        (profileMap['last_name'] as String?)?.trim().isNotEmpty == true
        ? profileMap['last_name'] as String
        : (metadata['last_name'] as String?)?.trim() ?? '';
    final phone =
        (privateMap['phone'] as String?)?.trim().isNotEmpty == true
        ? privateMap['phone'] as String
        : (metadata['phone'] as String?)?.trim() ?? '';
    final seededProfileMap = {
      ...profileMap,
      if (firstName.isNotEmpty) 'first_name': firstName,
      if (lastName.isNotEmpty) 'last_name': lastName,
    };
    final seededPrivateMap = {
      ...privateMap,
      if (phone.isNotEmpty) 'phone': phone,
    };
    final merged = <String, dynamic>{
      'id': authUser.id,
      'email': authUser.email ?? '',
      ...seededProfileMap,
      ...seededPrivateMap,
    };
    return _profileFromServer(merged);
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
    final uuid = (user['id'] as String?)?.trim() ?? '';
    if (uuid.isNotEmpty) return 'runner_${uuid.substring(0, math.min(8, uuid.length))}';
    return '';
  }

  User _requireUser() {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException('Not authenticated.');
    }
    return user;
  }

  Future<Map<String, dynamic>> _loadCurrentUserDashboard() async {
    dynamic result;
    try {
      result = await supabase.rpc('current_user_dashboard');
    } on PostgrestException catch (e) {
      if (!_isMissingSchemaObject(
        e,
        objectNames: const ['current_user_dashboard', 'workouts'],
      )) {
        rethrow;
      }
      return const {'total_distance_m': 0, 'workouts_count': 0};
    }
    if (result is List && result.isNotEmpty && result.first is Map) {
      return (result.first as Map).cast<String, dynamic>();
    }
    if (result is Map) {
      return result.cast<String, dynamic>();
    }
    return const {'total_distance_m': 0, 'workouts_count': 0};
  }
}

bool _isMissingSchemaObject(
  PostgrestException e, {
  required List<String> objectNames,
}) {
  final code = (e.code ?? '').trim().toUpperCase();
  final message = e.message.toLowerCase();
  final details = (e.details?.toString() ?? '').toLowerCase();
  if (code == 'PGRST205') {
    return true;
  }
  for (final name in objectNames) {
    final lower = name.toLowerCase();
    if (message.contains(lower) || details.contains(lower)) {
      if (message.contains('could not find') ||
          message.contains('schema cache') ||
          details.contains('could not find') ||
          details.contains('schema cache') ||
          details.contains('not found')) {
        return true;
      }
    }
  }
  return false;
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

class NotificationService {
  static bool _ready = false;

  static Future<void> init() async {
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));
      _ready = true;
    } catch (_) {
      // Plugin not available in this environment
    }
  }

  static Future<void> workoutStarted() =>
      _show(1, 'Workout Started!', 'Your run is being tracked. Keep going!');

  static Future<void> workoutCompleted(double distKm, String pace) =>
      _show(2, 'Workout Complete!',
          '${distKm.toStringAsFixed(2)} km · $pace — Great work!');

  static Future<void> challengeJoined(String challengeTitle) =>
      _show(3, 'Challenge Joined!', 'You\'ve joined "$challengeTitle". Good luck!');

  static Future<void> clubCreated(String clubName) =>
      _show(4, 'Club Created!', '"$clubName" is live. Invite friends to run together.');

  static Future<void> sendTestNotification() =>
      _show(99, 'Test Notification', 'StrideSense notifications are working! 🎉');

  static Future<void> _show(int id, String title, String body) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'stridesense_workouts',
            'Workout Notifications',
            channelDescription: 'StrideSense workout and activity updates',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {}
  }

  static final _plugin = FlutterLocalNotificationsPlugin();
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
