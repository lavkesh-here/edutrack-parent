// Pure logic tests for Session 48 — comprehensive model + business logic coverage.
// No device or platform channels required.

import 'package:flutter_test/flutter_test.dart';

// ══════════════════════════════════════════════════════════════════════════════
// MODEL REPLICAS (from core/api.dart and screens/)
// ══════════════════════════════════════════════════════════════════════════════

// ── SchoolInfo ────────────────────────────────────────────────────────────────
class _SchoolInfo {
  final String id;
  final String name;
  final String code;
  final String? logoUrl;
  const _SchoolInfo({required this.id, required this.name, required this.code, this.logoUrl});
  factory _SchoolInfo.fromJson(Map<String, dynamic> j) => _SchoolInfo(
        id: j['id'].toString(),
        name: j['name'] as String,
        code: j['code'] as String,
        logoUrl: j['logo_url'] as String?,
      );
}

// ── ParentAuthResponse ────────────────────────────────────────────────────────
class _ParentAuthResponse {
  final String token;
  final String parentId;
  final bool mustChangePassword;
  const _ParentAuthResponse({required this.token, required this.parentId, this.mustChangePassword = false});
  factory _ParentAuthResponse.fromJson(Map<String, dynamic> j) => _ParentAuthResponse(
        token: j['access_token'] as String,
        parentId: j['parent_id'].toString(),
        mustChangePassword: j['must_change_password'] as bool? ?? false,
      );
}

// ── ChildInfo ─────────────────────────────────────────────────────────────────
class _ChildInfo {
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
  const _ChildInfo({
    required this.linkId, required this.studentId, required this.schoolId,
    required this.studentName, required this.admissionNumber, required this.schoolName,
    required this.schoolCode, this.classLabel, required this.relationType,
    this.gender, this.photoUrl,
  });
  _ChildInfo copyWith({String? photoUrl}) => _ChildInfo(
        linkId: linkId, studentId: studentId, schoolId: schoolId,
        studentName: studentName, admissionNumber: admissionNumber, schoolName: schoolName,
        schoolCode: schoolCode, classLabel: classLabel, relationType: relationType,
        gender: gender, photoUrl: photoUrl ?? this.photoUrl,
      );
  factory _ChildInfo.fromJson(Map<String, dynamic> j) => _ChildInfo(
        linkId: j['link_id'].toString(), studentId: j['student_id'].toString(),
        schoolId: j['school_id'].toString(), studentName: j['student_name'] as String,
        admissionNumber: j['admission_number'] as String? ?? '',
        schoolName: j['school_name'] as String, schoolCode: j['school_code'] as String,
        classLabel: j['class_label'] as String?, relationType: j['relation_type'] as String? ?? 'parent',
        gender: j['gender'] as String?, photoUrl: j['photo_url'] as String?,
      );
}

// ── AttendanceRecord / AttendanceSummary ──────────────────────────────────────
class _AttendanceRecord {
  final String date;
  final String status;
  const _AttendanceRecord({required this.date, required this.status});
  factory _AttendanceRecord.fromJson(Map<String, dynamic> j) => _AttendanceRecord(
        date: j['date'] as String,
        status: j['status'] as String? ?? 'unknown',
      );
}

class _AttendanceSummary {
  final int present;
  final int absent;
  final int late;
  final int total;
  final List<_AttendanceRecord> records;
  const _AttendanceSummary({
    required this.present, required this.absent, required this.late,
    required this.total, required this.records,
  });
  factory _AttendanceSummary.fromJson(Map<String, dynamic> j) {
    final summary = j['summary'] as Map<String, dynamic>? ?? {};
    final records = (j['records'] as List<dynamic>? ?? [])
        .map((e) => _AttendanceRecord.fromJson(e as Map<String, dynamic>))
        .toList();
    return _AttendanceSummary(
      present: summary['present'] as int? ?? 0,
      absent: summary['absent'] as int? ?? 0,
      late: summary['late'] as int? ?? 0,
      total: summary['total'] as int? ?? 0,
      records: records,
    );
  }
  double get attendancePct => total == 0 ? 0.0 : present / total;
}

// ── TestResult ────────────────────────────────────────────────────────────────
class _TestResult {
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
  const _TestResult({
    required this.id, required this.title, this.subjectName, this.classLabel,
    required this.totalMarks, this.marksObtained, this.percentage, required this.isAbsent,
    this.remarks, this.scheduledDate, this.rank, this.totalStudents,
  });
  factory _TestResult.fromJson(Map<String, dynamic> j) => _TestResult(
        id: j['id'].toString(), title: j['title'] as String,
        subjectName: j['subject_name'] as String?, classLabel: j['class_label'] as String?,
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

// ── WorkLogItem ───────────────────────────────────────────────────────────────
class _WorkLogItem {
  final String id;
  final String date;
  final String logType;
  final String description;
  final String? dueDate;
  final String? sectionLabel;
  final String? subjectName;
  final String? teacherName;
  final String? submissionId;
  final String ackStatus;
  final String? parentNote;
  final List<String> imageUrls;
  const _WorkLogItem({
    required this.id, required this.date, required this.logType,
    required this.description, this.dueDate, this.sectionLabel, this.subjectName,
    this.teacherName, this.submissionId, this.ackStatus = 'pending',
    this.parentNote, this.imageUrls = const [],
  });
  factory _WorkLogItem.fromJson(Map<String, dynamic> j) => _WorkLogItem(
        id: j['id'].toString(), date: j['date'] as String? ?? '',
        logType: j['log_type'] as String? ?? 'classwork',
        description: j['description'] as String? ?? '',
        dueDate: j['due_date'] as String?,
        sectionLabel: j['section_label'] as String?,
        subjectName: j['subject_name'] as String?,
        teacherName: j['teacher_name'] as String?,
        submissionId: j['submission_id']?.toString(),
        ackStatus: j['ack_status'] as String? ?? 'pending',
        parentNote: j['parent_note'] as String?,
        imageUrls: (j['image_urls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      );
  bool get isPending => ackStatus == 'pending' || ackStatus == 'seen';
}

class _WorkLogDate {
  final String date;
  final List<_WorkLogItem> logs;
  const _WorkLogDate({required this.date, required this.logs});
}

// ── ParentNotification ────────────────────────────────────────────────────────
class _ParentNotification {
  final String id;
  final String message;
  final String notificationType;
  final String createdAt;
  final String? teacherName;
  const _ParentNotification({
    required this.id, required this.message, required this.notificationType,
    required this.createdAt, this.teacherName,
  });
  factory _ParentNotification.fromJson(Map<String, dynamic> j) => _ParentNotification(
        id: j['id'].toString(), message: j['message'] as String? ?? '',
        notificationType: j['notification_type'] as String? ?? 'custom',
        createdAt: j['created_at'] as String? ?? '',
        teacherName: j['teacher_name'] as String?,
      );
}

// ── ForumPost / ForumComment ──────────────────────────────────────────────────
class _ForumPost {
  final String id;
  final String title;
  final String body;
  final String audience;
  final bool isPinned;
  final bool allowComments;
  final String createdAt;
  final String? authorName;
  final int commentCount;
  final int likeCount;
  final bool likedByMe;
  const _ForumPost({
    required this.id, required this.title, required this.body, required this.audience,
    required this.isPinned, required this.allowComments, required this.createdAt,
    this.authorName, this.commentCount = 0, this.likeCount = 0, this.likedByMe = false,
  });
  factory _ForumPost.fromJson(Map<String, dynamic> j) => _ForumPost(
        id: j['id'].toString(), title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '', audience: j['audience'] as String? ?? 'all',
        isPinned: j['is_pinned'] as bool? ?? false,
        allowComments: j['allow_comments'] as bool? ?? false,
        createdAt: j['created_at'] as String? ?? '',
        authorName: j['author_name'] as String?,
        commentCount: j['comment_count'] as int? ?? 0,
        likeCount: j['like_count'] as int? ?? 0,
        likedByMe: j['liked_by_me'] as bool? ?? false,
      );
}

class _ForumComment {
  final String id;
  final String body;
  final String? authorName;
  final String createdAt;
  final String? parentId;
  final int likeCount;
  final bool likedByMe;
  const _ForumComment({
    required this.id, required this.body, this.authorName,
    required this.createdAt, this.parentId, this.likeCount = 0, this.likedByMe = false,
  });
  factory _ForumComment.fromJson(Map<String, dynamic> j) => _ForumComment(
        id: j['id'].toString(), body: j['body'] as String? ?? '',
        authorName: j['author_name'] as String?, createdAt: j['created_at'] as String? ?? '',
        parentId: j['parent_id']?.toString(),
        likeCount: j['like_count'] as int? ?? 0, likedByMe: j['liked_by_me'] as bool? ?? false,
      );
}

// ── Fee categorisation helpers (from screens/fees.dart) ───────────────────────
bool _isCurrentOrPast(Map<String, dynamic> item, String currentYm) {
  final fm = item['fee_month'] as String?;
  if (fm == null) return true;
  return fm.substring(0, 7).compareTo(currentYm) <= 0;
}

List<Map<String, dynamic>> _overdue(List<Map<String, dynamic>> all) =>
    all.where((i) => i['status'] == 'overdue').toList();

List<Map<String, dynamic>> _currentUnpaid(List<Map<String, dynamic>> all, String ym) =>
    all.where((i) => i['status'] == 'unpaid' && _isCurrentOrPast(i, ym)).toList();

List<Map<String, dynamic>> _futureUnpaid(List<Map<String, dynamic>> all, String ym) =>
    all.where((i) => i['status'] == 'unpaid' && !_isCurrentOrPast(i, ym)).toList();

List<Map<String, dynamic>> _paid(List<Map<String, dynamic>> all) =>
    all.where((i) => i['status'] == 'paid').toList();

bool _hasUnpaidDue(List<Map<String, dynamic>> all, String ym) =>
    _overdue(all).isNotEmpty || _currentUnpaid(all, ym).isNotEmpty;

double _totalAmount(List<Map<String, dynamic>> items) =>
    items.fold(0.0, (sum, i) => sum + ((i['amount'] as num?) ?? 0).toDouble());

// ── Child switcher helper ─────────────────────────────────────────────────────
int _targetChildIdx(List<_ChildInfo> children, String? targetStudentId, int current) {
  if (targetStudentId == null) return current;
  final idx = children.indexWhere((c) => c.studentId == targetStudentId);
  return idx >= 0 ? idx : current;
}

// ── Work log filter (from screens/work_log.dart) ──────────────────────────────
List<_WorkLogDate> _filterByLogType(List<_WorkLogDate> dates, String filter) {
  if (filter == 'all') return dates;
  return dates.map((d) {
    final logs = d.logs.where((l) => l.logType == filter).toList();
    return _WorkLogDate(date: d.date, logs: logs);
  }).where((d) => d.logs.isNotEmpty).toList();
}

// ── FCM notification routing (from screens/home.dart) ────────────────────────
String _routeFromNotifType(String type) {
  switch (type) {
    case 'attendance': return 'attendance';
    case 'test_result': return 'tests';
    case 'fee_reminder': return 'fees';
    case 'work_log': return 'work_log';
    case 'circular': return 'home';
    default: return 'home';
  }
}

// ── Feature flags logic (from core/features.dart pattern) ────────────────────
class _FeatureFlags {
  final Map<String, bool> _flags;
  const _FeatureFlags(this._flags);
  factory _FeatureFlags.fromJson(Map<String, dynamic> j) => _FeatureFlags(
        Map<String, bool>.fromEntries(
          j.entries.map((e) => MapEntry(e.key, (e.value as bool?) ?? true)),
        ),
      );
  bool get fees => (_flags['feature.parent_fees'] ?? true) && (_flags['sa.fees_module'] ?? true);
  bool get transport => (_flags['feature.transport'] ?? true) && (_flags['sa.transport_module'] ?? true);
  bool get workLogs => _flags['feature.work_logs'] ?? true;
  bool get forum => _flags['feature.announcements'] ?? true;
}

// ══════════════════════════════════════════════════════════════════════════════
// TESTS
// ══════════════════════════════════════════════════════════════════════════════

void main() {
  // ── SchoolInfo ────────────────────────────────────────────────────────────
  group('SchoolInfo.fromJson', () {
    test('parses all fields', () {
      final s = _SchoolInfo.fromJson({'id': '1', 'name': 'Sunrise', 'code': 'SRS', 'logo_url': 'https://logo.png'});
      expect(s.name, 'Sunrise');
      expect(s.logoUrl, 'https://logo.png');
    });
    test('logoUrl null when absent', () {
      final s = _SchoolInfo.fromJson({'id': '2', 'name': 'X', 'code': 'X'});
      expect(s.logoUrl, isNull);
    });
    test('id coerced from int', () {
      final s = _SchoolInfo.fromJson({'id': 42, 'name': 'Y', 'code': 'Y'});
      expect(s.id, '42');
    });
  });

  // ── ParentAuthResponse ────────────────────────────────────────────────────
  group('ParentAuthResponse.fromJson', () {
    test('parses all fields', () {
      final a = _ParentAuthResponse.fromJson({
        'access_token': 'tok-abc', 'parent_id': 99, 'must_change_password': true,
      });
      expect(a.token, 'tok-abc');
      expect(a.parentId, '99');
      expect(a.mustChangePassword, isTrue);
    });
    test('mustChangePassword defaults false', () {
      final a = _ParentAuthResponse.fromJson({'access_token': 't', 'parent_id': '1'});
      expect(a.mustChangePassword, isFalse);
    });
  });

  // ── ChildInfo ─────────────────────────────────────────────────────────────
  group('ChildInfo.fromJson', () {
    final json = {
      'link_id': 'lnk-1', 'student_id': 'stu-1', 'school_id': 'sch-1',
      'student_name': 'Aarav Singh', 'admission_number': 'ADM001',
      'school_name': 'Sunrise Public School', 'school_code': 'SPS',
      'class_label': '8A', 'relation_type': 'parent', 'gender': 'male',
      'photo_url': 'https://gcs.example.com/aarav.jpg',
    };
    test('parses all fields', () {
      final c = _ChildInfo.fromJson(json);
      expect(c.studentName, 'Aarav Singh');
      expect(c.classLabel, '8A');
      expect(c.relationType, 'parent');
      expect(c.gender, 'male');
      expect(c.photoUrl, 'https://gcs.example.com/aarav.jpg');
    });
    test('ids coerced from int', () {
      final j = Map<String, dynamic>.from(json)
        ..['link_id'] = 1 ..['student_id'] = 2 ..['school_id'] = 3;
      final c = _ChildInfo.fromJson(j);
      expect(c.linkId, '1'); expect(c.studentId, '2'); expect(c.schoolId, '3');
    });
    test('optional fields default correctly', () {
      final c = _ChildInfo.fromJson({
        'link_id': '1', 'student_id': '2', 'school_id': '3',
        'student_name': 'Priya', 'school_name': 'Test', 'school_code': 'TS',
      });
      expect(c.admissionNumber, '');
      expect(c.classLabel, isNull);
      expect(c.relationType, 'parent');
      expect(c.gender, isNull);
      expect(c.photoUrl, isNull);
    });
    test('copyWith updates only photoUrl', () {
      final c = _ChildInfo.fromJson(json);
      final updated = c.copyWith(photoUrl: 'https://new.url/p.jpg');
      expect(updated.photoUrl, 'https://new.url/p.jpg');
      expect(updated.studentName, c.studentName);
      expect(updated.studentId, c.studentId);
    });
  });

  // ── Child switcher index ──────────────────────────────────────────────────
  group('Child switcher index', () {
    _ChildInfo child(String studentId, String name) => _ChildInfo(
          linkId: studentId, studentId: studentId, schoolId: 's',
          studentName: name, admissionNumber: '', schoolName: '', schoolCode: '', relationType: 'parent');
    final children = [child('A', 'Aarav'), child('B', 'Bina'), child('C', 'Charu')];

    test('null target keeps current index', () => expect(_targetChildIdx(children, null, 1), 1));
    test('matching studentId returns index', () => expect(_targetChildIdx(children, 'B', 0), 1));
    test('first child match returns 0', () => expect(_targetChildIdx(children, 'A', 2), 0));
    test('unknown studentId falls back to current', () => expect(_targetChildIdx(children, 'X', 2), 2));
    test('last child match', () => expect(_targetChildIdx(children, 'C', 0), 2));
  });

  // ── AttendanceRecord ──────────────────────────────────────────────────────
  group('AttendanceRecord.fromJson', () {
    test('parses present record', () {
      final r = _AttendanceRecord.fromJson({'date': '2026-07-01', 'status': 'present'});
      expect(r.date, '2026-07-01');
      expect(r.status, 'present');
    });
    test('status defaults to unknown', () {
      final r = _AttendanceRecord.fromJson({'date': '2026-07-01'});
      expect(r.status, 'unknown');
    });
    test('all status values', () {
      for (final s in ['present', 'absent', 'late', 'holiday']) {
        final r = _AttendanceRecord.fromJson({'date': '2026-07-01', 'status': s});
        expect(r.status, s);
      }
    });
  });

  // ── AttendanceSummary ─────────────────────────────────────────────────────
  group('AttendanceSummary.fromJson', () {
    final json = {
      'summary': {'present': 18, 'absent': 3, 'late': 1, 'total': 22},
      'records': [
        {'date': '2026-07-01', 'status': 'present'},
        {'date': '2026-07-02', 'status': 'absent'},
        {'date': '2026-07-03', 'status': 'late'},
      ],
    };
    test('parses summary counts', () {
      final s = _AttendanceSummary.fromJson(json);
      expect(s.present, 18);
      expect(s.absent, 3);
      expect(s.late, 1);
      expect(s.total, 22);
    });
    test('parses records list', () {
      final s = _AttendanceSummary.fromJson(json);
      expect(s.records.length, 3);
      expect(s.records[0].status, 'present');
      expect(s.records[1].status, 'absent');
    });
    test('attendancePct correct', () {
      final s = _AttendanceSummary.fromJson(json);
      expect(s.attendancePct, closeTo(18 / 22, 0.001));
    });
    test('attendancePct = 0 when total = 0', () {
      final s = _AttendanceSummary.fromJson({});
      expect(s.attendancePct, 0.0);
    });
    test('empty records and summary default to zero', () {
      final s = _AttendanceSummary.fromJson({});
      expect(s.present, 0);
      expect(s.records, isEmpty);
    });
  });

  // ── TestResult.fromJson ───────────────────────────────────────────────────
  group('TestResult.fromJson', () {
    test('parses scored result', () {
      final r = _TestResult.fromJson({
        'id': 'tr-1', 'title': 'Chapter 3 Test', 'subject_name': 'Maths',
        'class_label': '8A', 'total_marks': 50.0, 'marks_obtained': 42.0,
        'percentage': 84.0, 'is_absent': false, 'rank': 3, 'total_students': 30,
      });
      expect(r.id, 'tr-1');
      expect(r.totalMarks, 50.0);
      expect(r.marksObtained, 42.0);
      expect(r.percentage, 84.0);
      expect(r.rank, 3);
      expect(r.totalStudents, 30);
      expect(r.isAbsent, isFalse);
    });
    test('absent student has null marks', () {
      final r = _TestResult.fromJson({'id': '1', 'title': 'T', 'total_marks': 50, 'is_absent': true});
      expect(r.isAbsent, isTrue);
      expect(r.marksObtained, isNull);
      expect(r.percentage, isNull);
    });
    test('totalMarks from int', () {
      final r = _TestResult.fromJson({'id': '1', 'title': 'T', 'total_marks': 100, 'is_absent': false});
      expect(r.totalMarks, 100.0);
    });
    test('rank from num field', () {
      final r = _TestResult.fromJson({'id': '1', 'title': 'T', 'is_absent': false, 'rank': 1.0});
      expect(r.rank, 1);
    });
  });

  // ── WorkLogItem.fromJson ──────────────────────────────────────────────────
  group('WorkLogItem.fromJson', () {
    test('parses full homework log', () {
      final w = _WorkLogItem.fromJson({
        'id': 'wl-1', 'date': '2026-07-10', 'log_type': 'homework',
        'description': 'Ex 3.1', 'due_date': '2026-07-11',
        'section_label': '8A', 'subject_name': 'Maths', 'teacher_name': 'Ravi Sir',
        'submission_id': 'sub-42', 'ack_status': 'completed',
        'image_urls': ['https://gcs.example.com/img1.jpg'],
      });
      expect(w.logType, 'homework');
      expect(w.dueDate, '2026-07-11');
      expect(w.ackStatus, 'completed');
      expect(w.submissionId, 'sub-42');
      expect(w.imageUrls.length, 1);
    });
    test('logType defaults to classwork', () {
      final w = _WorkLogItem.fromJson({'id': '1', 'date': '', 'description': ''});
      expect(w.logType, 'classwork');
    });
    test('ackStatus defaults to pending', () {
      final w = _WorkLogItem.fromJson({'id': '1', 'date': '', 'description': ''});
      expect(w.ackStatus, 'pending');
    });
    test('imageUrls defaults to empty list', () {
      final w = _WorkLogItem.fromJson({'id': '1', 'date': '', 'description': ''});
      expect(w.imageUrls, isEmpty);
    });
    test('submissionId coerced from int', () {
      final w = _WorkLogItem.fromJson({'id': '1', 'date': '', 'description': '', 'submission_id': 99});
      expect(w.submissionId, '99');
    });
  });

  // ── WorkLogItem.isPending ─────────────────────────────────────────────────
  group('WorkLogItem.isPending', () {
    _WorkLogItem make(String ackStatus) => _WorkLogItem(
          id: '1', date: '', logType: 'classwork', description: '', ackStatus: ackStatus);
    test('pending → isPending true', () => expect(make('pending').isPending, isTrue));
    test('seen → isPending true', () => expect(make('seen').isPending, isTrue));
    test('completed → isPending false', () => expect(make('completed').isPending, isFalse));
    test('incomplete → isPending false', () => expect(make('incomplete').isPending, isFalse));
  });

  // ── Work log filter by logType ────────────────────────────────────────────
  group('Work log filter', () {
    final dates = [
      _WorkLogDate(date: '2026-07-10', logs: [
        _WorkLogItem(id: '1', date: '2026-07-10', logType: 'homework', description: 'HW'),
        _WorkLogItem(id: '2', date: '2026-07-10', logType: 'classwork', description: 'CW'),
        _WorkLogItem(id: '3', date: '2026-07-10', logType: 'note', description: 'NT'),
      ]),
      _WorkLogDate(date: '2026-07-11', logs: [
        _WorkLogItem(id: '4', date: '2026-07-11', logType: 'homework', description: 'HW2'),
      ]),
    ];

    test('filter=all returns all dates', () {
      final f = _filterByLogType(dates, 'all');
      expect(f.length, 2);
      expect(f[0].logs.length, 3);
    });
    test('filter=homework returns only homework logs', () {
      final f = _filterByLogType(dates, 'homework');
      expect(f.length, 2);
      expect(f[0].logs.every((l) => l.logType == 'homework'), isTrue);
    });
    test('filter=classwork returns one date with one log', () {
      final f = _filterByLogType(dates, 'classwork');
      expect(f.length, 1);
      expect(f[0].logs.length, 1);
    });
    test('filter with no matches returns empty', () {
      final f = _filterByLogType(dates, 'project');
      expect(f, isEmpty);
    });
    test('filter=note returns only note logs', () {
      final f = _filterByLogType(dates, 'note');
      expect(f.length, 1);
      expect(f[0].logs[0].description, 'NT');
    });
  });

  // ── ParentNotification.fromJson ───────────────────────────────────────────
  group('ParentNotification.fromJson', () {
    test('parses full notification', () {
      final n = _ParentNotification.fromJson({
        'id': 'n-1', 'message': 'Aarav was absent today',
        'notification_type': 'attendance', 'created_at': '2026-07-10T08:00:00Z',
        'teacher_name': 'Ravi Sir',
      });
      expect(n.id, 'n-1');
      expect(n.notificationType, 'attendance');
      expect(n.teacherName, 'Ravi Sir');
    });
    test('notificationType defaults to custom', () {
      final n = _ParentNotification.fromJson({'id': '1', 'message': '', 'created_at': ''});
      expect(n.notificationType, 'custom');
    });
    test('teacherName null when absent', () {
      final n = _ParentNotification.fromJson({'id': '1', 'message': '', 'created_at': ''});
      expect(n.teacherName, isNull);
    });
    test('id coerced from int', () {
      final n = _ParentNotification.fromJson({'id': 55, 'message': '', 'created_at': ''});
      expect(n.id, '55');
    });
  });

  // ── FCM notification routing ──────────────────────────────────────────────
  group('FCM notification routing', () {
    test('attendance → attendance screen', () => expect(_routeFromNotifType('attendance'), 'attendance'));
    test('test_result → tests screen', () => expect(_routeFromNotifType('test_result'), 'tests'));
    test('fee_reminder → fees screen', () => expect(_routeFromNotifType('fee_reminder'), 'fees'));
    test('work_log → work_log screen', () => expect(_routeFromNotifType('work_log'), 'work_log'));
    test('circular → home screen', () => expect(_routeFromNotifType('circular'), 'home'));
    test('unknown → home screen', () => expect(_routeFromNotifType('unknown_type'), 'home'));
  });

  // ── Fee categorisation ────────────────────────────────────────────────────
  group('Fee categorisation', () {
    const ym = '2026-07';
    final fees = [
      {'status': 'overdue', 'fee_month': '2026-05', 'amount': 500},
      {'status': 'overdue', 'fee_month': '2026-06', 'amount': 800},
      {'status': 'unpaid', 'fee_month': '2026-07', 'amount': 1000},
      {'status': 'unpaid', 'fee_month': '2026-08', 'amount': 1000},
      {'status': 'unpaid', 'fee_month': '2026-09', 'amount': 1000},
      {'status': 'paid', 'fee_month': '2026-05', 'amount': 900},
      {'status': 'paid', 'fee_month': '2026-06', 'amount': 900},
    ];

    test('overdue count', () => expect(_overdue(fees).length, 2));
    test('current unpaid (july only)', () => expect(_currentUnpaid(fees, ym).length, 1));
    test('future unpaid (aug+sep)', () => expect(_futureUnpaid(fees, ym).length, 2));
    test('paid count', () => expect(_paid(fees).length, 2));
    test('hasUnpaidDue true with overdue', () => expect(_hasUnpaidDue(fees, ym), isTrue));
    test('hasUnpaidDue true with current-month unpaid only', () {
      final f = [{'status': 'unpaid', 'fee_month': '2026-07', 'amount': 1000}];
      expect(_hasUnpaidDue(f, ym), isTrue);
    });
    test('hasUnpaidDue false with only future unpaid', () {
      final f = [{'status': 'unpaid', 'fee_month': '2026-08', 'amount': 1000}];
      expect(_hasUnpaidDue(f, ym), isFalse);
    });
    test('hasUnpaidDue false with all paid', () {
      final f = [{'status': 'paid', 'fee_month': '2026-07', 'amount': 900}];
      expect(_hasUnpaidDue(f, ym), isFalse);
    });
    test('null fee_month treated as current-or-past', () {
      expect(_isCurrentOrPast({'status': 'unpaid', 'fee_month': null, 'amount': 0}, ym), isTrue);
    });
    test('YYYY-MM-DD fee_month substring works', () {
      expect(_isCurrentOrPast({'fee_month': '2026-06-01'}, ym), isTrue);
      expect(_isCurrentOrPast({'fee_month': '2026-08-01'}, ym), isFalse);
    });
    test('totalAmount sums correctly', () {
      final items = _overdue(fees);
      expect(_totalAmount(items), 1300.0);
    });
    test('totalAmount of empty list is 0', () => expect(_totalAmount([]), 0.0));
  });

  // ── ForumPost.fromJson ────────────────────────────────────────────────────
  group('ForumPost.fromJson', () {
    test('parses full post', () {
      final p = _ForumPost.fromJson({
        'id': 'p-1', 'title': 'Annual Day', 'body': '20th July',
        'audience': 'parents', 'is_pinned': true, 'allow_comments': true,
        'created_at': '2026-07-05', 'author_name': 'Principal',
        'comment_count': 8, 'like_count': 20, 'liked_by_me': true,
      });
      expect(p.isPinned, isTrue);
      expect(p.likeCount, 20);
      expect(p.likedByMe, isTrue);
      expect(p.authorName, 'Principal');
    });
    test('defaults when absent', () {
      final p = _ForumPost.fromJson({'id': '1', 'title': '', 'body': '', 'created_at': ''});
      expect(p.audience, 'all');
      expect(p.likeCount, 0);
      expect(p.likedByMe, isFalse);
    });
    test('id coerced from int', () {
      final p = _ForumPost.fromJson({'id': 123, 'title': '', 'body': '', 'created_at': ''});
      expect(p.id, '123');
    });
  });

  // ── ForumComment.fromJson ─────────────────────────────────────────────────
  group('ForumComment.fromJson', () {
    test('top-level comment', () {
      final c = _ForumComment.fromJson({
        'id': 'c-1', 'body': 'Nice!', 'author_name': 'Sunita', 'created_at': '', 'like_count': 2,
      });
      expect(c.parentId, isNull);
      expect(c.likeCount, 2);
    });
    test('reply with parentId', () {
      final c = _ForumComment.fromJson({'id': 'c-2', 'body': '', 'created_at': '', 'parent_id': 'c-1'});
      expect(c.parentId, 'c-1');
    });
    test('defaults likeCount=0, likedByMe=false', () {
      final c = _ForumComment.fromJson({'id': 'c', 'body': '', 'created_at': ''});
      expect(c.likeCount, 0);
      expect(c.likedByMe, isFalse);
    });
  });

  // ── Forum optimistic like ─────────────────────────────────────────────────
  group('Forum optimistic like', () {
    test('like: +1 count, true flag', () {
      bool liked = false; int count = 10;
      liked = !liked; count += liked ? 1 : -1;
      expect(liked, isTrue); expect(count, 11);
    });
    test('unlike: -1 count, false flag', () {
      bool liked = true; int count = 11;
      liked = !liked; count += liked ? 1 : -1;
      expect(liked, isFalse); expect(count, 10);
    });
    test('API error rollback', () {
      bool liked = false; int count = 10;
      final was = liked;
      liked = !liked; count += liked ? 1 : -1;
      liked = was; count += was ? 1 : -1;
      expect(liked, isFalse); expect(count, 10);
    });
  });

  // ── Feature flags ─────────────────────────────────────────────────────────
  group('FeatureFlags', () {
    test('all enabled by default (empty map)', () {
      final f = _FeatureFlags.fromJson({});
      expect(f.fees, isTrue);
      expect(f.transport, isTrue);
      expect(f.workLogs, isTrue);
      expect(f.forum, isTrue);
    });
    test('fees disabled when feature.parent_fees=false', () {
      final f = _FeatureFlags.fromJson({'feature.parent_fees': false});
      expect(f.fees, isFalse);
    });
    test('fees disabled when sa.fees_module=false', () {
      final f = _FeatureFlags.fromJson({'sa.fees_module': false});
      expect(f.fees, isFalse);
    });
    test('fees enabled when both true', () {
      final f = _FeatureFlags.fromJson({'feature.parent_fees': true, 'sa.fees_module': true});
      expect(f.fees, isTrue);
    });
    test('transport disabled when sa.transport_module=false', () {
      final f = _FeatureFlags.fromJson({'sa.transport_module': false});
      expect(f.transport, isFalse);
    });
    test('workLogs disabled when feature.work_logs=false', () {
      final f = _FeatureFlags.fromJson({'feature.work_logs': false});
      expect(f.workLogs, isFalse);
    });
    test('forum disabled when feature.announcements=false', () {
      final f = _FeatureFlags.fromJson({'feature.announcements': false});
      expect(f.forum, isFalse);
    });
  });
}
