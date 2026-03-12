part of '../../main.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.initialTab});

  final AppTab initialTab;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late AppTab _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _tab = widget.initialTab;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeTab(onOpenRecords: () => setState(() => _tab = AppTab.records)),
      const RecordTab(),
      const CommunityTab(),
      const ProfileTab(),
    ];

    return Scaffold(
      body: IndexedStack(index: _tab.index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        indicatorColor: AppPalette.primary.withValues(alpha: 0.12),
        onDestinationSelected: (index) =>
            setState(() => _tab = AppTab.values[index]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Record',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Community',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
