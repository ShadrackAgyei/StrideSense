import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

part 'navigation/app_core.dart';
part 'navigation/app_routes.dart';
part 'session/session.dart';
part 'widgets/shared.dart';
part 'features/auth/auth_screens.dart';
part 'features/shell/main_shell.dart';
part 'features/tabs/home_tab.dart';
part 'features/tabs/challenges_tab.dart';
part 'features/tabs/community_tab.dart';
part 'features/tabs/profile_tab.dart';
part 'features/details/detail_screens.dart';

const _supabaseUrl = 'https://wbqfjhrenpcflvfevqdy.supabase.co';
const _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndicWZqaHJlbnBjZmx2ZmV2cWR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYyNzExNjcsImV4cCI6MjA5MTg0NzE2N30.tnSzE6fS5r6__3wYX58uhMOQCDL2uLtiUEMmboCuBDs';

SupabaseClient get supabase => Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
  await NotificationService.init();
  runApp(const StrideSenseApp());
}
