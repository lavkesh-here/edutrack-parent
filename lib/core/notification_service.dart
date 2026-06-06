import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static const _tokenKey = 'fcm_token_registered';

  static Future<void> init() async {
    // Placeholder: FCM token registration requires firebase_messaging + google-services.json.
    // Wire in when Firebase is configured:
    // final token = await FirebaseMessaging.instance.getToken();
    // if (token != null) {
    //   await ParentApiClient.registerPushToken(token, deviceId);
    // }
    try {
      final prefs = await SharedPreferences.getInstance();
      final _ = prefs.getBool(_tokenKey) ?? false;
    } catch (_) {}
  }
}
