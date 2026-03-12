part of '../main.dart';

class AppRoutes {
  static const onboarding = '/onboarding';
  static const signup = '/signup';
  static const login = '/login';
  static const forgotPassword = '/forgot_password';
  static const authSuccess = '/auth_success';

  static const home = '/home';
  static const records = '/records';
  static const challengeHub = '/challenge_hub';
  static const community = '/community';
  static const profile = '/profile';

  static const leaderboard = '/leaderboard';
  static const logWorkout = '/log_workout';
  static const workoutSummary = '/workout_summary';
  static const profileSettings = '/profile_settings';
  static const challengeDetail = '/challenge_detail';
  static const clubDetail = '/club_detail';
  static const editProfile = '/edit_profile';
  static const privacySettings = '/privacy_settings';
  static const notificationSettings = '/notification_settings';
}

class AppPalette {
  static const primary = Color(0xFF0D1A63);
}

enum AppTab { home, records, community, profile }

enum LeaderboardFilter { weekly, monthly }

enum WorkoutSessionState { idle, running, paused, completed }

enum ChallengeMembershipState { notJoined, pending, joined }

enum AuthSuccessMode { signup, reset }

class AuthSuccessArgs {
  const AuthSuccessArgs({required this.mode});

  final AuthSuccessMode mode;
}

class LeaderboardArgs {
  const LeaderboardArgs({required this.contextLabel});

  final String contextLabel;
}

class LogWorkoutArgs {
  const LogWorkoutArgs({
    required this.originTab,
    this.workoutId,
    this.routePoints = const [],
    this.elapsedSeconds = 0,
    this.distanceKm = 0,
    this.paceMinutesPerKm = 0,
  });

  final AppTab originTab;
  final int? workoutId;
  final List<RoutePoint> routePoints;
  final int elapsedSeconds;
  final double distanceKm;
  final double paceMinutesPerKm;
}

class WorkoutSummaryArgs {
  const WorkoutSummaryArgs({required this.originTab});

  final AppTab originTab;
}

class ChallengeDetailArgs {
  const ChallengeDetailArgs({
    this.id,
    required this.title,
    this.description = '',
    this.joined = false,
  });

  final int? id;
  final String title;
  final String description;
  final bool joined;
}

class ClubDetailArgs {
  const ClubDetailArgs({
    this.id,
    required this.name,
    this.description = '',
    this.memberCount = 0,
    this.joined = false,
  });

  final int? id;
  final String name;
  final String description;
  final int memberCount;
  final bool joined;
}

class PendingDestination {
  const PendingDestination(this.route, {this.arguments});

  final String route;
  final Object? arguments;
}

class RoutePoint {
  const RoutePoint({required this.lat, required this.lng});

  final double lat;
  final double lng;
}
