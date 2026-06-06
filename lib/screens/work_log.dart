import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class WorkLogScreen extends StatefulWidget {
  final ChildInfo? child;
  const WorkLogScreen({super.key, this.child});

  @override
  State<WorkLogScreen> createState() => _WorkLogScreenState();
}

class _WorkLogScreenState extends State<WorkLogScreen> {
  List<WorkLogItem> _logs = [];
  bool _loading = true;
  String _filter = 'all'; // all | homework | classwork | note

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(WorkLogScreen old) {
    super.didUpdateWidget(old);
    if (old.child?.studentId != widget.child?.studentId) _load();
  }

  Future<void> _load() async {
    final child = widget.child;
    if (child == null) { setState(() => _loading = false); return; }
    setState(() => _loading = true);
    try {
      final data = await ParentApiClient.getWorkLogs(child.studentId);
      setState(() { _logs = data; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<WorkLogItem> get _filtered {
    if (_filter == 'all') return _logs;
    return _logs.where((l) => l.logType == _filter).toList();
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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Work Log', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.text)),
                  const Text('Homework, classwork & notes from teachers', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                  const SizedBox(height: 10),
                  // Filter chips
                  SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _FilterChip(label: 'All', value: 'all', current: _filter, onTap: (v) => setState(() => _filter = v)),
                        const SizedBox(width: 8),
                        _FilterChip(label: '📚 Homework', value: 'homework', current: _filter, onTap: (v) => setState(() => _filter = v)),
                        const SizedBox(width: 8),
                        _FilterChip(label: '✏️ Classwork', value: 'classwork', current: _filter, onTap: (v) => setState(() => _filter = v)),
                        const SizedBox(width: 8),
                        _FilterChip(label: '📝 Notes', value: 'note', current: _filter, onTap: (v) => setState(() => _filter = v)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
                  : _filtered.isEmpty
                      ? const Center(child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('📝', style: TextStyle(fontSize: 48)),
                            SizedBox(height: 12),
                            Text('No work logs yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                          ],
                        ))
                      : RefreshIndicator(
                          color: AppColors.teal,
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) {
                              final w = _filtered[i];
                              return Container(
                                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 38, height: 38,
                                      decoration: BoxDecoration(
                                        color: _logColor(w.logType),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(child: Text(_logIcon(w.logType), style: const TextStyle(fontSize: 18))),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(w.description, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              if (w.subjectName != null) ...[
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(color: AppColors.violetLight, borderRadius: BorderRadius.circular(6)),
                                                  child: Text(w.subjectName!, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.violet)),
                                                ),
                                                const SizedBox(width: 6),
                                              ],
                                              Text(fmtDate(w.date), style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                                            ],
                                          ),
                                          if (w.dueDate != null) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(Icons.event_outlined, size: 12, color: AppColors.coral),
                                                const SizedBox(width: 4),
                                                Text('Due: ${fmtDate(w.dueDate!)}',
                                                    style: const TextStyle(fontSize: 11, color: AppColors.coral, fontWeight: FontWeight.w700)),
                                              ],
                                            ),
                                          ],
                                          if (w.teacherName != null) ...[
                                            const SizedBox(height: 2),
                                            Text('by ${w.teacherName}', style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                                          ],
                                        ],
                                      ),
                                    ),
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

  Color _logColor(String t) {
    switch (t) {
      case 'homework': return AppColors.sunLight;
      case 'classwork': return AppColors.violetLight;
      default: return AppColors.tealLight;
    }
  }

  String _logIcon(String t) {
    switch (t) {
      case 'homework': return '📚';
      case 'classwork': return '✏️';
      default: return '📝';
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label, value, current;
  final void Function(String) onTap;

  const _FilterChip({required this.label, required this.value, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.teal : AppColors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? AppColors.teal : AppColors.border, width: 1.5),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: active ? Colors.white : AppColors.muted)),
      ),
    );
  }
}
