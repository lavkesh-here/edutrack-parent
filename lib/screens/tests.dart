import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class TestsScreen extends StatefulWidget {
  final ChildInfo? child;
  const TestsScreen({super.key, this.child});

  @override
  State<TestsScreen> createState() => _TestsScreenState();
}

class _TestsScreenState extends State<TestsScreen> {
  List<TestResult> _tests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TestsScreen old) {
    super.didUpdateWidget(old);
    if (old.child?.studentId != widget.child?.studentId) _load();
  }

  Future<void> _load() async {
    final child = widget.child;
    if (child == null) { setState(() => _loading = false); return; }
    setState(() => _loading = true);
    try {
      final data = await ParentApiClient.getTests(child.studentId);
      setState(() { _tests = data; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  double get _average {
    final graded = _tests.where((t) => t.percentage != null && !t.isAbsent).toList();
    if (graded.isEmpty) return 0;
    return graded.map((t) => t.percentage!).reduce((a, b) => a + b) / graded.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Test Results', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.text)),
                      Text('Graded tests & marks', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                    ],
                  ),
                  if (!_loading && _tests.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _average >= 60 ? AppColors.tealLight : AppColors.coralLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${_average.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _average >= 60 ? AppColors.teal : AppColors.coral,
                            ),
                          ),
                          Text('Avg', style: TextStyle(fontSize: 9, color: _average >= 60 ? AppColors.teal : AppColors.coral, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
                  : _tests.isEmpty
                      ? const Center(child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('📊', style: TextStyle(fontSize: 48)),
                            SizedBox(height: 12),
                            Text('No graded tests yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                          ],
                        ))
                      : RefreshIndicator(
                          color: AppColors.teal,
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: _tests.length,
                            itemBuilder: (_, i) {
                              final t = _tests[i];
                              return Container(
                                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(t.title,
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text)),
                                        ),
                                        if (t.isAbsent)
                                          statusBadge('absent')
                                        else if (t.marksObtained != null)
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '${t.marksObtained!.toStringAsFixed(0)} / ${t.totalMarks.toStringAsFixed(0)}',
                                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.text),
                                              ),
                                              if (t.percentage != null)
                                                Text(
                                                  '${t.percentage!.toStringAsFixed(1)}%',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: (t.percentage ?? 0) >= 60 ? AppColors.teal : AppColors.coral,
                                                  ),
                                                ),
                                            ],
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        if (t.subjectName != null) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(color: AppColors.violetLight, borderRadius: BorderRadius.circular(6)),
                                            child: Text(t.subjectName!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.violet)),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        if (t.scheduledDate != null)
                                          Text(fmtDate(t.scheduledDate!), style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                                      ],
                                    ),
                                    if (t.remarks != null && t.remarks!.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(t.remarks!, style: const TextStyle(fontSize: 11, color: AppColors.muted, fontStyle: FontStyle.italic)),
                                    ],
                                    // Progress bar
                                    if (!t.isAbsent && t.percentage != null) ...[
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: (t.percentage! / 100).clamp(0.0, 1.0),
                                          backgroundColor: AppColors.bg,
                                          color: (t.percentage ?? 0) >= 60 ? AppColors.teal : AppColors.coral,
                                          minHeight: 4,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
