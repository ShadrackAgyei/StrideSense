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

const _supabaseUrl = 'https://ymvxdzdyxfgcinwuwckd.supabase.co';
const _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltdnhkemR5eGZnY2lud3V3Y2tkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU1NDc1MjYsImV4cCI6MjA5MTEyMzUyNn0._Ju0QAmuaQYNgtJ2AKiHIT1CVmbjuzu4z7kWvnquAaE';

SupabaseClient get supabase => Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
  runApp(const StrideSenseApp());
}
