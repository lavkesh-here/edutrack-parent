import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class TeachersScreen extends StatefulWidget {
  final ChildInfo child;
  const TeachersScreen({super.key, required this.child});

  @override
  State<TeachersScreen> createState() => _State();
}

class _State extends State<TeachersScreen> {
  List<Map<String, dynamic>> _teachers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ParentApiClient.getTeachers(widget.child.studentId);
      if (mounted) setState(() { _teachers = data; _loading = false; });
    } on ApiError catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load teachers.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Teachers'), leading: const BackButton()),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.coral)))
              : _teachers.isEmpty
                  ? _Empty()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        SectionHeader('${widget.child.classLabel ?? 'CLASS'} TEACHERS'),
                        const SizedBox(height: 8),
                        ..._teachers.map((t) => _TeacherTile(teacher: t)),
                      ],
                    ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('👩‍🏫', style: TextStyle(fontSize: 56)),
              SizedBox(height: 16),
              Text('No Teachers Found', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
              SizedBox(height: 8),
              Text('Teacher assignments have not been set up for this class yet.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      );
}

class _TeacherTile extends StatelessWidget {
  final Map<String, dynamic> teacher;
  const _TeacherTile({required this.teacher});

  @override
  Widget build(BuildContext context) {
    final name = teacher['name']?.toString() ?? '';
    final subject = teacher['subject_name']?.toString() ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.teal, Color(0xFF0D9488)]),
            shape: BoxShape.circle,
          ),
          child: Center(child: Text(initial, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white))),
        ),
        title: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text)),
        subtitle: subject.isNotEmpty
            ? Text(subject, style: const TextStyle(fontSize: 12, color: AppColors.muted))
            : null,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(8)),
          child: Text(subject.isEmpty ? 'Teacher' : subject,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.teal)),
        ),
      ),
    );
  }
}
