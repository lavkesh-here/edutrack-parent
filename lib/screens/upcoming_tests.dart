import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class UpcomingTestsScreen extends StatefulWidget {
  final ChildInfo child;
  const UpcomingTestsScreen({super.key, required this.child});

  @override
  State<UpcomingTestsScreen> createState() => _State();
}

class _State extends State<UpcomingTestsScreen> {
  List<Map<String, dynamic>>? _tests;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ParentApiClient.getUpcomingTests(widget.child.studentId);
      if (mounted) setState(() { _tests = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Upcoming Tests'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : (_tests == null || _tests!.isEmpty)
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('📅', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text(
                        'No upcoming tests',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tests scheduled in the next 7 days will appear here',
                        style: TextStyle(fontSize: 13, color: AppColors.muted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.teal,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tests!.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _TestCard(data: _tests![i]),
                  ),
                ),
    );
  }
}

class _TestCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TestCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? 'Test';
    final subject = data['subject'] as String? ?? '';
    final className = data['class_name'] as String? ?? '';
    final totalMarks = data['total_marks'] as num?;
    final scheduledDate = data['scheduled_date'] as String?;

    final daysLeft = scheduledDate != null ? _daysLeft(scheduledDate) : null;
    final urgencyColor = daysLeft != null
        ? (daysLeft <= 1 ? AppColors.coral : daysLeft <= 3 ? AppColors.amber : AppColors.teal)
        : AppColors.teal;
    final urgencyBg = daysLeft != null
        ? (daysLeft <= 1 ? AppColors.coralLight : daysLeft <= 3 ? AppColors.amberLight : AppColors.tealLight)
        : AppColors.tealLight;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: urgencyBg, borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text('📝', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (subject.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.violetLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(subject, style: const TextStyle(fontSize: 10, color: AppColors.violet, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (className.isNotEmpty)
                      Text(className, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (totalMarks != null) ...[
                      const Icon(Icons.assignment_outlined, size: 12, color: AppColors.muted),
                      const SizedBox(width: 3),
                      Text('$totalMarks marks', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                      const SizedBox(width: 12),
                    ],
                    if (scheduledDate != null) ...[
                      const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.muted),
                      const SizedBox(width: 3),
                      Text(fmtDate(scheduledDate.split('T').first),
                          style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (daysLeft != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: urgencyBg, borderRadius: BorderRadius.circular(8)),
              child: Text(
                daysLeft == 0 ? 'Today' : daysLeft == 1 ? 'Tomorrow' : '$daysLeft days',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: urgencyColor),
              ),
            ),
        ],
      ),
    );
  }

  int _daysLeft(String dateStr) {
    try {
      final d = DateTime.parse(dateStr.split('T').first);
      final now = DateTime.now();
      return d.difference(DateTime(now.year, now.month, now.day)).inDays;
    } catch (_) {
      return 999;
    }
  }
}
