part of '../../main.dart';

class CommunityTab extends StatefulWidget {
  const CommunityTab({super.key});

  @override
  State<CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends State<CommunityTab> {
  bool _loading = true;
  List<ChallengeSummary> _challenges = const [];
  List<ClubSummary> _clubs = const [];
  List<CommunityMember> _members = const [];
  bool _didLoad = false;
  bool _wasAuthenticated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = SessionScope.of(context);
    if (!_didLoad) {
      _didLoad = true;
      _wasAuthenticated = session.isAuthenticated;
      unawaited(_loadData());
    } else if (session.isAuthenticated && !_wasAuthenticated) {
      _wasAuthenticated = true;
      unawaited(_loadData());
    }
  }

  Future<void> _loadData() async {
    final session = SessionScope.of(context);
    final results = await Future.wait([
      session.loadChallenges(),
      session.loadClubs(),
      session.loadCommunityMembers(),
    ]);
    if (!mounted) return;
    setState(() {
      _challenges = results[0] as List<ChallengeSummary>;
      _clubs = results[1] as List<ClubSummary>;
      _members = results[2] as List<CommunityMember>;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ShellScaffold(
      title: 'Community',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Community Hub',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Discover rankings, challenges, and club activity.',
            style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.primary,
                  ),
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.leaderboard,
                    arguments: const LeaderboardArgs(contextLabel: 'Club'),
                  ),
                  icon: const Icon(Icons.emoji_events_outlined),
                  label: const Text('Leaderboard'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.primary,
                  ),
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.challengeHub),
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Challenges'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F5FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: StatCell(value: '${_clubs.length}', label: 'Clubs'),
                ),
                Expanded(
                  child: StatCell(
                    value: '${_challenges.length}',
                    label: 'Events',
                  ),
                ),
                Expanded(
                  child: StatCell(
                    value: '${_challenges.where((c) => c.joined).length}',
                    label: 'Joined',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Trending Challenges',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (!_loading && _challenges.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: _CommunityItem(
                icon: Icons.flag_outlined,
                title: 'No active challenges right now',
                subtitle: 'Check back later',
              ),
            ),
          if (!_loading)
            for (var i = 0; i < _challenges.length && i < 3; i++) ...[
              const SizedBox(height: 8),
              _CommunityItem(
                icon: Icons.directions_run,
                title: _challenges[i].title,
                subtitle: _challenges[i].description.isNotEmpty
                    ? _challenges[i].description
                    : 'Status: ${_challenges[i].status}',
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.challengeDetail,
                  arguments: ChallengeDetailArgs(
                    id: _challenges[i].id,
                    title: _challenges[i].title,
                    description: _challenges[i].description,
                    joined: _challenges[i].joined,
                  ),
                ),
              ),
            ],
          const SizedBox(height: 16),
          const Text(
            'Club Updates',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          if (!_loading) ...[
            const SizedBox(height: 8),
            if (_clubs.isEmpty)
              const _CommunityItem(
                icon: Icons.groups_outlined,
                title: 'No club updates yet',
                subtitle: 'Join or create a club to get updates',
              ),
            for (var i = 0; i < _clubs.length && i < 3; i++) ...[
              _CommunityItem(
                icon: Icons.groups_outlined,
                title: _clubs[i].name,
                subtitle: '${_clubs[i].memberCount} members',
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.clubDetail,
                  arguments: ClubDetailArgs(
                    id: _clubs[i].id,
                    name: _clubs[i].name,
                    description: _clubs[i].description,
                    memberCount: _clubs[i].memberCount,
                    joined: _clubs[i].joined,
                  ),
                ),
              ),
              if (i < 2 && i < _clubs.length - 1) const SizedBox(height: 8),
            ],
          ],
          const SizedBox(height: 16),
          const Text(
            'Members',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (!_loading && _members.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: _CommunityItem(
                icon: Icons.person_outline,
                title: 'No members yet',
                subtitle: 'Be the first to join!',
              ),
            ),
          if (!_loading)
            for (var i = 0; i < _members.length; i++) ...[
              const SizedBox(height: 8),
              _MemberTile(member: _members[i]),
            ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});

  final CommunityMember member;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E7F8)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFDCE3FF),
            backgroundImage: member.avatarUrl.isNotEmpty
                ? NetworkImage(member.avatarUrl)
                : null,
            child: member.avatarUrl.isEmpty
                ? const Icon(Icons.person, color: AppPalette.primary, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Text(
            member.displayName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _CommunityItem extends StatelessWidget {
  const _CommunityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE3E7F8)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFDCE3FF),
                child: Icon(icon, color: AppPalette.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
