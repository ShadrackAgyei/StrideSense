part of '../../main.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, required this.args});

  final LeaderboardArgs args;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  LeaderboardFilter _filter = LeaderboardFilter.weekly;
  bool _loading = true;
  List<LeaderboardEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadLeaderboard());
  }

  Future<void> _loadLeaderboard() async {
    final entries = await SessionScope.of(
      context,
    ).loadLeaderboard(filter: _filter);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final myName = session.profile.displayName;
    final myIndex = _entries.indexWhere((e) => e.displayName == myName);
    return ShellScaffold(
      title: 'Leaderboard',
      showBack: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'StrideSense',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Leaderboard',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text('Context: ${widget.args.contextLabel} leaderboard'),
            const SizedBox(height: 12),
            const Text(
              'Filter by Time Frame',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: [
                ChoiceChip(
                  label: const Text('Weekly'),
                  selected: _filter == LeaderboardFilter.weekly,
                  onSelected: (_) {
                    setState(() {
                      _filter = LeaderboardFilter.weekly;
                      _loading = true;
                    });
                    unawaited(_loadLeaderboard());
                  },
                ),
                ChoiceChip(
                  label: const Text('Monthly'),
                  selected: _filter == LeaderboardFilter.monthly,
                  onSelected: (_) {
                    setState(() {
                      _filter = LeaderboardFilter.monthly;
                      _loading = true;
                    });
                    unawaited(_loadLeaderboard());
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loading && _entries.isEmpty)
              const Text('No leaderboard data yet. Complete a workout first.'),
            if (!_loading)
              for (var i = 0; i < _entries.length && i < 10; i++) ...[
                PerformerTile(
                  name: '${i + 1}. ${_entries[i].displayName}',
                  metric:
                      'Distance: ${(_entries[i].totalDistanceM / 1000).toStringAsFixed(2)} km',
                ),
                if (i != _entries.length - 1 && i < 9)
                  const SizedBox(height: 8),
              ],
            const SizedBox(height: 16),
            const Text(
              'Your Ranking',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppPalette.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const CircleAvatar(child: Icon(Icons.person)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You\nRank: ${myIndex >= 0 ? '#${myIndex + 1}' : '--'}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF333333),
                    ),
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.challengeDetail,
                      arguments: const ChallengeDetailArgs(
                        title: 'Context Challenge',
                      ),
                    ),
                    child: const Text('Challenge'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LogWorkoutScreen extends StatefulWidget {
  const LogWorkoutScreen({super.key, required this.args});

  final LogWorkoutArgs args;

  @override
  State<LogWorkoutScreen> createState() => _LogWorkoutScreenState();
}

class _LogWorkoutScreenState extends State<LogWorkoutScreen> {
  String? _selectedCategory;
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _formatDuration(widget.args.elapsedSeconds);
    final distance = widget.args.distanceKm > 0 ? widget.args.distanceKm : 5.2;
    final pace = _formatPace(
      widget.args.paceMinutesPerKm > 0 ? widget.args.paceMinutesPerKm : 6.5,
    );
    final points = widget.args.routePoints.isEmpty
        ? const [
            RoutePoint(lat: 5.6037, lng: -0.1870),
            RoutePoint(lat: 5.6042, lng: -0.1865),
            RoutePoint(lat: 5.6048, lng: -0.1869),
            RoutePoint(lat: 5.6054, lng: -0.1860),
            RoutePoint(lat: 5.6061, lng: -0.1857),
          ]
        : widget.args.routePoints;

    return ShellScaffold(
      title: 'Log Workout',
      showBack: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFDDE3FA)),
              ),
              child: _RouteMapPreview(points: points),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  elapsed,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text('Distance: ${distance.toStringAsFixed(2)}'),
                Text('Pace: $pace'),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Workout Category',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final label in [
                  'Interval Training',
                  'Hill Repeats',
                  'Long Run',
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _selectedCategory == label,
                    onSelected: (_) =>
                        setState(() => _selectedCategory = label),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _notes,
              label: 'Notes (optional)',
              hint: 'How did the run feel?',
            ),
            const SizedBox(height: 10),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.primary,
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: () async {
                final session = SessionScope.of(context);
                final completedAt = DateTime.now().toUtc();
                final effectivePaceMinutesPerKm = widget.args.paceMinutesPerKm > 0
                    ? widget.args.paceMinutesPerKm
                    : (distance > 0
                          ? (widget.args.elapsedSeconds / 60) / distance
                          : 0.0);
                await session.recordWorkoutLocally(
                  endedAt: completedAt,
                  durationSec: widget.args.elapsedSeconds,
                  distanceKm: distance,
                  paceMinutesPerKm: effectivePaceMinutesPerKm,
                  category: _selectedCategory,
                );
                if (widget.args.workoutId != null) {
                  try {
                    await session.uploadWorkoutSamples(
                      widget.args.workoutId!,
                      points,
                      widget.args.elapsedSeconds,
                      distance,
                    );
                    await session.completeWorkoutSession(
                      workoutId: widget.args.workoutId!,
                      endedAt: completedAt,
                      durationSec: widget.args.elapsedSeconds,
                      distanceKm: distance,
                      paceMinutesPerKm: effectivePaceMinutesPerKm,
                      category: _selectedCategory,
                    );
                  } catch (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          session.lastError ??
                              'Could not sync workout to cloud. Saved locally.',
                        ),
                      ),
                    );
                  }
                }
                if (!context.mounted) return;
                final targetRoute = widget.args.originTab == AppTab.profile
                    ? AppRoutes.profile
                    : widget.args.originTab == AppTab.records
                    ? AppRoutes.records
                    : AppRoutes.home;
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  targetRoute,
                  (_) => false,
                );
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Workout saved.')));
              },
              child: const Text('Save Workout'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final s = seconds.clamp(0, 99 * 3600);
    final h = (s ~/ 3600).toString().padLeft(2, '0');
    final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$h:$m:$sec';
  }

  String _formatPace(double paceMinutesPerKm) {
    if (paceMinutesPerKm <= 0) return '--:--/km';
    final totalSeconds = (paceMinutesPerKm * 60).round();
    final min = totalSeconds ~/ 60;
    final sec = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$min:$sec/km';
  }
}

class WorkoutSummaryScreen extends StatefulWidget {
  const WorkoutSummaryScreen({super.key, required this.args});

  final WorkoutSummaryArgs args;

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen> {
  @override
  Widget build(BuildContext context) {
    final workout = widget.args.workout;
    final distanceKm = workout.distanceM / 1000;
    final startedAt = workout.startedAt?.toLocal();
    final pace = _formatPace(workout.avgPaceSecPerKm);
    final category = workout.category.trim().isNotEmpty
        ? workout.category.trim()
        : 'Uncategorized';
    final dateLabel = startedAt == null
        ? '--/--/----'
        : '${startedAt.day}/${startedAt.month}/${startedAt.year}';
    final timeLabel = startedAt == null
        ? '--:--'
        : '${startedAt.hour.toString().padLeft(2, '0')}:${startedAt.minute.toString().padLeft(2, '0')}';
    final durationLabel = _estimateDuration(
      workout.distanceM,
      workout.avgPaceSecPerKm,
    );

    return ShellScaffold(
      title: 'Workout Summary',
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Workout Details',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              '$dateLabel • $timeLabel',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MetricChip(
                    label: 'Distance',
                    value: '${distanceKm.toStringAsFixed(2)} km',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricChip(label: 'Avg Pace', value: pace),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MetricChip(
                    label: 'Duration',
                    value: durationLabel,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricChip(
                    label: 'Status',
                    value: workout.status.toUpperCase(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Category',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPace(double paceSecPerKm) {
    if (paceSecPerKm <= 0) return '--:--/km';
    final totalSeconds = paceSecPerKm.round();
    final min = totalSeconds ~/ 60;
    final sec = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$min:$sec/km';
  }

  String _estimateDuration(double distanceM, double paceSecPerKm) {
    if (distanceM <= 0 || paceSecPerKm <= 0) return '--:--';
    final totalSeconds = ((distanceM / 1000) * paceSecPerKm).round();
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class PersonalInformationSettingsScreen extends StatefulWidget {
  const PersonalInformationSettingsScreen({super.key});

  @override
  State<PersonalInformationSettingsScreen> createState() =>
      _PersonalInformationSettingsScreenState();
}

class _PersonalInformationSettingsScreenState
    extends State<PersonalInformationSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _dirty = false;
  bool _loading = true;
  ProfileData _profile = ProfileData.defaults;

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _dob = TextEditingController();
  final _gender = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await LocalProfileStore.load();
    if (!mounted) return;
    _profile = profile;
    _firstName.text = profile.firstName;
    _lastName.text = profile.lastName;
    _email.text = profile.email;
    _phone.text = profile.phone;
    _dob.text = profile.dob;
    _gender.text = profile.gender;
    _height.text = profile.heightCm;
    _weight.text = profile.weightKg;
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _dob.dispose();
    _gender.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<bool> _confirmDiscardIfDirty() async {
    if (!_dirty) {
      return true;
    }
    final bool? shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.primary),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return shouldDiscard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final shouldDiscard = await _confirmDiscardIfDirty();
        if (shouldDiscard && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: ShellScaffold(
        title: 'Personal Information',
        showBack: true,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  onChanged: () => setState(() => _dirty = true),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(
                        controller: _firstName,
                        label: 'First Name',
                        validator: Validators.required,
                      ),
                      AppTextField(
                        controller: _lastName,
                        label: 'Last Name',
                        validator: Validators.required,
                      ),
                      AppTextField(
                        controller: _email,
                        label: 'Email',
                        validator: Validators.email,
                      ),
                      AppTextField(
                        controller: _phone,
                        label: 'Phone',
                        keyboardType: TextInputType.phone,
                        validator: Validators.phone,
                      ),
                      AppTextField(
                        controller: _dob,
                        label: 'Date of Birth',
                        hint: 'YYYY-MM-DD',
                        validator: Validators.required,
                      ),
                      AppTextField(
                        controller: _gender,
                        label: 'Gender (optional)',
                      ),
                      AppTextField(
                        controller: _height,
                        label: 'Height (cm)',
                        keyboardType: TextInputType.number,
                      ),
                      AppTextField(
                        controller: _weight,
                        label: 'Weight (kg)',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                if (await _confirmDiscardIfDirty()) {
                                  if (context.mounted) Navigator.pop(context);
                                }
                              },
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppPalette.primary,
                              ),
                              onPressed: () async {
                                final session = SessionScope.of(context);
                                if (_formKey.currentState?.validate() != true) {
                                  return;
                                }
                                final updated = _profile.copyWith(
                                  firstName: _firstName.text.trim(),
                                  lastName: _lastName.text.trim(),
                                  email: _email.text.trim(),
                                  phone: _phone.text.trim(),
                                  dob: _dob.text.trim(),
                                  gender: _gender.text.trim(),
                                  heightCm: _height.text.trim(),
                                  weightKg: _weight.text.trim(),
                                  displayName:
                                      '${_firstName.text.trim()} ${_lastName.text.trim()}'
                                          .trim(),
                                );
                                await LocalProfileStore.save(updated);
                                await session.syncProfileNow();
                                await session.refreshMeAndDashboard();
                                setState(() => _dirty = false);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Personal information saved.',
                                    ),
                                  ),
                                );
                                Navigator.pop(context);
                              },
                              child: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class ChallengeDetailScreen extends StatefulWidget {
  const ChallengeDetailScreen({super.key, required this.args});

  final ChallengeDetailArgs args;

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  bool _loading = false;
  bool _joining = false;
  ChallengeDetails? _details;
  String? _error;

  @override
  void initState() {
    super.initState();
    _details = ChallengeDetails(
      id: widget.args.id ?? 0,
      clubId: null,
      title: widget.args.title,
      description: widget.args.description,
      type: '',
      targetValue: 0,
      startAt: null,
      endAt: null,
      status: '',
      joined: widget.args.joined,
    );
    if (widget.args.id != null) {
      unawaited(_loadDetails());
    }
  }

  Future<void> _loadDetails() async {
    final challengeId = widget.args.id;
    if (challengeId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final data = await SessionScope.of(
      context,
    ).loadChallengeDetail(challengeId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (data == null) {
        _error =
            SessionScope.of(context).lastError ??
            'Could not load challenge details';
      } else {
        _details = data;
      }
    });
  }

  Future<void> _joinChallenge() async {
    final challengeId = widget.args.id;
    if (challengeId == null || _joining || (_details?.joined ?? false)) {
      return;
    }
    setState(() => _joining = true);
    final session = SessionScope.of(context);
    final ok = await session.joinChallenge(challengeId);
    if (!mounted) return;
    setState(() => _joining = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(session.lastError ?? 'Could not join challenge'),
        ),
      );
      return;
    }
    setState(() {
      final current = _details;
      if (current != null) {
        _details = ChallengeDetails(
          id: current.id,
          clubId: current.clubId,
          title: current.title,
          description: current.description,
          type: current.type,
          targetValue: current.targetValue,
          startAt: current.startAt,
          endAt: current.endAt,
          status: current.status,
          joined: true,
        );
      }
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Challenge joined.')));
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    final joined = details?.joined ?? widget.args.joined;
    return ShellScaffold(
      title: details?.title ?? widget.args.title,
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              ),
            Text(
              details?.title ?? widget.args.title,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              details?.description.isNotEmpty == true
                  ? details!.description
                  : widget.args.description.isNotEmpty
                  ? widget.args.description
                  : 'Challenge details',
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _detailChip(
                  'Status',
                  (details?.status.isNotEmpty ?? false)
                      ? details!.status
                      : 'active',
                ),
                _detailChip(
                  'Type',
                  (details?.type.isNotEmpty ?? false) ? details!.type : 'run',
                ),
                _detailChip(
                  'Target',
                  details != null && details.targetValue > 0
                      ? details.targetValue.toStringAsFixed(0)
                      : '--',
                ),
                _detailChip('Starts', _formatChallengeDate(details?.startAt)),
                _detailChip('Ends', _formatChallengeDate(details?.endAt)),
              ],
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: joined
                    ? const Color(0xFF5A5F77)
                    : AppPalette.primary,
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: joined ? null : _joinChallenge,
              child: Text(
                _joining
                    ? 'Joining...'
                    : joined
                    ? 'Joined'
                    : 'Join Challenge',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  String _formatChallengeDate(DateTime? value) {
    if (value == null) return '--';
    final d = value.toLocal();
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$month-$day';
  }
}

class ClubDetailScreen extends StatefulWidget {
  const ClubDetailScreen({super.key, required this.args});

  final ClubDetailArgs args;

  @override
  State<ClubDetailScreen> createState() => _ClubDetailScreenState();
}

class _ClubDetailScreenState extends State<ClubDetailScreen> {
  late bool _joined;
  bool _joining = false;
  bool _loading = false;
  ClubDetails? _details;
  String? _error;

  @override
  void initState() {
    super.initState();
    _joined = widget.args.joined;
    _details = ClubDetails(
      id: widget.args.id ?? 0,
      name: widget.args.name,
      description: widget.args.description,
      memberCount: widget.args.memberCount,
      joined: widget.args.joined,
      createdAt: null,
    );
    if (widget.args.id != null) {
      unawaited(_loadDetails());
    }
  }

  Future<void> _loadDetails() async {
    final clubId = widget.args.id;
    if (clubId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final session = SessionScope.of(context);
    final data = await session.loadClubDetail(clubId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (data == null) {
        _error = session.lastError ?? 'Could not load club details';
      } else {
        _details = data;
        _joined = data.joined;
      }
    });
  }

  Future<void> _joinClub() async {
    final clubId = widget.args.id;
    if (clubId == null || _joining || _joined) return;
    setState(() => _joining = true);
    final session = SessionScope.of(context);
    final ok = await session.joinClub(clubId);
    if (!mounted) return;
    setState(() {
      _joining = false;
      if (ok) {
        _joined = true;
        final current = _details;
        if (current != null) {
          _details = ClubDetails(
            id: current.id,
            name: current.name,
            description: current.description,
            memberCount: current.memberCount,
            joined: true,
            createdAt: current.createdAt,
          );
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Club joined.' : (session.lastError ?? 'Could not join club'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    final title = details?.name ?? widget.args.name;
    final description = details?.description ?? widget.args.description;
    final memberCount = details?.memberCount ?? widget.args.memberCount;
    return ShellScaffold(
      title: title,
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              ),
            Text(
              title,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(description.isNotEmpty ? description : 'Local running club'),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _clubChip('Members', '$memberCount'),
                _clubChip('Status', _joined ? 'joined' : 'not joined'),
                _clubChip('Created', _formatDate(details?.createdAt)),
              ],
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _joined
                    ? const Color(0xFF5A5F77)
                    : AppPalette.primary,
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: _joined ? null : _joinClub,
              child: Text(
                _joining
                    ? 'Joining...'
                    : _joined
                    ? 'Joined'
                    : 'Join Club',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _clubChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '--';
    final d = value.toLocal();
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$month-$day';
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _dirty = false;
  bool _loading = true;
  ProfileData _profile = ProfileData.defaults;

  final _displayName = TextEditingController();
  final _username = TextEditingController();
  final _location = TextEditingController();
  final _bio = TextEditingController();
  final _occupation = TextEditingController();
  final _website = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await LocalProfileStore.load();
    if (!mounted) return;
    _profile = profile;
    _displayName.text = profile.displayName;
    _username.text = profile.username;
    _location.text = profile.location;
    _bio.text = profile.bio;
    _occupation.text = profile.occupation;
    _website.text = profile.website;
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _displayName.dispose();
    _username.dispose();
    _location.dispose();
    _bio.dispose();
    _occupation.dispose();
    _website.dispose();
    super.dispose();
  }

  Future<bool> _confirmDiscardIfDirty() async {
    if (!_dirty) return true;
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved profile changes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.primary),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return shouldDiscard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldDiscard = await _confirmDiscardIfDirty();
        if (shouldDiscard && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: ShellScaffold(
        title: 'Edit Profile',
        showBack: true,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  onChanged: () => setState(() => _dirty = true),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundColor: const Color(0xFFDCE3FF),
                        backgroundImage: _profile.avatarUrl.isNotEmpty
                            ? NetworkImage(_profile.avatarUrl)
                            : null,
                        child: _profile.avatarUrl.isEmpty
                            ? const Icon(
                                Icons.person,
                                color: AppPalette.primary,
                                size: 34,
                              )
                            : null,
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () async {
                          final picker = ImagePicker();
                          final source = await showModalBottomSheet<ImageSource>(
                            context: context,
                            builder: (context) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.camera_alt_outlined),
                                    title: const Text('Take Photo'),
                                    onTap: () => Navigator.pop(
                                      context,
                                      ImageSource.camera,
                                    ),
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.photo_library_outlined),
                                    title: const Text('Choose from Gallery'),
                                    onTap: () => Navigator.pop(
                                      context,
                                      ImageSource.gallery,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                          if (source == null) return;
                          final picked = await picker.pickImage(
                            source: source,
                            maxWidth: 1200,
                            imageQuality: 85,
                          );
                          if (picked == null || !context.mounted) return;
                          final avatarUrl = await SessionScope.of(
                            context,
                          ).uploadProfilePhoto(picked);
                          if (!context.mounted) return;
                          if (avatarUrl == null || avatarUrl.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  SessionScope.of(context).lastError ??
                                      'Photo upload failed',
                                ),
                              ),
                            );
                            return;
                          }
                          setState(() {
                            _profile = _profile.copyWith(avatarUrl: avatarUrl);
                            _dirty = true;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                source == ImageSource.camera
                                    ? 'Photo captured and uploaded.'
                                    : 'Photo uploaded.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Change Photo'),
                      ),
                      const SizedBox(height: 10),
                      AppTextField(
                        controller: _displayName,
                        label: 'Display Name',
                        validator: Validators.required,
                      ),
                      AppTextField(
                        controller: _username,
                        label: 'Username',
                        validator: Validators.required,
                      ),
                      AppTextField(
                        controller: _occupation,
                        label: 'Occupation',
                      ),
                      AppTextField(controller: _location, label: 'Location'),
                      AppTextField(controller: _bio, label: 'Bio'),
                      AppTextField(
                        controller: _website,
                        label: 'Website (optional)',
                        hint: 'https://',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                if (await _confirmDiscardIfDirty()) {
                                  if (context.mounted) Navigator.pop(context);
                                }
                              },
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppPalette.primary,
                              ),
                              onPressed: () async {
                                final session = SessionScope.of(context);
                                if (_formKey.currentState?.validate() != true) {
                                  return;
                                }
                                final updated = _profile.copyWith(
                                  displayName: _displayName.text.trim(),
                                  username: _username.text.trim(),
                                  occupation: _occupation.text.trim(),
                                  location: _location.text.trim(),
                                  bio: _bio.text.trim(),
                                  website: _website.text.trim(),
                                );
                                await LocalProfileStore.save(updated);
                                await session.syncProfileNow();
                                await session.refreshMeAndDashboard();
                                setState(() => _dirty = false);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Profile updated successfully.',
                                    ),
                                  ),
                                );
                                Navigator.pop(context);
                              },
                              child: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ShellScaffold(
      title: 'Privacy Settings',
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SwitchSettingTile(
            icon: Icons.public_off_outlined,
            title: 'Private Profile',
            subtitle: 'Only approved followers can view your profile.',
            initialValue: false,
          ),
          _SwitchSettingTile(
            icon: Icons.location_off_outlined,
            title: 'Hide Live Location',
            subtitle: 'Do not share location while running.',
            initialValue: true,
          ),
          _SwitchSettingTile(
            icon: Icons.visibility_off_outlined,
            title: 'Hide Activity Details',
            subtitle: 'Show only distance totals to others.',
            initialValue: false,
          ),
        ],
      ),
    );
  }
}

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ShellScaffold(
      title: 'Settings',
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SwitchSettingTile(
            icon: Icons.notifications_active_outlined,
            title: 'Push Notifications',
            subtitle: 'Workout reminders and app alerts.',
            initialValue: true,
          ),
          const _SwitchSettingTile(
            icon: Icons.email_outlined,
            title: 'Email Updates',
            subtitle: 'Weekly reports and announcements.',
            initialValue: false,
          ),
          const _SwitchSettingTile(
            icon: Icons.flag_outlined,
            title: 'Challenge Alerts',
            subtitle: 'Progress and invite notifications.',
            initialValue: true,
          ),
          const SizedBox(height: 10),
          ActionTile(
            title: 'Edit Profile',
            onTap: () => Navigator.pushNamed(context, AppRoutes.editProfile),
          ),
          ActionTile(
            title: 'Personal Information',
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.profileSettings),
          ),
          ActionTile(
            title: 'Privacy Settings',
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.privacySettings),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.primary,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () async {
              await SessionScope.of(context).logout();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout),
            label: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}

class _RouteMapPreview extends StatelessWidget {
  const _RouteMapPreview({required this.points});

  final List<RoutePoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(child: Text('No route data available'));
    }

    final latLngPoints = points
        .map((p) => latlong.LatLng(p.lat, p.lng))
        .toList();
    final center = _estimateCenter(latLngPoints);
    final zoom = _estimateZoom(latLngPoints);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: FlutterMap(
        options: MapOptions(initialCenter: center, initialZoom: zoom),
        children: [
          TileLayer(
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
            userAgentPackageName: 'com.example.labapp',
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: latLngPoints,
                color: Colors.blue,
                strokeWidth: 7,
                strokeCap: StrokeCap.round,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: latLngPoints.first,
                width: 28,
                height: 28,
                child: const Icon(
                  Icons.radio_button_checked,
                  color: Colors.green,
                  size: 22,
                ),
              ),
              Marker(
                point: latLngPoints.last,
                width: 28,
                height: 28,
                child: const Icon(
                  Icons.flag_circle,
                  color: Colors.red,
                  size: 22,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  latlong.LatLng _estimateCenter(List<latlong.LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    return latlong.LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
  }

  double _estimateZoom(List<latlong.LatLng> points) {
    if (points.length < 2) return 16;
    final lats = points.map((p) => p.latitude).toList();
    final lngs = points.map((p) => p.longitude).toList();
    final latSpan = (lats.reduce(math.max) - lats.reduce(math.min)).abs();
    final lngSpan = (lngs.reduce(math.max) - lngs.reduce(math.min)).abs();
    final span = math.max(latSpan, lngSpan);
    if (span <= 0.001) return 16;
    if (span <= 0.003) return 15;
    if (span <= 0.008) return 14;
    if (span <= 0.015) return 13;
    if (span <= 0.03) return 12;
    if (span <= 0.06) return 11;
    return 10;
  }
}

class _SwitchSettingTile extends StatefulWidget {
  const _SwitchSettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.initialValue,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool initialValue;

  @override
  State<_SwitchSettingTile> createState() => _SwitchSettingTileState();
}

class _SwitchSettingTileState extends State<_SwitchSettingTile> {
  late bool _enabled = widget.initialValue;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF7F8FF),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(widget.icon, color: AppPalette.primary),
        title: Text(widget.title),
        subtitle: Text(widget.subtitle),
        trailing: Switch(
          value: _enabled,
          onChanged: (value) => setState(() => _enabled = value),
        ),
      ),
    );
  }
}
