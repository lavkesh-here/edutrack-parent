import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class AttendanceScreen extends StatefulWidget {
  final ChildInfo? child;
  const AttendanceScreen({super.key, this.child});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  AttendanceSummary? _data;
  bool _loading = true;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AttendanceScreen old) {
    super.didUpdateWidget(old);
    if (old.child?.studentId != widget.child?.studentId) _load();
  }

  Future<void> _load() async {
    final child = widget.child;
    if (child == null) { setState(() => _loading = false); return; }
    setState(() => _loading = true);
    try {
      final data = await ParentApiClient.getAttendance(child.studentId, month: _month, year: _year);
      setState(() { _data = data; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  static const _months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  void _prevMonth() {
    setState(() {
      _month--;
      if (_month < 1) { _month = 12; _year--; }
    });
    _load();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_year == now.year && _month == now.month) return;
    setState(() {
      _month++;
      if (_month > 12) { _month = 1; _year++; }
    });
    _load();
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
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Attendance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.text)),
                        Text('Monthly record', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  // Month selector
                  Row(
                    children: [
                      IconButton(
                        onPressed: _prevMonth,
                        icon: const Icon(Icons.chevron_left, color: AppColors.text),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      Text('${_months[_month]} $_year',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
                      IconButton(
                        onPressed: _nextMonth,
                        icon: const Icon(Icons.chevron_right, color: AppColors.text),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.teal)))
            else if (_data == null)
              const Expanded(child: Center(child: Text('Could not load attendance', style: TextStyle(color: AppColors.muted))))
            else ...[
              // Summary row
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Row(
                  children: [
                    Expanded(child: _SummaryTile(value: '${_data!.present}', label: 'Present', color: AppColors.teal)),
                    const SizedBox(width: 8),
                    Expanded(child: _SummaryTile(value: '${_data!.absent}', label: 'Absent', color: AppColors.coral)),
                    const SizedBox(width: 8),
                    Expanded(child: _SummaryTile(value: '${_data!.late}', label: 'Late', color: AppColors.amber)),
                    const SizedBox(width: 8),
                    Expanded(child: _SummaryTile(
                      value: _data!.total > 0
                          ? '${(_data!.present / _data!.total * 100).toStringAsFixed(0)}%'
                          : '—',
                      label: 'Rate',
                      color: AppColors.violet,
                    )),
                  ],
                ),
              ),
              Container(height: 1, color: AppColors.border),
              // Records list
              Expanded(
                child: _data!.records.isEmpty
                    ? const Center(child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('📅', style: TextStyle(fontSize: 40)),
                          SizedBox(height: 12),
                          Text('No records for this month', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                        ],
                      ))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: _data!.records.length,
                        itemBuilder: (_, i) {
                          final r = _data!.records[i];
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: AppColors.border)),
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                Text(fmtDate(r.date),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                                const Spacer(),
                                statusBadge(r.status),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String value, label;
  final Color color;
  const _SummaryTile({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
            Text(label, style: const TextStyle(fontSize: 9, color: AppColors.muted, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
