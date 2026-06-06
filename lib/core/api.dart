import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class SchoolInfo {
  final int id;
  final String name;
  final String code;
  final String? logoUrl;

  const SchoolInfo({required this.id, required this.name, required this.code, this.logoUrl});

  factory SchoolInfo.fromJson(Map<String, dynamic> j) => SchoolInfo(
        id: j['id'] as int,
        name: j['name'] as String,
        code: j['code'] as String,
        logoUrl: j['logo_url'] as String?,
      );
}

class ParentAuthResponse {
  final String token;
  final String parentName;
  final int parentId;
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
        parentId: j['parent_id'] as int,
        mustChangePassword: j['must_change_password'] as bool? ?? false,
      );
}

class ChildInfo {
  final int linkId;
  final int studentId;
  final int schoolId;
  final String studentName;
  final String admissionNumber;
  final String schoolName;
  final String schoolCode;
  final String? classLabel;
  final String relationType;

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
  });

  factory ChildInfo.fromJson(Map<String, dynamic> j) => ChildInfo(
        linkId: j['link_id'] as int,
        studentId: j['student_id'] as int,
        schoolId: j['school_id'] as int,
        studentName: j['student_name'] as String,
        admissionNumber: j['admission_number'] as String? ?? '',
        schoolName: j['school_name'] as String,
        schoolCode: j['school_code'] as String,
        classLabel: j['class_label'] as String?,
        relationType: j['relation_type'] as String? ?? 'parent',
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
  final int id;
  final String title;
  final String? subjectName;
  final String? classLabel;
  final double totalMarks;
  final double? marksObtained;
  final double? percentage;
  final bool isAbsent;
  final String? remarks;
  final String? scheduledDate;

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
  });

  factory TestResult.fromJson(Map<String, dynamic> j) => TestResult(
        id: j['id'] as int,
        title: j['title'] as String,
        subjectName: j['subject_name'] as String?,
        classLabel: j['class_label'] as String?,
        totalMarks: (j['total_marks'] as num?)?.toDouble() ?? 0,
        marksObtained: (j['marks_obtained'] as num?)?.toDouble(),
        percentage: (j['percentage'] as num?)?.toDouble(),
        isAbsent: j['is_absent'] as bool? ?? false,
        remarks: j['remarks'] as String?,
        scheduledDate: j['scheduled_date'] as String?,
      );
}

class WorkLogItem {
  final int id;
  final String date;
  final String logType;
  final String description;
  final String? dueDate;
  final String? sectionLabel;
  final String? subjectName;
  final String? teacherName;

  const WorkLogItem({
    required this.id,
    required this.date,
    required this.logType,
    required this.description,
    this.dueDate,
    this.sectionLabel,
    this.subjectName,
    this.teacherName,
  });

  factory WorkLogItem.fromJson(Map<String, dynamic> j) => WorkLogItem(
        id: j['id'] as int,
        date: j['date'] as String? ?? '',
        logType: j['log_type'] as String? ?? 'classwork',
        description: j['description'] as String? ?? '',
        dueDate: j['due_date'] as String?,
        sectionLabel: j['section_label'] as String?,
        subjectName: j['subject_name'] as String?,
        teacherName: j['teacher_name'] as String?,
      );
}

class ParentNotification {
  final int id;
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
        id: j['id'] as int,
        message: j['message'] as String? ?? '',
        notificationType: j['notification_type'] as String? ?? 'custom',
        createdAt: j['created_at'] as String? ?? '',
        teacherName: j['teacher_name'] as String?,
      );
}

// ── API Client ────────────────────────────────────────────────────────────────

class ParentApiClient {
  static const defaultBaseUrl = 'https://edutrack-api-6382035856.asia-south1.run.app';
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

  static Future<dynamic> _get(String path) async {
    final base = await getBaseUrl();
    final res = await http.get(
      Uri.parse('$base$path'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 20));
    if (res.statusCode == 401) {
      await onUnauthorized?.call();
      throw ApiError('Session expired. Please log in again.', 401);
    }
    if (res.statusCode >= 400) throw ApiError(_errorDetail(res), res.statusCode);
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static Future<dynamic> _post(String path, Map<String, dynamic> body, {bool handleUnauthorized = true}) async {
    final base = await getBaseUrl();
    final res = await http.post(
      Uri.parse('$base$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 20));
    if (res.statusCode == 401) {
      if (handleUnauthorized) await onUnauthorized?.call();
      throw ApiError(handleUnauthorized ? 'Session expired. Please log in again.' : 'Invalid credentials', 401);
    }
    if (res.statusCode >= 400) throw ApiError(_errorDetail(res), res.statusCode);
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
    required int parentId,
    required String currentPassword,
    required String newPassword,
  }) async {
    await _post('/api/v1/auth/parent/$parentId/change-password', {
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

  static Future<AttendanceSummary> getAttendance(int studentId, {int? month, int? year}) async {
    var path = '/api/v1/parent/child/$studentId/attendance';
    if (month != null && year != null) path += '?month=$month&year=$year';
    final data = await _get(path);
    return AttendanceSummary.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<TestResult>> getTests(int studentId) async {
    final data = await _get('/api/v1/parent/child/$studentId/tests');
    final list = data as List<dynamic>;
    return list.map((e) => TestResult.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<WorkLogItem>> getWorkLogs(int studentId) async {
    final data = await _get('/api/v1/parent/child/$studentId/work-logs');
    final list = data as List<dynamic>;
    return list.map((e) => WorkLogItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<ParentNotification>> getNotifications(int studentId) async {
    final data = await _get('/api/v1/parent/child/$studentId/notifications');
    final list = data as List<dynamic>;
    return list.map((e) => ParentNotification.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Map<String, dynamic>> getSchoolContacts(int schoolId) async {
    final data = await _get('/api/v1/parent/school/$schoolId/contacts');
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getChildProfile(int studentId) async {
    final data = await _get('/api/v1/parent/child/$studentId/profile');
    return data as Map<String, dynamic>;
  }
}

  static Future<Map<String, dynamic>> getTransport(int studentId) async {
    final data = await _get('/api/v1/parent/child/$studentId/transport');
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getFees(int studentId, {String? academicYear}) async {
    var path = '/api/v1/parent/child/$studentId/fees';
    if (academicYear != null) path += '?academic_year=$academicYear';
    final data = await _get(path);
    return data as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getAttenders(int studentId) async {
    final data = await _get('/api/v1/parent/child/$studentId/attenders');
    return (data as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<void> addAttender(int studentId, {required String name, required String phone, required String relation}) async {
    await _post('/api/v1/parent/child/$studentId/attenders', {'name': name, 'phone': phone, 'relation': relation});
  }

  static Future<void> deleteAttender(int studentId, int attenderId) async {
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

  static Future<List<Map<String, dynamic>>> getTeachers(int studentId) async {
    final data = await _get('/api/v1/parent/child/$studentId/teachers');
    return (data as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<List<Map<String, dynamic>>> getDevices() async {
    final data = await _get('/api/v1/parent/devices');
    return (data as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<void> removeDevice(int sessionId) async {
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
}

class ApiError implements Exception {
  final String message;
  final int statusCode;
  const ApiError(this.message, this.statusCode);

  @override
  String toString() => message;
}
