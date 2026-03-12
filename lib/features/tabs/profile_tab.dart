part of '../../main.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  ProfileData _profile = ProfileData.defaults;
  DashboardSummary _dashboard = DashboardSummary.defaults;
  int _followingCount = 0;
  int _followersCount = 0;
  bool _loading = true;
  bool _didInit = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    unawaited(_loadProfile());
  }

  Future<void> _loadProfile() async {
    final session = SessionScope.of(context);
    final profile = await LocalProfileStore.load();
    final dashboard = await LocalDashboardStore.load();
    var following = 0;
    if (session.isAuthenticated) {
      final clubs = await session.loadClubs();
      following = clubs.where((club) => club.joined).length;
    }
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _dashboard = dashboard;
      _followingCount = following;
      _followersCount = dashboard.workoutsCount;
      _loading = false;
    });
    unawaited(session.refreshMeAndDashboard());
  }

  Future<void> _openAndRefresh(String route) async {
    await Navigator.pushNamed(context, route);
    if (!mounted) return;
    await _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final displayProfile = session.isAuthenticated ? session.profile : _profile;
    final displayDashboard = session.isAuthenticated
        ? session.dashboard
        : _dashboard;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final displayName = displayProfile.displayName.trim().isNotEmpty
        ? displayProfile.displayName.trim()
        : 'Runner';
    final about = <String>[
      if (displayProfile.occupation.trim().isNotEmpty)
        displayProfile.occupation.trim(),
      if (displayProfile.username.trim().isNotEmpty)
        '@${displayProfile.username.trim()}',
      if (displayProfile.bio.trim().isNotEmpty) displayProfile.bio.trim(),
    ].join('\n');

    return ShellScaffold(
      title: 'Profile',
      trailing: IconButton(
        onPressed: () =>
            Navigator.pushNamed(context, AppRoutes.notificationSettings),
        icon: const Icon(Icons.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFDCE2F6)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: const Color(0xFFDCE3FF),
                      backgroundImage: displayProfile.avatarUrl.isNotEmpty
                          ? NetworkImage(displayProfile.avatarUrl)
                          : null,
                      child: displayProfile.avatarUrl.isEmpty
                          ? const Icon(Icons.person, color: AppPalette.primary)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 2),
                          if (displayProfile.location.trim().isNotEmpty)
                            Text(
                              displayProfile.location.trim(),
                              style: TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (about.isNotEmpty) ...[
                            SizedBox(height: 8),
                            Text(
                              about,
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        _FollowStat(
                          value: _followingCount.toString(),
                          label: 'Following',
                        ),
                        const SizedBox(height: 10),
                        _FollowStat(
                          value: _followersCount.toString(),
                          label: 'Followers',
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _openAndRefresh(AppRoutes.editProfile),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppPalette.primary),
                        ),
                        child: const Text(
                          'Edit Profile',
                          style: TextStyle(color: AppPalette.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            _openAndRefresh(AppRoutes.profileSettings),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppPalette.primary),
                        ),
                        child: const Text(
                          'Personal Info',
                          style: TextStyle(color: AppPalette.primary),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Your Progress',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _ProfileMetricCard(
                      title: 'Distance',
                      value:
                          '${displayDashboard.totalDistanceKm.toStringAsFixed(2)} km',
                      subtitle: '${displayDashboard.workoutsCount} workouts',
                      icon: Icons.straighten,
                      height: 220,
                    ),
                    const SizedBox(height: 12),
                    _ProfileMetricCard(
                      title: 'Weekly Pace',
                      value: _formatPace(
                        displayDashboard.weeklyAvgPaceSecPerKm,
                      ),
                      subtitle: 'Steady pacing',
                      icon: Icons.speed_outlined,
                      compact: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    _ProfileMetricCard(
                      title: 'Top Performance',
                      value:
                          '${displayDashboard.weeklyDistanceKm.toStringAsFixed(2)} km',
                      subtitle: 'Last 7 days',
                      icon: Icons.workspace_premium_outlined,
                      compact: true,
                    ),
                    SizedBox(height: 12),
                    _ProfileMetricCard(
                      title: 'Calories',
                      value:
                          '${(displayDashboard.weeklyDistanceKm * 62).round()} kcal',
                      subtitle: 'Estimated weekly burn',
                      icon: Icons.local_fire_department_outlined,
                      height: 220,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'This Week',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Container(
            height: 220,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDDE3FA)),
            ),
            child: _WeeklyDistanceChart(
              values: _buildWeeklySeries(displayDashboard.recentWorkouts),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPace(double secPerKm) {
    if (secPerKm <= 0) return '--:-- /km';
    final total = secPerKm.round();
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s /km';
  }

  List<double> _buildWeeklySeries(List<WorkoutHistoryItem> workouts) {
    if (workouts.isEmpty) return [0, 0, 0, 0, 0, 0, 0];
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 6));
    final bins = List<double>.filled(7, 0);
    for (final workout in workouts) {
      final t = workout.startedAt?.toLocal();
      if (t == null) continue;
      final day = DateTime(t.year, t.month, t.day);
      final idx = day
          .difference(DateTime(start.year, start.month, start.day))
          .inDays;
      if (idx < 0 || idx > 6) continue;
      bins[idx] += workout.distanceM / 1000;
    }
    return bins;
  }
}

class _FollowStat extends StatelessWidget {
  const _FollowStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        Text(label, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}

class _ProfileMetricCard extends StatelessWidget {
  const _ProfileMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.compact = false,
    this.height,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final bool compact;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height ?? (compact ? 112 : 160),
      padding: EdgeInsets.all(compact ? 12 : 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppPalette.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: compact ? 30 * 0.62 : 48,
              fontWeight: FontWeight.w900,
              color: AppPalette.primary,
              height: 1.05,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyDistanceChart extends StatelessWidget {
  const _WeeklyDistanceChart({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WeeklyChartPainter(values),
      child: const SizedBox.expand(),
    );
  }
}

class _WeeklyChartPainter extends CustomPainter {
  _WeeklyChartPainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    const maxY = 10.0;
    const minY = 0.0;
    final chartWidth = size.width;
    final chartHeight = size.height;

    final gridPaint = Paint()
      ..color = const Color(0xFFD5DCF4)
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = AppPalette.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final fillPaint = Paint()
      ..color = AppPalette.primary.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    final dotPaint = Paint()..color = AppPalette.primary;

    for (var i = 0; i <= 4; i++) {
      final y = chartHeight * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);
    }

    if (values.isEmpty) return;

    final dx = values.length == 1 ? 0.0 : chartWidth / (values.length - 1);
    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < values.length; i++) {
      final x = dx * i;
      final normalized = ((values[i] - minY) / (maxY - minY)).clamp(0.0, 1.0);
      final y = chartHeight - (normalized * chartHeight);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, chartHeight);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
    }

    fillPath
      ..lineTo(chartWidth, chartHeight)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    final labelStyle = const TextStyle(
      color: Colors.black54,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );
    final weekLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    for (var i = 0; i < weekLabels.length && i < values.length; i++) {
      final span = TextSpan(text: weekLabels[i], style: labelStyle);
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr)
        ..layout();
      final x = dx * i - tp.width / 2;
      tp.paint(
        canvas,
        Offset(x.clamp(0, chartWidth - tp.width), chartHeight - 16),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyChartPainter oldDelegate) =>
      oldDelegate.values != values;
}
