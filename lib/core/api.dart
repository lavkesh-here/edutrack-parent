import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'cache.dart';
import 'device_context.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class SchoolInfo {
  final String id;
  final String name;
  final String code;
  final String? logoUrl;

  const SchoolInfo({required this.id, required this.name, required this.code, this.logoUrl});

  factory SchoolInfo.fromJson(Map<String, dynamic> j) => SchoolInfo(
        id: j['id'].toString(),
        name: j['name'] as String,
        code: j['code'] as String,
        logoUrl: j['logo_url'] as String?,
      );
}

class ParentAuthResponse {
  final String token;
  final String parentName;
  final String parentId;
  final bool mustChangePassword;

  const ParentAuthResponse({
    required this.token,
    required this.parentName,
    required this.parentId,
    required this.mustChangePassword,
  });

  factory ParentAuthResponse.fromJson(Map<String, dynamic> j) => ParentAuthResponse(
        token: j['access_token'] as String,
        parentName: j['parent_name'] as String,
        parentId: j['parent_id'].toString(),
        mustChangePassword: j['must_change_password'] as bool? ?? false,
      );
}

class ChildInfo {
  final String linkId;
  final String studentId;
  final String schoolId;
  final String studentName;
  final String admissionNumber;
  final String schoolName;
  final String schoolCode;
  final String? classLabel;
  final String relationType;
  final String? gender;
  final String? photoUrl;

  const ChildInfo({
    required this.linkId,
    required this.studentId,
    required this.schoolId,
    required this.studentName,
    required this.admissionNumber,
    required this.schoolName,
    required this.schoolCode,
    this.classLabel,
    required this.relationType,
    this.gender,
    this.photoUrl,
  });

  ChildInfo copyWith({String? photoUrl}) => ChildInfo(
        linkId: linkId,
        studentId: studentId,
        schoolId: schoolId,
        studentName: studentName,
        admissionNumber: admissionNumber,
        schoolName: schoolName,
        schoolCode: schoolCode,
        classLabel: classLabel,
        relationType: relationType,
        gender: gender,
        photoUrl: photoUrl ?? this.photoUrl,
      );

  factory ChildInfo.fromJson(Map<String, dynamic> j) => ChildInfo(
        linkId: j['link_id'].toString(),
        studentId: j['student_id'].toString(),
        schoolId: j['school_id'].toString(),
        studentName: j['student_name'] as String,
        admissionNumber: j['admission_number'] as String? ?? '',
        schoolName: j['school_name'] as String,
        schoolCode: j['school_code'] as String,
        classLabel: j['class_label'] as String?,
        relationType: j['relation_type'] as String? ?? 'parent',
        gender: j['gender'] as String?,
        photoUrl: j['photo_url'] as String?,
      );
}

class AttendanceRecord {
  final String date;
  final String status;

  const AttendanceRecord({required this.date, required this.status});

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
        date: j['date'] as String,
        status: j['status'] as String? ?? 'unknown',
      );
}

class AttendanceSummary {
  final int present;
  final int absent;
  final int late;
  final int total;
  final List<AttendanceRecord> records;

  const AttendanceSummary({
    required this.present,
    required this.absent,
    required this.late,
    required this.total,
    required this.records,
  });

  factory AttendanceSummary.fromJson(Map<String, dynamic> j) {
    final summary = j['summary'] as Map<String, dynamic>? ?? {};
    final records = (j['records'] as List<dynamic>? ?? [])
        .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
        .toList();
    return AttendanceSummary(
      present: summary['present'] as int? ?? 0,
      absent: summary['absent'] as int? ?? 0,
      late: summary['late'] as int? ?? 0,
      total: summary['total'] as int? ?? 0,
      records: records,
    );
  }
}

class TestResult {
  final String id;
  final String title;
  final String? subjectName;
  final String? classLabel;
  final double totalMarks;
  final double? marksObtained;
  final double? percentage;
  final bool isAbsent;
  final String? remarks;
  final String? scheduledDate;
  final int? rank;
  final int? totalStudents;

  const TestResult({
    required this.id,
    required this.title,
    this.subjectName,
    this.classLabel,
    required this.totalMarks,
    this.marksObtained,
    this.percentage,
    required this.isAbsent,
    this.remarks,
    this.scheduledDate,
    this.rank,
    this.totalStudents,
  });

  factory TestResult.fromJson(Map<String, dynamic> j) => TestResult(
        id: j['id'].toString(),
        title: j['title'] as String,
        subjectName: j['subject_name'] as String?,
        classLabel: j['class_label'] as String?,
        totalMarks: (j['total_marks'] as num?)?.toDouble() ?? 0,
        marksObtained: (j['marks_obtained'] as num?)?.toDouble(),
        percentage: (j['percentage'] as num?)?.toDouble(),
        isAbsent: j['is_absent'] as bool? ?? false,
        remarks: j['remarks'] as String?,
        scheduledDate: j['scheduled_date'] as String?,
        rank: (j['rank'] as num?)?.toInt(),
        totalStudents: (j['total_students'] as num?)?.toInt(),
      );
}

class WorkLogItem {
  final String id;
  final String date;
  final String logType;
  final String description;
  final String? dueDate;
  final String? sectionLabel;
  final String? subjectName;
  final String? teacherName;
  final String? submissionId;
  final String ackStatus; // pending | seen | completed | incomplete
  final String? parentNote;
  final List<String> imageUrls;

  const WorkLogItem({
    required this.id,
    required this.date,
    required this.logType,
    required this.description,
    this.dueDate,
    this.sectionLabel,
    this.subjectName,
    this.teacherName,
    this.submissionId,
    this.ackStatus = 'pending',
    this.parentNote,
    this.imageUrls = const [],
  });

  factory WorkLogItem.fromJson(Map<String, dynamic> j) => WorkLogItem(
        id: j['id'].toString(),
        date: j['date'] as String? ?? '',
        logType: j['log_type'] as String? ?? 'classwork',
        description: j['description'] as String? ?? '',
        dueDate: j['due_date'] as String?,
        sectionLabel: j['section_label'] as String?,
        subjectName: j['subject_name'] as String?,
        teacherName: j['teacher_name'] as String?,
        submissionId: j['submission_id']?.toString(),
        ackStatus: j['ack_status'] as String? ?? 'pending',
        parentNote: j['parent_note'] as String?,
        imageUrls: (j['image_urls'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
}

class WorkLogDate {
  final String date;
  final List<WorkLogItem> logs;
  const WorkLogDate({required this.date, required this.logs});
}

class ParentNotification {
  final String id;
  final String message;
  final String notificationType;
  final String createdAt;
  final String? teacherName;

  const ParentNotification({
    required this.id,
    required this.message,
    required this.notificationType,
    required this.createdAt,
    this.teacherName,
  });

  factory ParentNotification.fromJson(Map<String, dynamic> j) => ParentNotification(
        id: j['id'].toString(),
        message: j['message'] as String? ?? '',
        notificationType: j['notification_type'] as String? ?? 'custom',
        createdAt: j['created_at'] as String? ?? '',
        teacherName: j['teacher_name'] as String?,
      );
}

// ── API Client ────────────────────────────────────────────────────────────────

class ParentApiClient {
  static const defaultBaseUrl = 'https://edutrack-api-849362142189.asia-south1.run.app';
  static const devBaseUrl = 'http://10.0.2.2:8000';
  static const _prefKeyUrl = 'parent_server_url';
  static const _prefKeyToken = 'parent_auth_token';

  static Future<void> Function()? onUnauthorized;

  static Future<String> getBaseUrl() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_prefKeyUrl) ?? defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefKeyUrl, url.trim().replaceAll(RegExp(r'/$'), ''));
  }

  static Future<String?> getToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_prefKeyToken);
  }

  static Future<void> setToken(String? token) async {
    final p = await SharedPreferences.getInstance();
    if (token == null) {
      await p.remove(_prefKeyToken);
    } else {
      await p.setString(_prefKeyToken, token);
    }
  }

  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...DeviceContext.headers,
    };
  }

  static String _errorDetail(http.Response res) {
    try {
      final b = jsonDecode(res.body);
      return b['detail']?.toString() ?? 'Server error (${res.statusCode})';
    } catch (_) {
      return 'Server error (${res.statusCode})';
    }
  }

  static void _log(String method, String path, int status, int ms, {String? requestId, String? error}) {
    if (!kDebugMode) return;
    final rid = requestId != null ? ' [rid=$requestId]' : '';
    if (error != null) {
      dev.log('$method $path → $status (${ms}ms)$rid  ERROR: $error', name: 'ParentAPI', level: 900);
    } else {
      dev.log('$method $path → $status (${ms}ms)$rid', name: 'ParentAPI');
    }
  }

  static Future<dynamic> _get(String path) async {
    final base = await getBaseUrl();
    final sw = Stopwatch()..start();
    final res = await http.get(
      Uri.parse('$base$path'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 20));
    final ms = sw.elapsedMilliseconds;
    final rid = res.headers['x-request-id'];
    if (res.statusCode == 401) {
      _log('GET', path, 401, ms, requestId: rid, error: 'session expired');
      await onUnauthorized?.call();
      throw ApiError('Session expired. Please log in again.', 401);
    }
    if (res.statusCode >= 400) {
      final detail = _errorDetail(res);
      _log('GET', path, res.statusCode, ms, requestId: rid, error: detail);
      throw ApiError(detail, res.statusCode);
    }
    _log('GET', path, res.statusCode, ms, requestId: rid);
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static Future<dynamic> _delete(String path) async {
    final base = await getBaseUrl();
    final sw = Stopwatch()..start();
    final res = await http.delete(
      Uri.parse('$base$path'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 20));
    final ms = sw.elapsedMilliseconds;
    final rid = res.headers['x-request-id'];
    if (res.statusCode == 401) {
      _log('DELETE', path, 401, ms, requestId: rid, error: 'session expired');
      await onUnauthorized?.call();
      throw ApiError('Session expired. Please log in again.', 401);
    }
    if (res.statusCode >= 400) {
      final detail = _errorDetail(res);
      _log('DELETE', path, res.statusCode, ms, requestId: rid, error: detail);
      throw ApiError(detail, res.statusCode);
    }
    _log('DELETE', path, res.statusCode, ms, requestId: rid);
    if (res.body.isEmpty) return <String, dynamic>{};
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static Future<dynamic> _patch(String path, Map<String, dynamic> body) async {
    final base = await getBaseUrl();
    final sw = Stopwatch()..start();
    final res = await http.patch(
      Uri.parse('$base$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 20));
    final ms = sw.elapsedMilliseconds;
    final rid = res.headers['x-request-id'];
    if (res.statusCode == 401) {
      _log('PATCH', path, 401, ms, requestId: rid, error: 'session expired');
      await onUnauthorized?.call();
      throw ApiError('Session expired. Please log in again.', 401);
    }
    if (res.statusCode >= 400) {
      final detail = _errorDetail(res);
      _log('PATCH', path, res.statusCode, ms, requestId: rid, error: detail);
      throw ApiError(detail, res.statusCode);
    }
    _log('PATCH', path, res.statusCode, ms, requestId: rid);
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static Future<dynamic> _post(String path, Map<String, dynamic> body, {bool handleUnauthorized = true}) async {
    final base = await getBaseUrl();
    final sw = Stopwatch()..start();
    final res = await http.post(
      Uri.parse('$base$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 20));
    final ms = sw.elapsedMilliseconds;
    final rid = res.headers['x-request-id'];
    if (res.statusCode == 401) {
      _log('POST', path, 401, ms, requestId: rid, error: 'session expired');
      if (handleUnauthorized) await onUnauthorized?.call();
      throw ApiError(handleUnauthorized ? 'Session expired. Please log in again.' : 'Invalid credentials', 401);
    }
    if (res.statusCode >= 400) {
      final detail = _errorDetail(res);
      _log('POST', path, res.statusCode, ms, requestId: rid, error: detail);
      throw ApiError(detail, res.statusCode);
    }
    _log('POST', path, res.statusCode, ms, requestId: rid);
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  static Future<SchoolInfo> lookupSchool(String code) async {
    final data = await _get('/api/v1/auth/school/$code');
    return SchoolInfo.fromJson(data as Map<String, dynamic>);
  }

  static Future<ParentAuthResponse> login(String phone, String password, {String? deviceName, String? osVersion}) async {
    final data = await _post('/api/v1/auth/parent/login', {
      'phone': phone,
      'password': password,
      if (deviceName != null) 'device_name': deviceName,
      if (osVersion != null) 'os_version': osVersion,
      'app_version': '1.0.0',
    }, handleUnauthorized: false);
    return ParentAuthResponse.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    // parent_id is read from the Bearer token on the BE — no path param needed
    await _post('/api/v1/auth/parent/change-password', {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  // ── Profile + children ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getProfile() async {
    final data = await _get('/api/v1/parent/profile');
    return data as Map<String, dynamic>;
  }

  static Future<void> addChild({
    required String schoolCode,
    required String admissionNumber,
    required String password,
    String relation = 'parent',
  }) async {
    await _post('/api/v1/parent/add-child', {
      'school_code': schoolCode,
      'student_admission_number': admissionNumber,
      'password': password,
      'relationship': relation,
    });
  }

  // ── Child data ────────────────────────────────────────────────────────────

  static Future<AttendanceSummary> getAttendance(String studentId, {int? month, int? year}) async {
    var path = '/api/v1/parent/child/$studentId/attendance';
    if (month != null && year != null) path += '?month=$month&year=$year';
    final data = await _get(path);
    return AttendanceSummary.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<TestResult>> getTests(String studentId) async {
    final data = await _get('/api/v1/parent/child/$studentId/tests');
    final list = data as List<dynamic>;
    return list.map((e) => TestResult.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<WorkLogDate>> getWorkLogs(String studentId, {int days = 30}) async {
    final data = await _get('/api/v1/parent/child/$studentId/work-logs?days=$days');
    final map = data as Map<String, dynamic>;
    final dates = (map['dates'] as List<dynamic>? ?? []);
    return dates.map((d) {
      final dm = d as Map<String, dynamic>;
      final logs = (dm['logs'] as List<dynamic>? ?? [])
          .map((l) => WorkLogItem.fromJson(l as Map<String, dynamic>))
          .toList();
      return WorkLogDate(date: dm['date'] as String, logs: logs);
    }).toList();
  }

  static Future<void> acknowledgeWorkLog(String studentId, String logId,
      {required String status, String? note}) async {
    await _post('/api/v1/parent/child/$studentId/work-logs/$logId/acknowledge', {
      'status': status,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  static Future<List<ParentNotification>> getNotifications(String studentId) async {
    final data = await _get('/api/v1/parent/child/$studentId/notifications');
    final list = data as List<dynamic>;
    return list.map((e) => ParentNotification.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Map<String, dynamic>> getSchoolContacts(String schoolId) async {
    final data = await _get('/api/v1/parent/school/$schoolId/contacts');
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getChildProfile(String studentId) async {
    final data = await _get('/api/v1/parent/child/$studentId/profile');
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getTransport(String studentId) async {
    final data = await _get('/api/v1/parent/child/$studentId/transport');
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getFees(String studentId, {String? academicYear}) async {
    var path = '/api/v1/parent/child/$studentId/fees';
    if (academicYear != null) path += '?academic_year=$academicYear';
    final data = await _get(path);
    return data as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getAttenders(String studentId) async {
    final data = await _get('/api/v1/parent/child/$studentId/attenders');
    return (data as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<void> addAttender(String studentId, {required String name, required String phone, required String relation}) async {
    await _post('/api/v1/parent/child/$studentId/attenders', {'name': name, 'phone': phone, 'relation': relation});
  }

  static Future<Map<String, dynamic>> getAttenderUploadUrl(
    String studentId, {
    required String filename,
    required String contentType,
    required int fileSize,
  }) async {
    final data = await _post('/api/v1/parent/child/$studentId/attenders/upload-url', {
      'filename': filename,
      'content_type': contentType,
      'file_size': fileSize,
    });
    return data as Map<String, dynamic>;
  }

  static Future<void> updateAttenderPhoto(String studentId, String attenderId, String gcsUrl) async {
    await _patch('/api/v1/parent/child/$studentId/attenders/$attenderId/photo', {'gcs_url': gcsUrl});
  }

  static Future<void> deleteAttender(String studentId, String attenderId) async {
    final base = await getBaseUrl();
    final res = await http.delete(
      Uri.parse('$base/api/v1/parent/child/$studentId/attenders/$attenderId'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 20));
    if (res.statusCode == 401) {
      await onUnauthorized?.call();
      throw ApiError('Session expired. Please log in again.', 401);
    }
    if (res.statusCode >= 400) throw ApiError(_errorDetail(res), res.statusCode);
  }

  static Future<List<Map<String, dynamic>>> getTeachers(String studentId) async {
    final data = await _get('/api/v1/parent/child/$studentId/teachers');
    return (data as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<List<Map<String, dynamic>>> getDevices() async {
    final data = await _get('/api/v1/parent/devices');
    return (data as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<void> removeDevice(String sessionId) async {
    final base = await getBaseUrl();
    final res = await http.delete(
      Uri.parse('$base/api/v1/parent/devices/$sessionId'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 20));
    if (res.statusCode == 401) {
      await onUnauthorized?.call();
      throw ApiError('Session expired. Please log in again.', 401);
    }
    if (res.statusCode >= 400) throw ApiError(_errorDetail(res), res.statusCode);
  }
  // ── Push token registration ───────────────────────────────────────────────

  static Future<void> registerPushToken(String fcmToken, String deviceId) async {
    await _post('/api/v1/parent/push-token', {'fcm_token': fcmToken, 'device_id': deviceId});
  }

  static Future<void> deregisterPushToken(String deviceId) async {
    final base = await getBaseUrl();
    final req = http.Request('DELETE', Uri.parse('$base/api/v1/parent/push-token'));
    req.headers.addAll(await _headers());
    req.body = jsonEncode({'device_id': deviceId});
    await req.send();
  }

  // ── In-app notification inbox ─────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getInbox() async {
    final data = await _get('/api/v1/parent/notifications');
    return List<Map<String, dynamic>>.from(data as List);
  }

  static Future<void> markInboxRead(String notifId) async {
    await _post('/api/v1/parent/notifications/$notifId/read', {});
  }

  // ── Circulars ─────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getCirculars(String studentId) async {
    final data = await _get('/api/v1/parent/child/$studentId/circulars');
    return (data as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  // ── Documents ─────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getDocuments(String studentId) async {
    final data = await _get('/api/v1/parent/child/$studentId/documents');
    return (data as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  // ── Timetable ─────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getChildTimetable(String studentId) async {
    final data = await _get('/api/v1/parent/child/$studentId/timetable');
    return data as Map<String, dynamic>;
  }

  // ── Upcoming tests ────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getUpcomingTests(String studentId) async {
    final data = await _get('/api/v1/parent/child/$studentId/upcoming-tests');
    return (data as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  // ── Onboarding ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getOnboardingState() async {
    return (await _get('/api/v1/parent/onboarding')) as Map<String, dynamic>;
  }

  static Future<void> markOnboardingSeen(String actionKey) async {
    await _post('/api/v1/parent/onboarding/$actionKey/seen', {});
  }

  // ── Parent own profile photo ──────────────────────────────────────────────

  static Future<Map<String, dynamic>> getProfilePhotoUploadUrl(
      String filename, String contentType, int fileSize) async {
    return (await _post('/api/v1/parent/me/photo-url', {
      'filename': filename,
      'content_type': contentType,
      'file_size': fileSize,
    })) as Map<String, dynamic>;
  }

  static Future<void> saveProfilePhotoUrl(String photoUrl) async {
    await _patch('/api/v1/parent/me/photo', {'photo_url': photoUrl});
  }

  // ── Student photo (parent: always changeable) ─────────────────────────────

  static Future<Map<String, dynamic>> getChildPhotoUploadUrl(
    String studentId, {
    required String filename,
    required String contentType,
    required int fileSize,
  }) async {
    return (await _post('/api/v1/parent/child/$studentId/photo/upload-url', {
      'filename': filename,
      'content_type': contentType,
      'file_size': fileSize,
    })) as Map<String, dynamic>;
  }

  static Future<void> saveChildPhoto(String studentId, String photoUrl) async {
    await _patch('/api/v1/parent/child/$studentId/photo', {'photo_url': photoUrl});
  }

  // ── Feature flags ──────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getFeatureConfig() async {
    final data = await _get('/api/v1/parent/feature-config');
    // Returns {school_id: {feature_key: bool}} — merge into a single flat map
    // (use the first school's flags; multi-school merges happen at UI layer)
    final map = (data as Map<String, dynamic>?) ?? {};
    if (map.isEmpty) return {};
    final first = map.values.first as Map<String, dynamic>? ?? {};
    return first;
  }

  static Future<Map<String, dynamic>> getBranding(String schoolId) async {
    final data = await _get('/api/v1/parent/branding/$schoolId');
    return (data as Map<String, dynamic>?) ?? {};
  }

  static Future<List<Map<String, dynamic>>> getHealthIncidents(String studentId) async {
    final data = await _get('/api/v1/parent/health-incidents/$studentId') as List<dynamic>;
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  // ── Cached profile ─────────────────────────────────────────────────────────

  // ── Global search ──────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> globalSearch(String studentId, String query) async {
    final encoded = Uri.encodeComponent(query);
    return (await _get('/api/v1/parent/search?student_id=$studentId&q=$encoded'))
        as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getProfileCached() async {
    const key = 'parent_profile';
    const maxAge = Duration(minutes: 5);
    final cached = await CacheService.getMap(key, maxAge: maxAge);
    if (cached != null) {
      // Refresh in background
      getProfile().then((fresh) => CacheService.set(key, fresh)).ignore();
      return cached;
    }
    final fresh = await getProfile();
    await CacheService.set(key, fresh);
    return fresh;
  }

  // ── Student Full Report Card ───────────────────────────────────────────────

  static Future<Map<String, dynamic>> getStudentFullReport(String studentId) async {
    return (await _get('/api/v1/parent/child/$studentId/full-report'))
        as Map<String, dynamic>;
  }

  // ── Report card PDF ────────────────────────────────────────────────────────

  static Future<String> exportReportCardToken(String studentId) async {
    final data = await _post('/api/v1/parent/child/$studentId/full-report/export-token', {});
    return data['token'] as String;
  }

  // ── Child syllabus ─────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getChildSyllabus(String studentId) async {
    final data = await _get('/api/v1/parent/child/$studentId/syllabus');
    if (data == null) return [];
    return (data as List<dynamic>).cast<Map<String, dynamic>>();
  }

  // ── Support chat ───────────────────────────────────────────────────────────

  static Future<String> supportChat({
    required String message,
    required List<Map<String, String>> history,
  }) async {
    final data = await _post('/api/v1/parent/support/chat', {
      'message': message,
      'history': history,
    });
    return data['reply'] as String;
  }

  // ── Forum ──────────────────────────────────────────────────────────────────

  static Future<List<ForumPost>> getForumPosts({int page = 0, int pageSize = 20}) async {
    final data = await _get('/api/v1/parent/forum/posts?page=$page&page_size=$pageSize');
    final list = (data as Map<String, dynamic>)['announcements'] as List<dynamic>;
    return list.map((e) => ForumPost.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<ForumComment>> getForumComments(String postId) async {
    final data = await _get('/api/v1/parent/forum/posts/$postId/comments');
    return (data as List<dynamic>)
        .map((e) => ForumComment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> createForumComment(String postId, String body, {String? parentId}) async {
    await _post('/api/v1/parent/forum/posts/$postId/comments', {
      'body': body,
      if (parentId != null) 'parent_id': parentId,
    });
  }

  static Future<bool> toggleForumCommentLike(String commentId) async {
    final data = await _post('/api/v1/parent/forum/comments/$commentId/like', {});
    return (data as Map<String, dynamic>)['liked'] as bool? ?? false;
  }

}  // end ParentApiClient


// ── Forum models ──────────────────────────────────────────────────────────────

class ForumPost {
  final String id;
  final String title;
  final String body;
  final String audience;
  final bool isPinned;
  final bool allowComments;
  final String createdAt;
  final String? authorName;
  final List<Map<String, dynamic>> images;
  final int commentCount;
  final int likeCount;
  final bool likedByMe;
  final Map<String, dynamic>? previewComment;

  const ForumPost({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    required this.isPinned,
    required this.allowComments,
    required this.createdAt,
    this.authorName,
    this.images = const [],
    this.commentCount = 0,
    this.likeCount = 0,
    this.likedByMe = false,
    this.previewComment,
  });

  factory ForumPost.fromJson(Map<String, dynamic> j) => ForumPost(
        id: j['id'].toString(),
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        audience: j['audience'] as String? ?? 'all',
        isPinned: j['is_pinned'] as bool? ?? false,
        allowComments: j['allow_comments'] as bool? ?? false,
        createdAt: j['created_at'] as String? ?? '',
        authorName: j['author_name'] as String?,
        images: (j['images'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
        commentCount: j['comment_count'] as int? ?? 0,
        likeCount: j['like_count'] as int? ?? 0,
        likedByMe: j['liked_by_me'] as bool? ?? false,
        previewComment: j['preview_comment'] as Map<String, dynamic>?,
      );
}

class ForumComment {
  final String id;
  final String body;
  final String? authorName;
  final String createdAt;
  final String? parentId;
  final int likeCount;
  final bool likedByMe;

  const ForumComment({
    required this.id,
    required this.body,
    this.authorName,
    required this.createdAt,
    this.parentId,
    this.likeCount = 0,
    this.likedByMe = false,
  });

  factory ForumComment.fromJson(Map<String, dynamic> j) => ForumComment(
        id: j['id'].toString(),
        body: j['body'] as String? ?? '',
        authorName: j['author_name'] as String?,
        createdAt: j['created_at'] as String? ?? '',
        parentId: j['parent_id']?.toString(),
        likeCount: j['like_count'] as int? ?? 0,
        likedByMe: j['liked_by_me'] as bool? ?? false,
      );
}

class ApiError implements Exception {
  final String message;
  final int statusCode;
  const ApiError(this.message, this.statusCode);

  @override
  String toString() => message;
}

// ── Certificates ──────────────────────────────────────────────────────────────

extension ParentApiClientCertificates on ParentApiClient {
  static Future<List<Map<String, dynamic>>> getChildCertificates(String studentId) async {
    final data = await ParentApiClient._get('/api/v1/parent/child/$studentId/certificates');
    return (data as List).cast<Map<String, dynamic>>();
  }

  static Future<String> getCertificatePdfUrl(String studentId, String certId) async {
    final data = await ParentApiClient._post(
      '/api/v1/parent/child/$studentId/certificates/$certId/export-token',
      {},
    );
    final token = data['token'] as String;
    final base = await ParentApiClient.getBaseUrl();
    return '$base/api/v1/parent/certificates/$certId/pdf?token=$token';
  }
}

// ── PTM ───────────────────────────────────────────────────────────────────────

extension ParentApiClientPTM on ParentApiClient {
  static Future<List<Map<String, dynamic>>> getChildPTM(String studentId) async {
    final data = await ParentApiClient._get('/api/v1/parent/child/$studentId/ptm');
    return (data['meetings'] as List).cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> getPTMEvents(String studentId) async {
    final data = await ParentApiClient._get(
        '/api/v1/parent/ptm/events?student_id=$studentId');
    return (data['events'] as List).cast<Map<String, dynamic>>();
  }

  static Future<void> registerPTM(String eventId, String studentId, {String? remarks}) async {
    await ParentApiClient._post('/api/v1/parent/ptm/events/$eventId/register', {
      'student_id': studentId,
      if (remarks != null && remarks.isNotEmpty) 'parent_remarks': remarks,
    });
  }

  static Future<void> cancelPTMRegistration(String eventId, String studentId) async {
    await ParentApiClient._delete(
        '/api/v1/parent/ptm/events/$eventId/register?student_id=$studentId');
  }
}

// ── SOS ───────────────────────────────────────────────────────────────────────

extension ParentApiClientSOS on ParentApiClient {
  static Future<void> triggerSOS({String? locationNote, String? studentId}) async {
    await ParentApiClient._post('/api/v1/parent/sos', {
      if (locationNote != null) 'location_note': locationNote,
      if (studentId != null) 'student_id': studentId,
    });
  }
}

// ── Emergency Contacts ────────────────────────────────────────────────────────

extension ParentApiClientEmergency on ParentApiClient {
  static Future<List<Map<String, dynamic>>> getChildEmergencyContacts(String studentId) async {
    final data = await ParentApiClient._get('/api/v1/parent/child/$studentId/emergency-contacts');
    return (data['contacts'] as List).cast<Map<String, dynamic>>();
  }

  static Future<void> addEmergencyContact(String studentId, {
    required String name,
    required String relation,
    required String phone,
    int priority = 1,
  }) async {
    await ParentApiClient._post('/api/v1/parent/child/$studentId/emergency-contacts', {
      'name': name,
      'relation': relation,
      'phone': phone,
      'priority': priority,
    });
  }

  static Future<void> deleteEmergencyContact(String studentId, String contactId) async {
    await ParentApiClient._delete('/api/v1/parent/child/$studentId/emergency-contacts/$contactId');
  }
}

// ── Medical Profile ───────────────────────────────────────────────────────────

extension ParentApiClientMedical on ParentApiClient {
  static Future<Map<String, dynamic>?> getChildMedical(String studentId) async {
    final data = await ParentApiClient._get('/api/v1/parent/child/$studentId/medical');
    return data['profile'] as Map<String, dynamic>?;
  }
}

// ── AI Report Explain ─────────────────────────────────────────────────────────

extension ParentApiClientAI on ParentApiClient {
  static Future<String> explainReport(String studentId, {String language = 'english'}) async {
    final data = await ParentApiClient._post(
      '/api/v1/parent/child/$studentId/report/explain',
      {'language': language},
    );
    return data['explanation'] as String? ?? '';
  }
}
