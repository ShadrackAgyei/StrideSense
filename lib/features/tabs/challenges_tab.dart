part of '../../main.dart';

class RecordTab extends StatefulWidget {
  const RecordTab({super.key});

  @override
  State<RecordTab> createState() => _RecordTabState();
}

class _RecordTabState extends State<RecordTab> {
  WorkoutSessionState _sessionState = WorkoutSessionState.idle;
  double _distanceKm = 0.0;
  int _elapsedSeconds = 0;
  Timer? _elapsedTicker;
  Timer? _simulatedTicker;
  StreamSubscription<Position>? _positionSubscription;
  final Stopwatch _stopwatch = Stopwatch();
  Position? _lastPosition;
  bool _usingSimulatedTracking = false;
  int _simTick = 0;
  String _locationHint = 'Location ready';
  List<RoutePoint> _routePoints = const [];
  int? _activeWorkoutId;

  @override
  void dispose() {
    _elapsedTicker?.cancel();
    _simulatedTicker?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startWorkout() async {
    final canTrack = await _ensureLocationReady();
    if (!mounted) return;

    if (_sessionState == WorkoutSessionState.idle ||
        _sessionState == WorkoutSessionState.completed) {
      _distanceKm = 0;
      _elapsedSeconds = 0;
      _simTick = 0;
      _stopwatch
        ..reset()
        ..start();
      _routePoints = const [];
      _lastPosition = null;
      _activeWorkoutId = null;
    } else if (_sessionState == WorkoutSessionState.paused) {
      _stopwatch.start();
      if (_activeWorkoutId != null) {
        unawaited(
          SessionScope.of(
            context,
          ).resumeWorkoutSession(_activeWorkoutId!, DateTime.now().toUtc()),
        );
      }
    }

    _elapsedTicker?.cancel();
    _elapsedTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_stopwatch.isRunning) return;
      setState(() => _elapsedSeconds = _stopwatch.elapsed.inSeconds);
    });

    _simulatedTicker?.cancel();
    _positionSubscription?.cancel();
    if (canTrack) {
      _usingSimulatedTracking = false;
      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 3,
            ),
          ).listen((position) {
            if (!mounted || _sessionState != WorkoutSessionState.running) {
              return;
            }
            setState(() {
              _locationHint =
                  'GPS ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
              if (_lastPosition != null) {
                final meters = Geolocator.distanceBetween(
                  _lastPosition!.latitude,
                  _lastPosition!.longitude,
                  position.latitude,
                  position.longitude,
                );
                if (meters.isFinite && meters > 0) {
                  _distanceKm += meters / 1000;
                }
              }
              _lastPosition = position;
              _routePoints = [
                ..._routePoints,
                RoutePoint(lat: position.latitude, lng: position.longitude),
              ];
            });
          });

      if (_lastPosition == null) {
        try {
          final current = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          if (!mounted) return;
          setState(() {
            _lastPosition = current;
            _routePoints = [
              ..._routePoints,
              RoutePoint(lat: current.latitude, lng: current.longitude),
            ];
          });
        } catch (_) {
          _startSimulatedTracking();
        }
      }
    } else {
      _startSimulatedTracking();
    }

    setState(() {
      _sessionState = WorkoutSessionState.running;
    });
    if (_activeWorkoutId == null) {
      final workoutId = await SessionScope.of(context).startWorkoutSession(
        startedAt: DateTime.now().toUtc(),
        activityType: 'run',
      );
      if (!mounted) return;
      setState(() => _activeWorkoutId = workoutId);
    }
  }

  void _pauseWorkout() {
    _stopwatch.stop();
    _elapsedTicker?.cancel();
    _simulatedTicker?.cancel();
    _positionSubscription?.cancel();
    if (_activeWorkoutId != null) {
      unawaited(
        SessionScope.of(
          context,
        ).pauseWorkoutSession(_activeWorkoutId!, DateTime.now().toUtc()),
      );
    }
    setState(() => _sessionState = WorkoutSessionState.paused);
  }

  void _stopWorkout() {
    _stopwatch.stop();
    _elapsedTicker?.cancel();
    _simulatedTicker?.cancel();
    _positionSubscription?.cancel();
    _elapsedSeconds = _stopwatch.elapsed.inSeconds;
    setState(() => _sessionState = WorkoutSessionState.completed);
    final paceMinutesPerKm = _distanceKm > 0
        ? (_elapsedSeconds / 60) / _distanceKm
        : 0.0;
    Navigator.pushNamed(
      context,
      AppRoutes.logWorkout,
      arguments: LogWorkoutArgs(
        originTab: AppTab.records,
        routePoints: _routePoints,
        workoutId: _activeWorkoutId,
        elapsedSeconds: _elapsedSeconds,
        distanceKm: _distanceKm,
        paceMinutesPerKm: paceMinutesPerKm,
      ),
    );
  }

  String get _statusLabel {
    switch (_sessionState) {
      case WorkoutSessionState.idle:
        return 'Ready to start';
      case WorkoutSessionState.running:
        return _usingSimulatedTracking
            ? 'Workout running (simulated route)'
            : 'Workout running with live GPS';
      case WorkoutSessionState.paused:
        return 'Workout paused';
      case WorkoutSessionState.completed:
        return 'Workout saved';
    }
  }

  Future<bool> _ensureLocationReady() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _showPermissionDialog(
          title: 'Turn on location services',
          message:
              'StrideSense needs location services enabled to track your real route. You can turn them on now or continue with a simulated route.',
          openSettings: Geolocator.openLocationSettings,
        );
        if (!mounted) return false;
        setState(() {
          _locationHint =
              'Location services are off. Starting with simulated route.';
        });
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        await _showPermissionDialog(
          title: 'Location permission needed',
          message:
              'Allow location access while using the app so StrideSense can record your run instead of using a simulated route.',
          openSettings: Geolocator.openAppSettings,
        );
        if (!mounted) return false;
        setState(() {
          _locationHint = 'Location permission denied. Using simulated route.';
        });
        return false;
      }
      if (permission == LocationPermission.deniedForever) {
        await _showPermissionDialog(
          title: 'Location permission blocked',
          message:
              'Location permission is blocked for StrideSense. Open app settings and allow location access to record a live route.',
          openSettings: Geolocator.openAppSettings,
        );
        if (!mounted) return false;
        setState(() {
          _locationHint =
              'Location permission denied forever. Using simulated route.';
        });
        return false;
      }

      setState(() => _locationHint = 'Location permission granted.');
      return true;
    } catch (_) {
      setState(() {
        _locationHint =
            'Location unavailable on this build. Using simulated route.';
      });
      return false;
    }
  }

  Future<void> _showPermissionDialog({
    required String title,
    required String message,
    required Future<bool> Function() openSettings,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.primary),
            onPressed: () async {
              Navigator.pop(context);
              await openSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _startSimulatedTracking() {
    _usingSimulatedTracking = true;
    if (_routePoints.isEmpty) {
      _routePoints = const [RoutePoint(lat: 5.6037, lng: -0.1870)];
    }
    _simulatedTicker?.cancel();
    _simulatedTicker = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || _sessionState != WorkoutSessionState.running) return;
      setState(() {
        _simTick += 1;
        _distanceKm += 0.006;
        final last = _routePoints.last;
        final next = RoutePoint(
          lat: last.lat + (math.sin(_simTick / 4) * 0.00012),
          lng: last.lng + (math.cos(_simTick / 5) * 0.00014),
        );
        _routePoints = [..._routePoints, next];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = SessionScope.of(context).dashboard;
    final workouts = dashboard.recentWorkouts;
    final records = workouts
        .take(8)
        .map(
          (w) => (
            w.category.isNotEmpty ? w.category : 'Workout',
            _formatWorkoutDate(w.startedAt),
            '${(w.distanceM / 1000).toStringAsFixed(2)} km',
          ),
        )
        .toList();
    final weeklySessions = workouts.where((w) {
      final startedAt = w.startedAt;
      if (startedAt == null) return false;
      final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 7));
      return startedAt.toUtc().isAfter(cutoff) &&
          w.status.toLowerCase() == 'completed';
    }).length;

    return ShellScaffold(
      title: 'Record',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD9DFF5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Workout Controls',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusLabel,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _locationHint,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppPalette.primary,
                        ),
                        onPressed: _sessionState == WorkoutSessionState.running
                            ? null
                            : () => _startWorkout(),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _sessionState == WorkoutSessionState.running
                            ? _pauseWorkout
                            : null,
                        icon: const Icon(Icons.pause),
                        label: const Text('Pause'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _sessionState == WorkoutSessionState.idle
                            ? null
                            : _stopWorkout,
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _MetricChip(
                      label: 'Live Distance',
                      value: '${_distanceKm.toStringAsFixed(2)} km',
                    ),
                    const SizedBox(width: 8),
                    _MetricChip(
                      label: 'Duration',
                      value: _formatElapsedCompact(_elapsedSeconds),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F5FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: StatCell(
                    value:
                        '${dashboard.weeklyDistanceKm.toStringAsFixed(1)} km',
                    label: 'This Week',
                  ),
                ),
                Expanded(
                  child: StatCell(
                    value: _formatPace(dashboard.weeklyAvgPaceSecPerKm),
                    label: 'Avg Pace',
                  ),
                ),
                Expanded(
                  child: StatCell(value: '$weeklySessions', label: 'Sessions'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Recent Records',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No records yet. Tap Start to track your first workout.',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          for (var i = 0; i < records.length; i++) ...[
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: i == 0 ? AppPalette.primary : const Color(0xFFE4E7F4),
                ),
              ),
              tileColor: const Color(0xFFF9FAFF),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFDCE3FF),
                child: Icon(Icons.directions_run, color: AppPalette.primary),
              ),
              title: Text(
                '${records[i].$1} • ${records[i].$2}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                records[i].$3,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppPalette.primary,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.workoutSummary,
                arguments: WorkoutSummaryArgs(
                  originTab: AppTab.records,
                  workout: workouts[i],
                ),
              ),
            ),
            if (i != records.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  String _formatElapsedCompact(int seconds) {
    final clamped = seconds.clamp(0, 99 * 60);
    final m = (clamped ~/ 60).toString().padLeft(2, '0');
    final s = (clamped % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatWorkoutDate(DateTime? dt) {
    if (dt == null) return '--/--/----';
    final d = dt.toLocal();
    return '${d.day}/${d.month}/${d.year}';
  }

  String _formatPace(double secPerKm) {
    if (secPerKm <= 0) return '--:--/km';
    final total = secPerKm.round();
    final m = (total ~/ 60).toString();
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s/km';
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEBEFFF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: AppPalette.primary,
                fontWeight: FontWeight.w900,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChallengesTab extends StatefulWidget {
  const ChallengesTab({super.key, this.showBack = false});

  final bool showBack;

  @override
  State<ChallengesTab> createState() => _ChallengesTabState();
}

class _ChallengesTabState extends State<ChallengesTab> {
  bool _clubsSelected = false;
  bool _loading = true;
  List<ChallengeSummary> _challenges = const [];
  List<ClubSummary> _clubs = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadData());
  }

  Future<void> _loadData() async {
    final session = SessionScope.of(context);
    final challenges = await session.loadChallenges();
    final clubs = await session.loadClubs();
    if (!mounted) return;
    setState(() {
      _challenges = challenges;
      _clubs = clubs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ShellScaffold(
      title: 'Challenges',
      showBack: widget.showBack,
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Active Challenges'),
                    ),
                    ButtonSegment<bool>(value: true, label: Text('Clubs')),
                  ],
                  selected: {_clubsSelected},
                  onSelectionChanged: (selection) =>
                      setState(() => _clubsSelected = selection.first),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: _loading
                      ? const [
                          Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ]
                      : _clubsSelected
                      ? _buildClubs(context)
                      : _buildActive(context),
                ),
              ),
            ],
          ),
          if (_clubsSelected)
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.extended(
                backgroundColor: AppPalette.primary,
                foregroundColor: Colors.white,
                onPressed: () async {
                  final created = await _showCreateClubDialog(context);
                  if (created) {
                    await _loadData();
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Create Club'),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildActive(BuildContext context) {
    if (_challenges.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(12),
          child: Text('No active challenges available.'),
        ),
      ];
    }
    return _challenges.map((challenge) {
      return ChallengeCard(
        title: challenge.title,
        subtitle: challenge.description.isNotEmpty
            ? challenge.description
            : 'Status: ${challenge.status}',
        actionLabel: challenge.joined ? 'View' : 'Join',
        membershipState: challenge.joined
            ? ChallengeMembershipState.joined
            : ChallengeMembershipState.notJoined,
        onTap: () async {
          final session = SessionScope.of(context);
          final messenger = ScaffoldMessenger.of(context);
          var joinedForDetails = challenge.joined;
          if (!challenge.joined) {
            final ok = await session.joinChallenge(challenge.id);
            if (!mounted) return;
            if (ok) {
              joinedForDetails = true;
              messenger.showSnackBar(
                SnackBar(content: Text('Joined ${challenge.title}.')),
              );
              await _loadData();
            } else {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    session.lastError ?? 'Could not join challenge',
                  ),
                ),
              );
            }
          }
          if (!context.mounted) return;
          Navigator.pushNamed(
            context,
            AppRoutes.challengeDetail,
            arguments: ChallengeDetailArgs(
              id: challenge.id,
              title: challenge.title,
              description: challenge.description,
              joined: joinedForDetails,
            ),
          );
        },
      );
    }).toList();
  }

  List<Widget> _buildClubs(BuildContext context) {
    if (_clubs.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(12),
          child: Text('No clubs found yet. Create one to get started.'),
        ),
      ];
    }
    return _clubs.map((club) {
      return ClubCard(
        name: club.name,
        memberCount: club.memberCount,
        onTap: () async {
          final session = SessionScope.of(context);
          final messenger = ScaffoldMessenger.of(context);
          var joinedForDetails = club.joined;
          if (!club.joined) {
            final ok = await session.joinClub(club.id);
            if (!mounted) return;
            if (ok) {
              joinedForDetails = true;
              messenger.showSnackBar(
                SnackBar(content: Text('Joined ${club.name}.')),
              );
              await _loadData();
            } else {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(session.lastError ?? 'Could not join club'),
                ),
              );
            }
          }
          if (!context.mounted) return;
          Navigator.pushNamed(
            context,
            AppRoutes.clubDetail,
            arguments: ClubDetailArgs(
              id: club.id,
              name: club.name,
              description: club.description,
              memberCount: club.memberCount,
              joined: joinedForDetails,
            ),
          );
        },
      );
    }).toList();
  }

  Future<bool> _showCreateClubDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    bool loading = false;
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Create Club'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Club name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: loading
                    ? null
                    : () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: loading
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        final description = descriptionController.text.trim();
                        if (name.isEmpty) return;
                        setDialogState(() => loading = true);
                        final ok = await SessionScope.of(
                          context,
                        ).createClub(name, description);
                        if (!context.mounted) return;
                        if (ok) {
                          Navigator.pop(dialogContext, true);
                        } else {
                          setDialogState(() => loading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                SessionScope.of(context).lastError ??
                                    'Could not create club',
                              ),
                            ),
                          );
                        }
                      },
                child: const Text('Create'),
              ),
            ],
          ),
        );
      },
    );
    nameController.dispose();
    descriptionController.dispose();
    return created ?? false;
  }
}
