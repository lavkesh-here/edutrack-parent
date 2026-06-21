import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';

class TimetableScreen extends StatefulWidget {
  final String studentId;
  const TimetableScreen({super.key, required this.studentId});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  Map<String, List<dynamic>>? _timetable;
  bool _loading = true;
  String? _error;

  static const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ParentApiClient.getChildTimetable(widget.studentId);
      setState(() { _timetable = Map<String, List<dynamic>>.from(
        data.map((k, v) => MapEntry(k, List<dynamic>.from(v as List)))
      ); _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _days.where((d) => _timetable?.containsKey(d) ?? true).length,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text('Timetable'),
          backgroundColor: Colors.white,
          bottom: _timetable == null ? null : TabBar(
            isScrollable: true,
            labelColor: AppColors.teal,
            unselectedLabelColor: AppColors.muted,
            indicatorColor: AppColors.teal,
            tabs: _days.where((d) => _timetable!.containsKey(d)).map((d) => Tab(text: d.substring(0, 3))).toList(),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
            : _error != null
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('😕', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _load, child: const Text('Retry')),
                  ]))
                : (_timetable == null || _timetable!.isEmpty)
                    ? const Center(child: Text('No timetable set up yet.', style: TextStyle(color: AppColors.muted)))
                    : TabBarView(
                        children: _days.where((d) => _timetable!.containsKey(d)).map((day) {
                          final slots = _timetable![day] ?? [];
                          return ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: slots.length,
                            itemBuilder: (_, i) {
                              final s = slots[i] as Map<String, dynamic>;
                              final start = s['start_time'] ?? '--';
                              final end = s['end_time'] ?? '--';
                              final subject = s['subject'] ?? 'Unknown';
                              final teacher = s['teacher'] as String?;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(children: [
                                    Container(
                                      width: 56,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(8)),
                                      child: Column(children: [
                                        Text(start, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.teal)),
                                        Text(end, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                                      ]),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(subject, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                                      if (teacher != null) ...[
                                        const SizedBox(height: 2),
                                        Text(teacher, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                      ],
                                    ])),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(6)),
                                      child: Text('P${s['period'] ?? i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted)),
                                    ),
                                  ]),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
      ),
    );
  }
}
