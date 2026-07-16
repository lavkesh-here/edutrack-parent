import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class ChildSummaryScreen extends StatefulWidget {
  final ChildInfo child;
  final void Function(String photoUrl)? onPhotoUpdated;

  const ChildSummaryScreen({super.key, required this.child, this.onPhotoUpdated});

  @override
  State<ChildSummaryScreen> createState() => _ChildSummaryScreenState();
}

class _ChildSummaryScreenState extends State<ChildSummaryScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _profile;
  AttendanceSummary? _attendance;
  List<TestResult> _tests = [];
  List<WorkLogItem> _workLogs = [];
  bool _loading = true;
  String? _error;
  bool _uploading = false;
  String? _photoUrl;
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 7, vsync: this);
    _photoUrl = widget.child.photoUrl;
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final now = DateTime.now();
      final results = await Future.wait([
        ParentApiClient.getChildProfile(widget.child.studentId),
        ParentApiClient.getAttendance(widget.child.studentId, month: now.month, year: now.year),
        ParentApiClient.getTests(widget.child.studentId),
        ParentApiClient.getWorkLogs(widget.child.studentId, days: 30),
      ]);
      if (mounted) {
        setState(() {
          _profile = results[0] as Map<String, dynamic>;
          _attendance = results[1] as AttendanceSummary;
          _tests = (results[2] as List<TestResult>).toList();
          final logDates = results[3] as List<WorkLogDate>;
          _workLogs = logDates.expand((d) => d.logs).toList();
          _photoUrl = _profile?['photo_url'] as String? ?? _photoUrl;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 800);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      if (mounted) showSnack(context, 'Image must be under 5MB', error: true);
      return;
    }
    final ext = file.path.split('.').last.toLowerCase();
    final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
    setState(() => _uploading = true);
    try {
      final resp = await ParentApiClient.getChildPhotoUploadUrl(
        widget.child.studentId,
        filename: file.name,
        contentType: contentType,
        fileSize: bytes.lengthInBytes,
      );
      final uploadUrl = resp['upload_url'] as String;
      final photoUrl = resp['photo_url'] as String;
      final res = await http.put(Uri.parse(uploadUrl), headers: {'Content-Type': contentType}, body: bytes);
      if (res.statusCode >= 300) throw Exception('Upload failed (${res.statusCode})');
      await ParentApiClient.saveChildPhoto(widget.child.studentId, photoUrl);
      setState(() => _photoUrl = photoUrl);
      widget.onPhotoUpdated?.call(photoUrl);
      if (mounted) showSnack(context, 'Photo updated ✓');
    } catch (_) {
      if (mounted) showSnack(context, 'Upload failed', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : _error != null
              ? _errorView()
              : _body(),
    );
  }

  Widget _errorView() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😕', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 12),
            Text(_error ?? 'Failed to load', style: const TextStyle(color: AppColors.muted, fontSize: 14)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );

  Widget _body() {
    final name = widget.child.studentName;
    final classLabel = _profile?['class_label'] as String? ?? widget.child.classLabel ?? '';
    final admNo = _profile?['admission_number'] as String? ?? widget.child.admissionNumber;
    final gender = _profile?['gender'] as String? ?? widget.child.gender;

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          title: Text(
            '$name · $classLabel',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: _buildHeader(name, classLabel, admNo, gender),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyTabBar(_tab),
        ),
      ],
      body: TabBarView(
        controller: _tab,
        children: [
          _profileTab(admNo, gender),
          _attendanceTab(),
          _testsTab(),
          _workLogTab(),
          _ReportCardTab(studentId: widget.child.studentId),
          _SyllabusTab(studentId: widget.child.studentId),
          _ChildCertificatesTab(studentId: widget.child.studentId),
        ],
      ),
    );
  }

  Widget _buildHeader(String name, String classLabel, String admNo, String? gender) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.teal, Color(0xFF0891B2)],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                _ChildAvatar(name: name, photoUrl: _photoUrl, gender: gender, size: 80),
                GestureDetector(
                  onTap: _uploading ? null : _pickAndUploadPhoto,
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.teal.withOpacity(0.3), width: 1.5),
                    ),
                    child: _uploading
                        ? const Padding(
                            padding: EdgeInsets.all(6),
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.teal),
                          )
                        : const Icon(Icons.camera_alt, size: 16, color: AppColors.teal),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 3),
            Text(
              '$classLabel · $admNo',
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileTab(String admNo, String? gender) {
    return RefreshIndicator(
      color: AppColors.teal,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                if (admNo.isNotEmpty) _InfoRow(label: 'Admission No.', value: admNo),
                if (gender != null && gender.isNotEmpty)
                  _InfoRow(label: 'Gender', value: _capitalize(gender)),
                if (_profile?['dob'] != null)
                  _InfoRow(label: 'Date of Birth', value: _fmtDate(_profile!['dob'] as String)),
                if (_profile?['guardian_name'] != null)
                  _InfoRow(label: 'Guardian', value: _profile!['guardian_name'] as String),
                if (_profile?['guardian_phone'] != null)
                  _InfoRow(label: 'Guardian Phone', value: _profile!['guardian_phone'] as String),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _attendanceTab() {
    if (_attendance == null) {
      return const Center(child: Text('No attendance data', style: TextStyle(color: AppColors.muted)));
    }
    final pct = _attendance!.total > 0
        ? ((_attendance!.present / _attendance!.total) * 100).round()
        : null;
    return RefreshIndicator(
      color: AppColors.teal,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _StatCard(label: 'Present', value: '${_attendance!.present}', color: AppColors.teal, bg: AppColors.tealLight),
              const SizedBox(width: 8),
              _StatCard(label: 'Absent', value: '${_attendance!.absent}', color: AppColors.coral, bg: AppColors.coralLight),
              const SizedBox(width: 8),
              _StatCard(
                label: 'Attendance',
                value: pct != null ? '$pct%' : '—',
                color: AppColors.sky,
                bg: AppColors.skyLight,
              ),
            ],
          ),
          if (_attendance!.late > 0) ...[
            const SizedBox(height: 8),
            Row(children: [
              _StatCard(label: 'Late', value: '${_attendance!.late}', color: AppColors.amber, bg: AppColors.sunLight),
            ]),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _testsTab() {
    if (_tests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📊', style: TextStyle(fontSize: 36)),
            SizedBox(height: 12),
            Text('No tests yet', style: TextStyle(color: AppColors.muted)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.teal,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _tests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _TestRow(test: _tests[i]),
      ),
    );
  }

  Widget _workLogTab() {
    if (_workLogs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📚', style: TextStyle(fontSize: 36)),
            SizedBox(height: 12),
            Text('No work logs yet', style: TextStyle(color: AppColors.muted)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.teal,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _workLogs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _WorkLogRow(item: _workLogs[i]),
      ),
    );
  }

  String _fmtDate(String raw) {
    try {
      final d = DateTime.parse(raw);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) { return raw; }
  }

  String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// ── Sticky tab bar ────────────────────────────────────────────────────────────

class _StickyTabBar extends SliverPersistentHeaderDelegate {
  final TabController controller;
  const _StickyTabBar(this.controller);

  @override double get minExtent => 49;
  @override double get maxExtent => 49;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: TabBar(
              controller: controller,
              labelColor: AppColors.teal,
              unselectedLabelColor: AppColors.muted,
              indicatorColor: AppColors.teal,
              indicatorWeight: 2,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(text: 'Profile'),
                Tab(text: 'Attendance'),
                Tab(text: 'Tests'),
                Tab(text: 'Work Log'),
                Tab(text: 'Report Card'),
                Tab(text: 'Syllabus'),
                Tab(text: 'Certificates'),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyTabBar old) => false;
}

// ── Child avatar ──────────────────────────────────────────────────────────────

class _ChildAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final String? gender;
  final double size;
  const _ChildAvatar({required this.name, this.photoUrl, this.gender, required this.size});

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  }

  Widget _initialsWidget() {
    final isFemale = gender?.toLowerCase() == 'female';
    final bg = isFemale ? const Color(0xFFF3E8FF) : const Color(0xFFDBEAFE);
    final fg = isFemale ? const Color(0xFF7C3AED) : const Color(0xFF1D4ED8);
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Center(child: Text(_initials, style: TextStyle(fontSize: size * 0.35, fontWeight: FontWeight.w900, color: fg))),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoUrl!,
          width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsWidget(),
        ),
      );
    }
    return _initialsWidget();
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bg;
  const _StatCard({required this.label, required this.value, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text))),
          ],
        ),
      );
}

class _TestRow extends StatelessWidget {
  final TestResult test;
  const _TestRow({required this.test});

  @override
  Widget build(BuildContext context) {
    final pct = test.percentage;
    final Color pctColor = pct == null
        ? AppColors.muted
        : pct >= 75
            ? AppColors.teal
            : pct >= 40
                ? AppColors.amber
                : AppColors.coral;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(test.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text)),
                if (test.subjectName != null && test.subjectName!.isNotEmpty)
                  Text(test.subjectName!, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
              ],
            ),
          ),
          if (test.marksObtained != null && !test.isAbsent)
            Text(
              '${test.marksObtained!.toInt()} / ${test.totalMarks.toInt()}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.text),
            ),
          if (pct != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: pctColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
              child: Text('${pct.round()}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: pctColor)),
            ),
          ],
          if (test.rank != null && test.totalStudents != null && test.totalStudents! > 1) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.violetLight, borderRadius: BorderRadius.circular(6)),
              child: Text(
                '#${test.rank} / ${test.totalStudents}',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.violet),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Report Card Tab ───────────────────────────────────────────────────────────

class _ReportCardTab extends StatefulWidget {
  final String studentId;
  const _ReportCardTab({required this.studentId});

  @override
  State<_ReportCardTab> createState() => _ReportCardTabState();
}

class _ReportCardTabState extends State<_ReportCardTab>
    with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  bool _pdfLoading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await ParentApiClient.getStudentFullReport(widget.studentId);
      if (mounted) setState(() { _data = r; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _downloadPdf() async {
    if (_pdfLoading) return;
    setState(() => _pdfLoading = true);
    try {
      final base = await ParentApiClient.getBaseUrl();
      final token = await ParentApiClient.exportReportCardToken(widget.studentId);
      final url = Uri.parse('$base/api/v1/parent/child/${widget.studentId}/full-report/pdf?token=$token');
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) showSnack(context, 'Could not open PDF', error: true);
      }
    } catch (_) {
      if (mounted) showSnack(context, 'Failed to download PDF', error: true);
    } finally {
      if (mounted) setState(() => _pdfLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.teal));
    if (_error != null) return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );

    final reportJson = _data?['report_json'] as Map<String, dynamic>?;
    final isStale = _data?['is_stale'] as bool? ?? true;

    if (reportJson == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('📋', style: TextStyle(fontSize: 40)),
              SizedBox(height: 12),
              Text('No report card available yet.\nYour child\'s teacher will generate one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.teal,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // PDF download button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pdfLoading ? null : _downloadPdf,
              icon: _pdfLoading
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.teal))
                  : const Icon(Icons.download_outlined, size: 16),
              label: Text(_pdfLoading ? 'Preparing PDF…' : 'Download PDF', style: const TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.teal,
                side: const BorderSide(color: AppColors.teal),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Stale notice
          if (isStale)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.amber.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Text('⚠️ ', style: TextStyle(fontSize: 14)),
                  Expanded(child: Text('Report may be outdated — ask teacher to regenerate.',
                      style: TextStyle(fontSize: 12, color: AppColors.text2))),
                ],
              ),
            ),

          // Level & trend hero
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.teal, Color(0xFF0891B2)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Holistic Report Card', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _RcBadge(reportJson['overall_level'] as String? ?? '—'),
                    const SizedBox(width: 10),
                    _TrendBadge(reportJson['overall_trend'] as String? ?? ''),
                  ],
                ),
                if ((reportJson['summary'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Text(reportJson['summary'] as String,
                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5)),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Strengths
          const Text('Strengths', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          ...(reportJson['strengths'] as List<dynamic>? ?? []).map((s) =>
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('✅ ', style: TextStyle(fontSize: 13)),
                  Expanded(child: Text(s.toString(), style: const TextStyle(fontSize: 13))),
                ],
              ),
            ),
          ),

          // Focus Areas
          const SizedBox(height: 16),
          const Text('Areas to Work On', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          ...(reportJson['focus_areas'] as List<dynamic>? ?? []).map((f) {
            final fa = f as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fa['area'] as String? ?? '—', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  if ((fa['observation'] as String?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(fa['observation'] as String, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                  if ((fa['action'] as String?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text('What to do: ${fa['action']}',
                        style: const TextStyle(color: AppColors.teal, fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            );
          }),

          // Subject Performance
          const SizedBox(height: 16),
          const Text('Subject Performance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          ...(reportJson['subject_feedback'] as List<dynamic>? ?? []).map((sf) {
            final s = sf as Map<String, dynamic>;
            final avg = (s['avg_pct'] as num?)?.toDouble() ?? 0;
            Color barColor = const Color(0xFF22C55E);
            if (avg < 60) barColor = const Color(0xFFF43F5E);
            else if (avg < 80) barColor = const Color(0xFFFBBF24);
            else if (avg < 90) barColor = AppColors.teal;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(s['subject'] as String? ?? '—', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                      Text('${avg.toStringAsFixed(1)}%', style: TextStyle(color: barColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (avg / 100).clamp(0.0, 1.0),
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      minHeight: 5,
                    ),
                  ),
                  if ((s['feedback'] as String?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    Text(s['feedback'] as String, style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4)),
                  ],
                ],
              ),
            );
          }),

          // Parent Message
          if ((reportJson['parent_message'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.teal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.teal.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💬 Message for You', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.teal)),
                  const SizedBox(height: 8),
                  Text(reportJson['parent_message'] as String,
                      style: const TextStyle(fontSize: 13, height: 1.5)),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _RcBadge extends StatelessWidget {
  const _RcBadge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.2),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.4)),
    ),
    child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
  );
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge(this.trend);
  final String trend;

  @override
  Widget build(BuildContext context) {
    final label = switch (trend) {
      'improving' => '↑ Improving',
      'declining' => '↓ Declining',
      'stable' => '→ Stable',
      _ => '— Getting Started',
    };
    return Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600));
  }
}

class _WorkLogRow extends StatelessWidget {
  final WorkLogItem item;
  const _WorkLogRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final isAck = item.ackStatus == 'acknowledged' || item.ackStatus == 'completed';
    final dotColor = switch (item.logType) {
      'homework' => AppColors.coral,
      'note'     => AppColors.amber,
      _          => AppColors.sky,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(item.description, style: const TextStyle(fontSize: 12, color: AppColors.text), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isAck ? AppColors.teal : AppColors.muted).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isAck ? '✓' : 'Pending',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isAck ? AppColors.teal : AppColors.muted),
                ),
              ),
            ],
          ),
          if (item.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: item.imageUrls.map((url) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _openImageViewer(context, item.imageUrls, item.imageUrls.indexOf(url)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      url, width: 56, height: 56, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          width: 56, height: 56, color: AppColors.border,
                          child: const Icon(Icons.broken_image_outlined, size: 18, color: AppColors.muted)),
                    ),
                  ),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Syllabus Tab ──────────────────────────────────────────────────────────────

class _SyllabusTab extends StatefulWidget {
  final String studentId;
  const _SyllabusTab({required this.studentId});

  @override
  State<_SyllabusTab> createState() => _SyllabusTabState();
}

class _SyllabusTabState extends State<_SyllabusTab>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _subjects = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ParentApiClient.getChildSyllabus(widget.studentId);
      if (mounted) setState(() { _subjects = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.teal));
    if (_error != null) return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
    if (_subjects.isEmpty) return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('📖', style: TextStyle(fontSize: 36)),
          SizedBox(height: 12),
          Text('No syllabus data yet.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
        ],
      ),
    );
    return RefreshIndicator(
      color: AppColors.teal,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _subjects.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _SyllabusSubjectCard(subject: _subjects[i]),
      ),
    );
  }
}

class _SyllabusSubjectCard extends StatefulWidget {
  final Map<String, dynamic> subject;
  const _SyllabusSubjectCard({required this.subject});

  @override
  State<_SyllabusSubjectCard> createState() => _SyllabusSubjectCardState();
}

class _SyllabusSubjectCardState extends State<_SyllabusSubjectCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final chapters = (widget.subject['chapters'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final total = (widget.subject['total'] as num?)?.toInt() ?? chapters.length;
    final done = (widget.subject['completed'] as num?)?.toInt() ?? 0;
    final inProg = (widget.subject['in_progress'] as num?)?.toInt() ?? 0;
    final pct = total > 0 ? done / total : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.subject['subject_name'] as String? ?? '—',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text),
                        ),
                      ),
                      Text(
                        '$done/$total',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 18, color: AppColors.muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.teal),
                      minHeight: 5,
                    ),
                  ),
                  if (done > 0 || inProg > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (done > 0) _SyllabusPill('$done done', AppColors.teal, AppColors.tealLight),
                        if (done > 0 && inProg > 0) const SizedBox(width: 6),
                        if (inProg > 0) _SyllabusPill('$inProg in progress', AppColors.amber, AppColors.amberLight),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_expanded && chapters.isNotEmpty) ...[
            const Divider(height: 1, color: AppColors.border),
            ...chapters.map((c) => _SyllabusChapterRow(chapter: c)),
          ],
        ],
      ),
    );
  }
}

class _SyllabusChapterRow extends StatelessWidget {
  final Map<String, dynamic> chapter;
  const _SyllabusChapterRow({required this.chapter});

  @override
  Widget build(BuildContext context) {
    final status = chapter['status'] as String? ?? 'not_started';
    final icon = switch (status) {
      'completed'   => '✅',
      'in_progress' => '🔄',
      _             => '○',
    };
    final textColor = status == 'not_started' ? AppColors.muted : AppColors.text;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              chapter['name'] as String? ?? '—',
              style: TextStyle(fontSize: 12, color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyllabusPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const _SyllabusPill(this.label, this.color, this.bg);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
  );
}

void _openImageViewer(BuildContext context, List<String> urls, int initialIndex) {
  showDialog(
    context: context,
    builder: (_) => Dialog.fullscreen(
      child: Stack(
        children: [
          PageView.builder(
            controller: PageController(initialPage: initialIndex),
            itemCount: urls.length,
            itemBuilder: (_, i) => InteractiveViewer(
              child: Center(
                child: Image.network(urls[i], fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 48, color: AppColors.muted)),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Child certificates tab ────────────────────────────────────────────────────

const _pCertTypeBg = {
  'academic':      Color(0xFFFEF3C7),
  'sports':        Color(0xFFDBEAFE),
  'participation': Color(0xFFCCFBF1),
  'cultural':      Color(0xFFFEE2E2),
  'attendance':    Color(0xFFDCFCE7),
  'custom':        Color(0xFFEDE9FE),
};
const _pCertTypeFg = {
  'academic':      Color(0xFF92400E),
  'sports':        Color(0xFF1E3A8A),
  'participation': Color(0xFF134E4A),
  'cultural':      Color(0xFF7F1D1D),
  'attendance':    Color(0xFF14532D),
  'custom':        Color(0xFF4C1D95),
};
const _pCertEmoji = {
  'academic': '🎓', 'sports': '🏆', 'participation': '🎗️',
  'cultural': '🎭', 'attendance': '📅', 'custom': '📜',
};

class _ChildCertificatesTab extends StatefulWidget {
  final String studentId;
  const _ChildCertificatesTab({required this.studentId});
  @override
  State<_ChildCertificatesTab> createState() => _ChildCertificatesTabState();
}

class _ChildCertificatesTabState extends State<_ChildCertificatesTab>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _certs = [];
  bool _loading = true;
  String? _error;
  final Map<String, bool> _downloading = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ParentApiClientCertificates.getChildCertificates(widget.studentId);
      if (mounted) setState(() { _certs = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${m[d.month-1]} ${d.year}';
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final primary = Theme.of(context).colorScheme.primary;
    if (_loading) return Center(child: CircularProgressIndicator(color: primary));
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    if (_certs.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('🎓', style: TextStyle(fontSize: 40)),
          SizedBox(height: 12),
          Text('No certificates yet', style: TextStyle(fontSize: 14, color: AppColors.muted)),
          SizedBox(height: 4),
          Text('Certificates issued by school will appear here',
            style: TextStyle(fontSize: 12, color: AppColors.muted), textAlign: TextAlign.center),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: _certs.length,
        itemBuilder: (_, i) {
          final c = _certs[i];
          final certId = c['id'] as String;
          final type = c['cert_type'] as String? ?? 'custom';
          final bg = _pCertTypeBg[type] ?? const Color(0xFFEDE9FE);
          final fg = _pCertTypeFg[type] ?? const Color(0xFF4C1D95);
          final emoji = _pCertEmoji[type] ?? '📜';
          final fields = (c['field_values'] as Map?)?.cast<String, dynamic>() ?? {};

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                    child: Text('$emoji ${c['title_text'] ?? 'Certificate'}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
                  ),
                  const Spacer(),
                  Text(_fmtDate(c['issued_at'] as String?),
                    style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                ]),
                const SizedBox(height: 8),
                Text(c['template_name'] as String? ?? '',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                if (c['academic_year'] != null) ...[
                  const SizedBox(height: 2),
                  Text('Academic Year: ${c['academic_year']}',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
                if (fields.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 4, children: fields.entries.map((e) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border)),
                    child: Text('${e.value}', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
                  )).toList()),
                ],
                const SizedBox(height: 8),
                Row(children: [
                  Text('Cert No: ${c['cert_number'] ?? ''}',
                    style: const TextStyle(fontSize: 11, color: AppColors.muted, fontFamily: 'monospace')),
                  const Spacer(),
                  Text('Issued by ${c['issued_by_name'] ?? ''}',
                    style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                ]),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: (_downloading[certId] == true) ? null : () async {
                      setState(() => _downloading[certId] = true);
                      try {
                        final url = await ParentApiClientCertificates.getCertificatePdfUrl(
                          widget.studentId, certId,
                        );
                        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                      } catch (_) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to open certificate PDF')),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _downloading[certId] = false);
                      }
                    },
                    icon: (_downloading[certId] == true)
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.picture_as_pdf_outlined, size: 16),
                    label: Text((_downloading[certId] == true) ? 'Opening…' : 'Download PDF'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primary,
                      side: BorderSide(color: primary.withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}
