import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/auth.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'attendance.dart';
import 'tests.dart';
import 'work_log.dart';
import 'notifications.dart';
import 'profile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _idx = 0;
  List<ChildInfo> _children = [];
  int _childIdx = 0;
  bool _loadingProfile = true;
  DateTime? _lastBackPress;

  ChildInfo? get _activeChild => _children.isNotEmpty ? _children[_childIdx] : null;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await ParentApiClient.getProfile();
      final childList = (data['children'] as List<dynamic>? ?? [])
          .map((e) => ChildInfo.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() { _children = childList; _loadingProfile = false; });
    } catch (_) {
      setState(() => _loadingProfile = false);
    }
  }

  List<Widget> get _screens {
    final child = _activeChild;
    return [
      _HomeTab(child: child),
      AttendanceScreen(child: child),
      TestsScreen(child: child),
      WorkLogScreen(child: child),
      ProfileScreen(children: _children, parentName: context.read<ParentAuthProvider>().user?.parentName ?? ''),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (_) {
        if (_idx != 0) { setState(() => _idx = 0); return; }
        final now = DateTime.now();
        if (_lastBackPress == null || now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Press back again to exit'),
            duration: Duration(seconds: 2),
          ));
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: _loadingProfile
            ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
            : Column(
                children: [
                  // Child switcher bar (visible when multiple children)
                  if (_children.length > 1) _ChildSwitcher(
                    children: _children,
                    activeIdx: _childIdx,
                    onSwitch: (i) => setState(() => _childIdx = i),
                  ),
                  Expanded(child: IndexedStack(index: _idx, children: _screens)),
                ],
              ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border, width: 1)),
            boxShadow: [BoxShadow(color: Color(0x1014B8A6), blurRadius: 20, offset: Offset(0, -4))],
          ),
          child: SafeArea(
            child: SizedBox(
              height: 62,
              child: Row(
                children: [
                  _NavItem(icon: '🏠', label: 'Home', index: 0, current: _idx, onTap: (i) => setState(() => _idx = i)),
                  _NavItem(icon: '📋', label: 'Attendance', index: 1, current: _idx, onTap: (i) => setState(() => _idx = i)),
                  _NavItem(icon: '📊', label: 'Results', index: 2, current: _idx, onTap: (i) => setState(() => _idx = i)),
                  _NavItem(icon: '📚', label: 'Work Log', index: 3, current: _idx, onTap: (i) => setState(() => _idx = i)),
                  _NavItem(icon: '👤', label: 'Profile', index: 4, current: _idx, onTap: (i) => setState(() => _idx = i)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Child Switcher ────────────────────────────────────────────────────────────

class _ChildSwitcher extends StatelessWidget {
  final List<ChildInfo> children;
  final int activeIdx;
  final void Function(int) onSwitch;

  const _ChildSwitcher({required this.children, required this.activeIdx, required this.onSwitch});

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            const Text('Viewing:', style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: children.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final child = children[i];
                    final active = i == activeIdx;
                    return GestureDetector(
                      onTap: () => onSwitch(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: active ? AppColors.teal : AppColors.tealLight,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          child.studentName.split(' ').first,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: active ? Colors.white : AppColors.teal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
}

// ── Home Tab ──────────────────────────────────────────────────────────────────

class _HomeTab extends StatefulWidget {
  final ChildInfo? child;
  const _HomeTab({this.child});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  AttendanceSummary? _attendance;
  List<TestResult> _recentTests = [];
  List<WorkLogItem> _recentLogs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_HomeTab old) {
    super.didUpdateWidget(old);
    if (old.child?.studentId != widget.child?.studentId) _load();
  }

  Future<void> _load() async {
    final child = widget.child;
    if (child == null) { setState(() => _loading = false); return; }
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final results = await Future.wait([
        ParentApiClient.getAttendance(child.studentId, month: now.month, year: now.year),
        ParentApiClient.getTests(child.studentId),
        ParentApiClient.getWorkLogs(child.studentId),
      ]);
      setState(() {
        _attendance = results[0] as AttendanceSummary;
        _recentTests = (results[1] as List<TestResult>).take(3).toList();
        _recentLogs = (results[2] as List<WorkLogItem>).take(5).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
            : RefreshIndicator(
                color: AppColors.teal,
                onRefresh: _load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: Row(
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [AppColors.teal, Color(0xFF0D9488)]),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  child?.studentName[0] ?? '?',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    child?.studentName ?? 'No child linked',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.text),
                                  ),
                                  if (child != null)
                                    Text(
                                      '${child.classLabel ?? ''} · ${child.schoolName}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (child == null) ...[
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Column(
                              children: [
                                Text('👶', style: TextStyle(fontSize: 48)),
                                SizedBox(height: 12),
                                Text('No children linked yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                                SizedBox(height: 8),
                                Text('Go to Profile → Add Child to link your child\'s account.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 16),

                        // Attendance this month
                        if (_attendance != null) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SectionHeader('ATTENDANCE THIS MONTH'),
                                Row(
                                  children: [
                                    Expanded(child: InfoCard(label: 'Present', value: '${_attendance!.present}', color: AppColors.teal, icon: '✅')),
                                    const SizedBox(width: 8),
                                    Expanded(child: InfoCard(label: 'Absent', value: '${_attendance!.absent}', color: AppColors.coral, icon: '❌')),
                                    const SizedBox(width: 8),
                                    Expanded(child: InfoCard(label: 'Late', value: '${_attendance!.late}', color: AppColors.amber, icon: '⏰')),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Attendance %
                                if (_attendance!.total > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      children: [
                                        const Text('Overall Attendance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                                        const Spacer(),
                                        Text(
                                          '${(_attendance!.present / _attendance!.total * 100).toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            fontSize: 16, fontWeight: FontWeight.w900,
                                            color: _attendance!.present / _attendance!.total > 0.75 ? AppColors.teal : AppColors.coral,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Recent tests
                        if (_recentTests.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SectionHeader('RECENT RESULTS'),
                                ..._recentTests.map((t) => Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(t.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
                                            if (t.subjectName != null) Text(t.subjectName!, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                                          ],
                                        ),
                                      ),
                                      if (t.isAbsent)
                                        statusBadge('absent')
                                      else if (t.marksObtained != null)
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text('${t.marksObtained!.toStringAsFixed(0)}/${t.totalMarks.toStringAsFixed(0)}',
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.text)),
                                            if (t.percentage != null)
                                              Text('${t.percentage!.toStringAsFixed(1)}%',
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                                      color: (t.percentage ?? 0) >= 60 ? AppColors.teal : AppColors.coral)),
                                          ],
                                        ),
                                    ],
                                  ),
                                )),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Recent work logs
                        if (_recentLogs.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SectionHeader('RECENT WORK LOG'),
                                ..._recentLogs.map((w) => Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 34, height: 34,
                                        decoration: BoxDecoration(
                                          color: w.logType == 'homework' ? AppColors.sunLight : AppColors.violetLight,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Center(child: Text(w.logType == 'homework' ? '📚' : '✏️', style: const TextStyle(fontSize: 16))),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(w.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text)),
                                            const SizedBox(height: 2),
                                            Text('${w.subjectName ?? ''} · ${fmtDate(w.date)}',
                                                style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                                            if (w.dueDate != null)
                                              Text('Due: ${fmtDate(w.dueDate!)}',
                                                  style: const TextStyle(fontSize: 10, color: AppColors.coral, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

// ── Nav Item ──────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final String icon;
  final String label;
  final int index;
  final int current;
  final void Function(int) onTap;

  const _NavItem({required this.icon, required this.label, required this.index, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: TextStyle(fontSize: active ? 22 : 20)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                color: active ? AppColors.teal : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
