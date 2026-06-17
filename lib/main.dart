import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/auth.dart';
import 'core/api.dart';
import 'core/theme.dart';
import 'screens/login.dart';
import 'screens/home.dart';
import 'screens/force_change_password.dart';

// Background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (requires google-services.json on Android,
  // GoogleService-Info.plist on iOS — download from Firebase Console)
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    // Catch Flutter framework errors (widget build failures, etc.)
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    // Catch Dart async errors outside Flutter (Future.error, isolate errors)
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (_) {
    // Firebase not configured yet — Crashlytics unavailable, app runs normally
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ParentAuthProvider(),
      child: const EduTrackParentApp(),
    ),
  );
}

class EduTrackParentApp extends StatelessWidget {
  const EduTrackParentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduTrack Parent',
      theme: buildTheme(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/force-change-password': (_) => const ForceChangePasswordScreen(),
      },
      home: const _Root(),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  @override
  void initState() {
    super.initState();
    _setupFcm();
  }

  Future<void> _setupFcm() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Request permission (iOS requires this; Android 13+ also needs it)
      await messaging.requestPermission(
        alert: true, badge: true, sound: true,
      );

      // Register token with backend when logged in
      final token = await messaging.getToken();
      if (token != null) {
        await _registerToken(token);
      }

      // Re-register on token refresh
      messaging.onTokenRefresh.listen(_registerToken);

      // Foreground messages — show a SnackBar / navigate
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Tap on notification when app is in background (not terminated)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Tap when app was terminated
      final initial = await messaging.getInitialMessage();
      if (initial != null) _handleNotificationTap(initial);
    } catch (_) {
      // Firebase not configured; skip silently
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      // Use platform + timestamp as stable device ID
      final deviceId = '${Platform.operatingSystem}_${DateTime.now().millisecondsSinceEpoch ~/ 86400000}';
      await ParentApiClient.registerPushToken(token, deviceId);
    } catch (_) {}
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    if (!mounted || title.isEmpty) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (body.isNotEmpty) Text(body, style: const TextStyle(fontSize: 12)),
          ],
        ),
        duration: const Duration(seconds: 4),
        backgroundColor: const Color(0xFF14B8A6),
      ),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Store pending navigation in auth provider; HomeScreen reads and handles it after loading children.
    final type = message.data['type'] as String? ?? '';
    final studentId = message.data['student_id'] as String?;
    if (!mounted) return;
    context.read<ParentAuthProvider>().setPendingNavigation(type, studentId);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ParentAuthProvider>();
    if (auth.loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFF8F3),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('👨‍👩‍👧', style: TextStyle(fontSize: 48)),
              SizedBox(height: 16),
              CircularProgressIndicator(color: Color(0xFF14B8A6)),
            ],
          ),
        ),
      );
    }
    // Set Crashlytics user context when logged in
    if (auth.isLoggedIn && auth.user != null) {
      try {
        FirebaseCrashlytics.instance.setUserIdentifier('parent_${auth.user!.parentId}');
      } catch (_) {}
    }

    return auth.isLoggedIn ? const HomeScreen() : const LoginScreen();
  }
}
