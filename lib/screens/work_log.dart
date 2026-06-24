import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class WorkLogScreen extends StatefulWidget {
  final ChildInfo? child;
  final DateTime? initialDate;
  const WorkLogScreen({super.key, this.child, this.initialDate});

  @override
  State<WorkLogScreen> createState() => _WorkLogScreenState();
}

class _WorkLogScreenState extends State<WorkLogScreen> {
  List<WorkLogDate> _dates = [];
  bool _loading = true;
  String _filter = 'all';
  int _days = 30;

  @override
  void initState() {
    super.initState();
    _applyInitialDate();
    _load();
  }

  void _applyInitialDate() {
    final d = widget.initialDate;
    if (d == null) return;
    final daysAgo = DateTime.now().difference(d).inDays;
    if (daysAgo > 30) _days = daysAgo > 60 ? 90 : 30;
  }

  @override
  void didUpdateWidget(WorkLogScreen old) {
    super.didUpdateWidget(old);
    if (old.child?.studentId != widget.child?.studentId) { _load(); return; }
    final nd = widget.initialDate;
    if (nd != null && nd != old.initialDate) {
      setState(() { _filter = 'all'; });
      _applyInitialDate();
      _load();
    }
  }

  Future<void> _load() async {
    final child = widget.child;
    if (child == null) { setState(() => _loading = false); return; }
    setState(() => _loading = true);
    try {
      final data = await ParentApiClient.getWorkLogs(child.studentId, days: _days);
      setState(() { _dates = data; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() { _filter = 'all'; _days = 30; });
    await _load();
  }

  List<WorkLogDate> get _filtered {
    if (_filter == 'all') return _dates;
    return _dates.map((d) {
      final logs = d.logs.where((l) => l.logType == _filter).toList();
      return WorkLogDate(date: d.date, logs: logs);
    }).where((d) => d.logs.isNotEmpty).toList();
  }

  Future<void> _acknowledge(WorkLogItem item, String status) async {
    final child = widget.child;
    if (child == null) return;
    try {
      await ParentApiClient.acknowledgeWorkLog(child.studentId, item.id, status: status);
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Could not update status', error: true);
    }
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
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Work Log', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.text)),
                            Text('Daily assignments from teachers', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                          ],
                        ),
                      ),
                      // Days filter
                      DropdownButton<int>(
                        value: _days,
                        underline: const SizedBox(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text),
                        items: const [
                          DropdownMenuItem(value: 7, child: Text('7 days')),
                          DropdownMenuItem(value: 30, child: Text('30 days')),
                          DropdownMenuItem(value: 90, child: Text('3 months')),
                        ],
                        onChanged: (v) {
                          if (v != null) { setState(() => _days = v); _load(); }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
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
                          onRefresh: _refresh,
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) => _DateGroup(
                              group: _filtered[i],
                              onAcknowledge: _acknowledge,
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateGroup extends StatefulWidget {
  final WorkLogDate group;
  final Future<void> Function(WorkLogItem, String) onAcknowledge;
  const _DateGroup({required this.group, required this.onAcknowledge});

  @override
  State<_DateGroup> createState() => _DateGroupState();
}

class _DateGroupState extends State<_DateGroup> {
  bool _expanded = true;

  String _fmtGroupDate(String d) {
    try {
      final dt = DateTime.parse(d);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      if (dt.year == today.year && dt.month == today.month && dt.day == today.day) return 'Today';
      if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) return 'Yesterday';
      return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return d;
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.group.logs.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.tealLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(_fmtGroupDate(widget.group.date),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.teal)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(10)),
                  child: Text('$count', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
                const Spacer(),
                Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.teal, size: 20),
              ],
            ),
          ),
        ),
        if (_expanded)
          ...widget.group.logs.map((item) => _WorkLogCard(item: item, onAcknowledge: widget.onAcknowledge)),
      ],
    );
  }
}

class _WorkLogCard extends StatelessWidget {
  final WorkLogItem item;
  final Future<void> Function(WorkLogItem, String) onAcknowledge;
  const _WorkLogCard({required this.item, required this.onAcknowledge});

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

  Widget _ackIndicator() {
    switch (item.ackStatus) {
      case 'completed':
        return const Icon(Icons.check_circle, color: AppColors.teal, size: 18);
      case 'incomplete':
        return const Icon(Icons.cancel, color: AppColors.coral, size: 18);
      default:
        return const Icon(Icons.radio_button_unchecked, color: AppColors.border, size: 18);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPending = item.ackStatus == 'pending' || item.ackStatus == 'seen';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: _logColor(item.logType), borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(_logIcon(item.logType), style: const TextStyle(fontSize: 16))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.description, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (item.subjectName != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.violetLight, borderRadius: BorderRadius.circular(6)),
                            child: Text(item.subjectName!, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.violet)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (item.dueDate != null)
                          Row(children: [
                            const Icon(Icons.event_outlined, size: 11, color: AppColors.coral),
                            const SizedBox(width: 3),
                            Text('Due ${fmtDate(item.dueDate!)}',
                                style: const TextStyle(fontSize: 10, color: AppColors.coral, fontWeight: FontWeight.w700)),
                          ]),
                      ],
                    ),
                    if (item.teacherName != null) ...[
                      const SizedBox(height: 2),
                      Text('by ${item.teacherName}', style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                    ],
                  ],
                ),
              ),
              _ackIndicator(),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                _AckButton(
                  label: 'Done',
                  icon: Icons.check_circle_outline,
                  color: AppColors.teal,
                  onTap: () => onAcknowledge(item, 'completed'),
                ),
                const SizedBox(width: 8),
                _AckButton(
                  label: 'Not Done',
                  icon: Icons.cancel_outlined,
                  color: AppColors.coral,
                  onTap: () => _showIncompleteDialog(context),
                ),
              ],
            ),
          ],
          if (!isPending && item.parentNote != null && item.parentNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(8)),
              child: Text(item.parentNote!, style: const TextStyle(fontSize: 11, color: AppColors.text2, fontStyle: FontStyle.italic)),
            ),
          ],
        ],
      ),
    );
  }

  void _showIncompleteDialog(BuildContext context) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Why was it not done?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        content: TextField(
          key: const Key('incomplete_note_field'),
          controller: noteCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Optional: Add a note for the teacher',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            key: const Key('submit_incomplete_button'),
            onPressed: () {
              Navigator.pop(context);
              onAcknowledge(item, 'incomplete');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

class _AckButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _AckButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      );
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
