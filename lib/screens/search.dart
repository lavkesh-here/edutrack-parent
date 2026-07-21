import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'notifications.dart';
import 'tests.dart';
import 'work_log.dart';
import 'circulars.dart';
import 'teachers.dart';

class SearchScreen extends StatefulWidget {
  final ChildInfo child;
  const SearchScreen({super.key, required this.child});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  Map<String, dynamic>? _results;
  bool _loading = false;
  String _lastQuery = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final trimmed = q.trim();
    if (trimmed.length < 2 || trimmed == _lastQuery) return;
    _lastQuery = trimmed;
    setState(() { _loading = true; _results = null; _error = null; });
    try {
      final data = await ParentApiClient.globalSearch(widget.child.studentId, trimmed);
      if (mounted) setState(() { _results = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  int get _totalHits {
    if (_results == null) return 0;
    return (_results!['tests'] as List).length +
        (_results!['work_logs'] as List).length +
        (_results!['notifications'] as List).length +
        (_results!['circulars'] as List).length +
        (_results!['teachers'] as List).length +
        ((_results!['fees'] as List?) ?? []).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        titleSpacing: 0,
        title: TextField(
          key: const Key('global_search_field'),
          controller: _ctrl,
          focusNode: _focus,
          onChanged: _search,
          textInputAction: TextInputAction.search,
          onSubmitted: _search,
          style: const TextStyle(fontSize: 15, color: AppColors.text),
          decoration: InputDecoration(
            hintText: 'Search tests, homework, fees, teachers...',
            hintStyle: const TextStyle(fontSize: 14, color: AppColors.muted),
            border: InputBorder.none,
            suffixIcon: _ctrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
                    onPressed: () {
                      _ctrl.clear();
                      setState(() { _results = null; _lastQuery = ''; });
                    },
                  )
                : null,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('⚠️', style: TextStyle(fontSize: 36)),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => _search(_ctrl.text),
                        child: const Text('Retry', style: TextStyle(color: AppColors.teal)),
                      ),
                    ]),
                  ),
                )
              : _results == null
              ? _EmptyState()
              : _totalHits == 0
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('🔍', style: TextStyle(fontSize: 40)),
                          SizedBox(height: 12),
                          Text('No results found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                          SizedBox(height: 4),
                          Text('Try a different keyword', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _ResultSection(
                          label: '📊 Tests',
                          items: (_results!['tests'] as List).cast<Map<String, dynamic>>(),
                          builder: (item) => _TestTile(item: item),
                          onViewAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TestsScreen(child: widget.child))),
                        ),
                        _ResultSection(
                          label: '📚 Homework & Work Logs',
                          items: (_results!['work_logs'] as List).cast<Map<String, dynamic>>(),
                          builder: (item) => _WorkLogTile(item: item),
                          onViewAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkLogScreen(child: widget.child))),
                        ),
                        _ResultSection(
                          label: '🔔 Notifications',
                          items: (_results!['notifications'] as List).cast<Map<String, dynamic>>(),
                          builder: (item) => _NotifTile(item: item),
                          onViewAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen(child: widget.child))),
                        ),
                        _ResultSection(
                          label: '📋 Circulars',
                          items: (_results!['circulars'] as List).cast<Map<String, dynamic>>(),
                          builder: (item) => _CircularTile(item: item),
                          onViewAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CircularsScreen(child: widget.child))),
                        ),
                        _ResultSection(
                          label: '👩‍🏫 Teachers',
                          items: (_results!['teachers'] as List).cast<Map<String, dynamic>>(),
                          builder: (item) => _TeacherTile(item: item),
                          onViewAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TeachersScreen(child: widget.child))),
                        ),
                        _ResultSection(
                          label: '💰 Fees',
                          items: ((_results!['fees'] as List?) ?? []).cast<Map<String, dynamic>>(),
                          builder: (item) => _FeeTile(item: item),
                          onViewAll: () {},
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🔍', style: TextStyle(fontSize: 40)),
            SizedBox(height: 12),
            Text('Search your child\'s school data', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
            SizedBox(height: 4),
            Text('Tests, homework, fees, notifications,\ncirculars, teachers', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.muted)),
          ],
        ),
      );
}

class _ResultSection extends StatelessWidget {
  final String label;
  final List<Map<String, dynamic>> items;
  final Widget Function(Map<String, dynamic>) builder;
  final VoidCallback onViewAll;

  const _ResultSection({
    required this.label,
    required this.items,
    required this.builder,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.5)),
              GestureDetector(
                onTap: onViewAll,
                child: const Text('View all →', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.teal)),
              ),
            ],
          ),
        ),
        ...items.map(builder),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ── Tile widgets ──────────────────────────────────────────────────────────────

class _TestTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _TestTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final pct = item['percentage'] as num?;
    final pctStr = pct != null ? '${pct.toStringAsFixed(0)}%' : 'Not graded';
    final color = pct == null ? AppColors.muted : (pct >= 75 ? AppColors.teal : pct >= 50 ? AppColors.amber : AppColors.coral);
    return _Card(
      icon: '📊',
      iconBg: AppColors.violetLight,
      title: item['title'] as String? ?? '',
      sub: item['subject_name'] as String? ?? '',
      trailing: Text(pctStr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

class _WorkLogTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _WorkLogTile({required this.item});

  @override
  Widget build(BuildContext context) => _Card(
        icon: '📚',
        iconBg: AppColors.sunLight,
        title: item['description'] as String? ?? '',
        sub: '${item['subject_name'] ?? ''} · ${fmtDate(item['date'] as String? ?? '')}',
        trailing: null,
      );
}

class _NotifTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _NotifTile({required this.item});

  @override
  Widget build(BuildContext context) => _Card(
        icon: '🔔',
        iconBg: AppColors.skyLight,
        title: item['message'] as String? ?? '',
        sub: item['teacher_name'] as String? ?? '',
        trailing: null,
      );
}

class _CircularTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _CircularTile({required this.item});

  @override
  Widget build(BuildContext context) => _Card(
        icon: '📋',
        iconBg: AppColors.tealLight,
        title: item['title'] as String? ?? '',
        sub: fmtDate((item['created_at'] as String? ?? '').split('T').first),
        trailing: null,
      );
}

class _TeacherTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _TeacherTile({required this.item});

  @override
  Widget build(BuildContext context) => _Card(
        icon: '👩‍🏫',
        iconBg: AppColors.violetLight,
        title: item['name'] as String? ?? '',
        sub: item['subject_name'] as String? ?? '',
        trailing: null,
      );
}

class _FeeTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _FeeTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final status = item['status'] as String? ?? 'pending';
    final amount = item['amount'] as num? ?? 0;
    final paid = item['paid_amount'] as num? ?? 0;
    final color = status == 'paid' ? AppColors.teal : status == 'partial' ? AppColors.amber : AppColors.coral;
    final statusLabel = status == 'paid' ? 'Paid' : status == 'partial' ? '₹$paid paid' : 'Pending';
    return _Card(
      icon: '💰',
      iconBg: AppColors.amberLight,
      title: item['fee_type'] as String? ?? '',
      sub: '₹${amount.toStringAsFixed(0)} · Due ${fmtDate(item['due_date'] as String? ?? '')}',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
        child: Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String icon;
  final Color iconBg;
  final String title;
  final String sub;
  final Widget? trailing;

  const _Card({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.sub,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text), maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      );
}
