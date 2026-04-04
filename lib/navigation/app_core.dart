part of '../main.dart';

class StrideSenseApp extends StatefulWidget {
  const StrideSenseApp({super.key});

  @override
  State<StrideSenseApp> createState() => _StrideSenseAppState();
}

class _StrideSenseAppState extends State<StrideSenseApp> {
  final SessionController _session = SessionController();

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      controller: _session,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'StrideSense',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
          colorScheme: ColorScheme.fromSeed(seedColor: AppPalette.primary),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFCCCCCC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppPalette.primary, width: 1.5),
            ),
          ),
        ),
        initialRoute: AppRoutes.onboarding,
        onGenerateRoute: _onGenerateRoute,
        onUnknownRoute: (_) => _materialRoute(
          const MainShell(initialTab: AppTab.home),
          const RouteSettings(name: AppRoutes.home),
        ),
      ),
    );
  }

  MaterialPageRoute<dynamic> _materialRoute(
    Widget screen,
    RouteSettings settings,
  ) {
    return MaterialPageRoute(builder: (_) => screen, settings: settings);
  }

  Route<dynamic> _requireAuth(RouteSettings settings, Widget screen) {
    if (_session.isAuthenticated) {
      return _materialRoute(screen, settings);
    }
    _session.setPendingDestination(
      settings.name ?? AppRoutes.home,
      arguments: settings.arguments,
    );
    return _materialRoute(
      const LoginScreen(),
      const RouteSettings(name: AppRoutes.login),
    );
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    final String route = settings.name ?? AppRoutes.onboarding;

    switch (route) {
      case AppRoutes.onboarding:
        return _materialRoute(const OnboardingScreen(), settings);
      case AppRoutes.signup:
        return _materialRoute(const SignupScreen(), settings);
      case AppRoutes.login:
        return _materialRoute(const LoginScreen(), settings);
      case AppRoutes.forgotPassword:
        return _materialRoute(const ForgotPasswordScreen(), settings);
      case AppRoutes.authSuccess:
        return _materialRoute(
          AuthSuccessScreen(
            args: _readArgs<AuthSuccessArgs>(settings.arguments),
          ),
          settings,
        );
      case AppRoutes.home:
        return _requireAuth(settings, const MainShell(initialTab: AppTab.home));
      case AppRoutes.records:
        return _requireAuth(
          settings,
          const MainShell(initialTab: AppTab.records),
        );
      case AppRoutes.challengeHub:
        return _requireAuth(settings, const ChallengesTab(showBack: true));
      case AppRoutes.community:
        return _requireAuth(
          settings,
          const MainShell(initialTab: AppTab.community),
        );
      case AppRoutes.profile:
        return _requireAuth(
          settings,
          const MainShell(initialTab: AppTab.profile),
        );
      case AppRoutes.leaderboard:
        return _requireAuth(
          settings,
          LeaderboardScreen(
            args: _readArgs<LeaderboardArgs>(settings.arguments),
          ),
        );
      case AppRoutes.logWorkout:
        return _requireAuth(
          settings,
          LogWorkoutScreen(args: _readArgs<LogWorkoutArgs>(settings.arguments)),
        );
      case AppRoutes.workoutSummary:
        return _requireAuth(
          settings,
          WorkoutSummaryScreen(
            args: _readArgs<WorkoutSummaryArgs>(settings.arguments),
          ),
        );
      case AppRoutes.profileSettings:
        return _requireAuth(
          settings,
          const PersonalInformationSettingsScreen(),
        );
      case AppRoutes.challengeDetail:
        return _requireAuth(
          settings,
          ChallengeDetailScreen(
            args: _readArgs<ChallengeDetailArgs>(settings.arguments),
          ),
        );
      case AppRoutes.clubDetail:
        return _requireAuth(
          settings,
          ClubDetailScreen(args: _readArgs<ClubDetailArgs>(settings.arguments)),
        );
      case AppRoutes.editProfile:
        return _requireAuth(settings, const EditProfileScreen());
      case AppRoutes.privacySettings:
        return _requireAuth(settings, const PrivacySettingsScreen());
      case AppRoutes.notificationSettings:
        return _requireAuth(settings, const NotificationSettingsScreen());
      default:
        return _materialRoute(
          const MainShell(initialTab: AppTab.home),
          const RouteSettings(name: AppRoutes.home),
        );
    }
  }
}

T _readArgs<T>(Object? raw) {
  if (raw is T) {
    return raw;
  }
  if (T == AuthSuccessArgs) {
    return const AuthSuccessArgs(mode: AuthSuccessMode.signup) as T;
  }
  if (T == LeaderboardArgs) {
    return const LeaderboardArgs(contextLabel: 'Global') as T;
  }
  if (T == LogWorkoutArgs) {
    return const LogWorkoutArgs(originTab: AppTab.home) as T;
  }
  if (T == WorkoutSummaryArgs) {
    return WorkoutSummaryArgs(
      originTab: AppTab.home,
      workout: const WorkoutHistoryItem(
        id: 0,
        status: 'completed',
        startedAt: null,
        distanceM: 0,
        avgPaceSecPerKm: 0,
        category: '',
      ),
    ) as T;
  }
  if (T == ChallengeDetailArgs) {
    return const ChallengeDetailArgs(title: 'Challenge') as T;
  }
  if (T == ClubDetailArgs) {
    return const ClubDetailArgs(name: 'Club') as T;
  }
  throw StateError('Missing arguments for type $T');
}
