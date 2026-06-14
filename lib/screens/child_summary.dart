import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
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

class _ChildSummaryScreenState extends State<ChildSummaryScreen> {
  Map<String, dynamic>? _profile;
  AttendanceSummary? _attendance;
  List<TestResult> _tests = [];
  List<WorkLogItem> _workLogs = [];
  bool _loading = true;
  String? _error;
  bool _uploading = false;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _photoUrl = widget.child.photoUrl;
    _load();
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
          _tests = ((results[2] as List<TestResult>)).take(5).toList();
          final logDates = results[3] as List<WorkLogDate>;
          _workLogs = logDates.expand((d) => d.logs).take(5).toList();
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
      final resp = await ParentApiClient.getChildPhotoUploadUrl(widget.child.studentId);
      final uploadUrl = resp['upload_url'] as String;
      final photoUrl = resp['photo_url'] as String;
      await http.put(Uri.parse(uploadUrl), headers: {'Content-Type': contentType}, body: bytes);
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

    return CustomScrollView(
      slivers: [
        // Hero header
        SliverAppBar(
          expandedHeight: 240,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
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
                    // Tappable avatar with camera icon
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
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Attendance summary
              if (_attendance != null) ...[
                _SectionHeader('Attendance This Month'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StatCard(label: 'Present', value: '${_attendance!.present}', color: AppColors.teal, bg: AppColors.tealLight),
                    const SizedBox(width: 8),
                    _StatCard(label: 'Absent', value: '${_attendance!.absent}', color: AppColors.coral, bg: AppColors.coralLight),
                    const SizedBox(width: 8),
                    _StatCard(
                      label: 'Attendance',
                      value: _attendance!.total > 0 ? '${((_attendance!.present / _attendance!.total) * 100).round()}%' : '—',
                      color: AppColors.sky,
                      bg: AppColors.skyLight,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Recent tests
              if (_tests.isNotEmpty) ...[
                _SectionHeader('Recent Tests'),
                const SizedBox(height: 8),
                ..._tests.map((t) => _TestRow(test: t)),
                const SizedBox(height: 20),
              ],

              // Recent work logs
              if (_workLogs.isNotEmpty) ...[
                _SectionHeader('Recent Work Logs'),
                const SizedBox(height: 8),
                ..._workLogs.map((w) => _WorkLogRow(item: w)),
                const SizedBox(height: 20),
              ],

              // Profile info
              _SectionHeader('Profile'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _InfoRow(label: 'Admission No.', value: admNo),
                    if (gender != null && gender.isNotEmpty) _InfoRow(label: 'Gender', value: _capitalize(gender)),
                    if (_profile?['dob'] != null) _InfoRow(label: 'Date of Birth', value: _fmtDate(_profile!['dob'] as String)),
                    if (_profile?['guardian_name'] != null) _InfoRow(label: 'Guardian', value: _profile!['guardian_name'] as String),
                    if (_profile?['guardian_phone'] != null) _InfoRow(label: 'Guardian Phone', value: _profile!['guardian_phone'] as String),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ],
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

// ── Child avatar (gender-based initials or photo) ─────────────────────────────

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

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.3),
      );
}

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
            SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted))),
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
    final Color pctColor = pct == null ? AppColors.muted : pct >= 75 ? AppColors.teal : pct >= 40 ? AppColors.amber : AppColors.coral;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
        ],
      ),
    );
  }
}

class _WorkLogRow extends StatelessWidget {
  final WorkLogItem item;
  const _WorkLogRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final isAck = item.ackStatus == 'acknowledged' || item.ackStatus == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: switch (item.logType) { 'homework' => AppColors.coral, 'note' => AppColors.amber, _ => AppColors.sky },
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(item.description, style: const TextStyle(fontSize: 12, color: AppColors.text), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
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
    );
  }
}
