import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class StudentProfileScreen extends StatefulWidget {
  final ChildInfo child;
  const StudentProfileScreen({super.key, required this.child});

  @override
  State<StudentProfileScreen> createState() => _State();
}

class _State extends State<StudentProfileScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _parentProfile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ParentApiClient.getChildProfile(widget.child.studentId),
        ParentApiClient.getProfile(),
      ]);
      if (mounted) setState(() {
        _profile = results[0] as Map<String, dynamic>;
        _parentProfile = results[1] as Map<String, dynamic>;
        _loading = false;
      });
    } on ApiError catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load profile.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Student Profile'), leading: const BackButton()),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.coral)))
              : _profile == null
                  ? const SizedBox()
                  : _Body(profile: _profile!, parentProfile: _parentProfile, child: widget.child),
    );
  }
}

class _Body extends StatelessWidget {
  final Map<String, dynamic> profile;
  final Map<String, dynamic>? parentProfile;
  final ChildInfo child;

  const _Body({required this.profile, this.parentProfile, required this.child});

  String _v(String key, [String fallback = '—']) {
    final v = profile[key];
    if (v == null || v.toString().isEmpty) return fallback;
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Avatar card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.teal, Color(0xFF0D9488)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      child.studentName[0].toUpperCase(),
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_v('name'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(_v('class_label'), style: const TextStyle(fontSize: 13, color: Colors.white70)),
                      Text(_v('school_name'), style: const TextStyle(fontSize: 12, color: Colors.white60)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Student info
          _Section(title: 'STUDENT INFORMATION', children: [
            _InfoRow(label: 'Admission No.', value: _v('admission_number')),
            _InfoRow(label: 'Date of Birth', value: _v('dob')),
            _InfoRow(label: 'Gender', value: _v('gender').isEmpty ? '—' : _v('gender')[0].toUpperCase() + _v('gender').substring(1)),
            _InfoRow(label: 'Class', value: _v('class_label')),
            _InfoRow(label: 'School', value: _v('school_name')),
            _InfoRow(label: 'School Code', value: _v('school_code')),
          ]),
          const SizedBox(height: 12),

          // Guardian info
          _Section(title: 'GUARDIAN INFORMATION', children: [
            _InfoRow(label: 'Guardian Name', value: _v('guardian_name')),
            _InfoRow(label: 'Contact', value: _v('guardian_phone')),
          ]),
          const SizedBox(height: 12),

          // Parent details
          if (parentProfile != null)
            _Section(title: 'PARENT DETAILS', children: [
              _InfoRow(label: 'Parent Name', value: parentProfile!['name']?.toString() ?? '—'),
              _InfoRow(label: 'Phone', value: parentProfile!['phone']?.toString() ?? '—'),
              _InfoRow(label: 'Email', value: parentProfile!['email']?.toString().isNotEmpty == true ? parentProfile!['email'].toString() : '—'),
              _InfoRow(label: 'Relation', value: child.relationType),
            ]),
          const SizedBox(height: 12),

        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title),
            ...children,
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontSize: 13, color: AppColors.text, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}
