part of '../../main.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.onOpenRecords});

  final VoidCallback onOpenRecords;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  static const _dayWindowBefore = 15;
  static const _dayWindowAfter = 15;
  late int _selectedDay;
  late final ScrollController _dayController;
  bool _didRefresh = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _dayWindowBefore;
    _dayController = ScrollController(
      initialScrollOffset: (_selectedDay * 64).toDouble(),
    );
  }

  @override
  void dispose() {
    _dayController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didRefresh) return;
    _didRefresh = true;
    unawaited(SessionScope.of(context).refreshMeAndDashboard());
  }

  @override
  Widget build(BuildContext context) {
    final days = _buildCurrentWeekDays();
    final session = SessionScope.of(context);
    final firstName = session.profile.firstName.trim().isNotEmpty
        ? session.profile.firstName.trim()
        : 'Runner';
    final dashboard = session.dashboard;
    final recentActivities = dashboard.recentWorkouts
        .map(
          (w) => _ActivityItem(
            title: w.category.isNotEmpty ? w.category : 'Workout',
            date: _formatDate(w.startedAt),
            distance: '${(w.distanceM / 1000).toStringAsFixed(2)} km',
          ),
        )
        .toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Color(0xFFE4EAFF),
                  backgroundImage: session.profile.avatarUrl.isNotEmpty
                      ? NetworkImage(session.profile.avatarUrl)
                      : null,
                  child: session.profile.avatarUrl.isEmpty
                      ? const Icon(Icons.person, color: AppPalette.primary)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome back',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      Text(
                        firstName,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
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
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 66,
              child: ListView.separated(
                controller: _dayController,
                scrollDirection: Axis.horizontal,
                itemCount: days.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final item = days[index];
                  final selected = _selectedDay == index;
                  return InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => setState(() => _selectedDay = index),
                    child: Container(
                      width: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: selected
                            ? AppPalette.primary
                            : const Color(0xFFF3F5FE),
                        border: Border.all(
                          color: selected
                              ? AppPalette.primary
                              : const Color(0xFFDCE2F7),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.white : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.date,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: selected ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Your Progress',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ProgressCard(
                    title: 'Distance',
                    value: '${dashboard.totalDistanceKm.toStringAsFixed(1)} km',
                    subtitle: '${dashboard.workoutsCount} workouts completed',
                    icon: Icons.straighten,
                    height: 212,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      _ProgressCard(
                        title: 'Top Performance',
                        value:
                            '${dashboard.weeklyDistanceKm.toStringAsFixed(1)} km',
                        subtitle: 'Last 7 days',
                        icon: Icons.workspace_premium_outlined,
                        compact: true,
                      ),
                      SizedBox(height: 12),
                      _ProgressCard(
                        title: 'Weekly Pace',
                        value: _formatPace(dashboard.weeklyAvgPaceSecPerKm),
                        subtitle: 'Average this week',
                        icon: Icons.speed_outlined,
                        compact: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Text(
                  'Recent Activity',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                TextButton(
                  onPressed: widget.onOpenRecords,
                  child: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < recentActivities.length; i++) ...[
              _ActivityTile(
                activity: recentActivities[i],
                selected: i == 0,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.workoutSummary,
                  arguments: WorkoutSummaryArgs(
                    originTab: AppTab.home,
                    workout: dashboard.recentWorkouts[i],
                  ),
                ),
              ),
              if (i != recentActivities.length - 1) const SizedBox(height: 10),
            ],
            if (recentActivities.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'No workouts yet. Start your first run from Record.',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
          ],
        ),
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

  String _formatDate(DateTime? dt) {
    if (dt == null) return '--/--/----';
    final d = dt.toLocal();
    return '${d.day}/${d.month}/${d.year}';
  }

  List<_DayItem> _buildCurrentWeekDays() {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: _dayWindowBefore));
    return List.generate(_dayWindowBefore + _dayWindowAfter + 1, (index) {
      final date = start.add(Duration(days: index));
      return _DayItem(label: _weekdayLabel(date.weekday), date: '${date.day}');
    });
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      default:
        return 'Sun';
    }
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
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
      height: height ?? 100,
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: compact
            ? MainAxisAlignment.center
            : MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppPalette.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: compact ? 34 * 0.55 : 34,
              fontWeight: FontWeight.w900,
              color: AppPalette.primary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.activity,
    required this.selected,
    required this.onTap,
  });

  final _ActivityItem activity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppPalette.primary : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Color(0xFFDCE3FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.directions_run,
                color: AppPalette.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${activity.title} • ${activity.date}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    activity.distance,
                    style: const TextStyle(
                      fontSize: 34 * 0.4,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppPalette.primary),
              ),
              child: const Icon(
                Icons.arrow_forward,
                size: 18,
                color: AppPalette.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayItem {
  const _DayItem({required this.label, required this.date});

  final String label;
  final String date;
}

class _ActivityItem {
  const _ActivityItem({
    required this.title,
    required this.date,
    required this.distance,
  });

  final String title;
  final String date;
  final String distance;
}
