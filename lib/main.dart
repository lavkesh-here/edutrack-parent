import 'dart:async';
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
      // Clamp system font scale to 1.2× max — prevents layout overflow for
      // parents using larger accessibility font sizes.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 1.0,
              maxScaleFactor: 1.2,
            ),
          ),
          child: child!,
        );
      },
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

class _RootState extends State<_Root> with WidgetsBindingObserver {
  DateTime? _pausedAt;
  Timer? _inactivityTimer;
  ParentAuthProvider? _authRef;
  static const _inactivityDuration = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupFcm();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _authRef = context.read<ParentAuthProvider>();
      _authRef!.addListener(_handleAuthChange);
      _handleAuthChange();
    });
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _authRef?.removeListener(_handleAuthChange);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handleAuthChange() {
    if (!mounted || _authRef == null) return;
    if (_authRef!.isLoggedIn && !_authRef!.isLocked) {
      _resetInactivityTimer();
    } else {
      _inactivityTimer?.cancel();
    }
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityDuration, _onInactivity);
  }

  Future<void> _onInactivity() async {
    if (!mounted || _authRef == null) return;
    if (_authRef!.isLoggedIn && !_authRef!.isLocked && await _authRef!.isBiometricEnabled) {
      _authRef!.lockApp();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _checkAppLock();
    }
  }

  Future<void> _checkAppLock() async {
    if (_pausedAt == null || !mounted) return;
    final elapsed = DateTime.now().difference(_pausedAt!);
    _pausedAt = null;
    final auth = context.read<ParentAuthProvider>();
    if (!auth.isLoggedIn) return;
    if (elapsed.inSeconds >= 60 && await auth.isBiometricEnabled) {
      auth.lockApp();
    }
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
      final prefs = await SharedPreferences.getInstance();
      var deviceId = prefs.getString('push_device_id');
      if (deviceId == null) {
        deviceId = '${Platform.operatingSystem}_${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString('push_device_id', deviceId);
      }
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
    final date = message.data['date'] as String?;
    if (!mounted) return;
    context.read<ParentAuthProvider>().setPendingNavigation(type, studentId, date: date);
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

    if (!auth.isLoggedIn) return const LoginScreen();

    final home = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetInactivityTimer(),
      child: const HomeScreen(),
    );

    if (!auth.isLocked) return home;

    return Stack(
      children: [
        IgnorePointer(child: home),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(color: Colors.black.withOpacity(0.35)),
        ),
        const _BiometricLockScreen(),
      ],
    );
  }
}

// ── Biometric lock screen ─────────────────────────────────────────────────────

class _BiometricLockScreen extends StatefulWidget {
  const _BiometricLockScreen();

  @override
  State<_BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<_BiometricLockScreen> {
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    final auth = context.read<ParentAuthProvider>();
    final err = await auth.unlockApp();
    if (!mounted) return;
    setState(() { _loading = false; _error = err; });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF14B8A6).withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(child: Text('👨‍👩‍👧', style: TextStyle(fontSize: 34))),
                ),
                const SizedBox(height: 24),
                const Text(
                  'EduTrack is locked',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1C1917)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use your fingerprint or face to continue',
                  style: TextStyle(fontSize: 14, color: Color(0xFF78716C)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDA4AF)),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(fontSize: 13, color: Color(0xFFBE123C), fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _unlock,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Icon(Icons.fingerprint_rounded, size: 22),
                    label: Text(_loading ? 'Verifying…' : 'Unlock'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14B8A6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}
