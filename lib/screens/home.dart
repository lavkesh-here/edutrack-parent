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
import 'school_contacts.dart';
import 'student_profile.dart';
import 'settings.dart';
import 'about.dart';
import 'faq.dart';
import 'transport.dart';
import 'fees.dart';
import 'attender.dart';
import 'teachers.dart';
import 'circulars.dart';
import 'timetable.dart';
import 'upcoming_tests.dart';
import 'child_summary.dart';
import 'search.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _homeTabKey = GlobalKey<_HomeTabState>();
  int _idx = 0;
  List<ChildInfo> _children = [];
  int _childIdx = 0;
  bool _loadingProfile = true;
  DateTime? _lastBackPress;
  DateTime? _notifDate;

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
      if (mounted) {
        setState(() { _children = childList; _loadingProfile = false; });
        _handlePendingNavigation();
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  void _handlePendingNavigation() {
    final auth = context.read<ParentAuthProvider>();
    final type = auth.pendingNotifType;
    if (type == null) return;
    final targetStudentId = auth.pendingNotifStudentId;
    final dateStr = auth.pendingNotifDate;
    auth.clearPendingNavigation();

    final child = targetStudentId != null
        ? (_children.firstWhere((c) => c.studentId == targetStudentId, orElse: () => _children.first))
        : _activeChild;
    if (child == null) return;

    final idx = _children.indexOf(child);
    if (idx >= 0 && idx != _childIdx) setState(() => _childIdx = idx);

    DateTime? parsedDate;
    if (dateStr != null) parsedDate = DateTime.tryParse(dateStr);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (type) {
        case 'attendance_absent':
        case 'attendance_present':
        case 'attendance_late':
          setState(() { _idx = 1; _notifDate = parsedDate; });
        case 'test_result':
        case 'test_published':
          setState(() => _idx = 2);
        case 'work_log':
          setState(() { _idx = 3; _notifDate = parsedDate; });
        case 'fee_reminder':
        case 'fee_overdue':
          Navigator.push(context, MaterialPageRoute(builder: (_) => FeesScreen(child: child)));
        case 'circular':
          Navigator.push(context, MaterialPageRoute(builder: (_) => CircularsScreen(child: child)));
        default:
          Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen(child: child)));
      }
    });
  }

  List<Widget> get _screens {
    final child = _activeChild;
    return [
      _HomeTab(
        key: _homeTabKey,
        child: child,
        children: _children,
        childIdx: _childIdx,
        onSwitchChild: (i) => setState(() => _childIdx = i),
        onSwitchTab: (i) => setState(() => _idx = i),
        onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
        onPhotoUpdated: (url) => setState(() {
          if (child != null) {
            _children = _children.map((c) => c.studentId == child.studentId ? c.copyWith(photoUrl: url) : c).toList();
          }
        }),
      ),
      AttendanceScreen(child: child, initialDate: _notifDate),
      TestsScreen(child: child),
      WorkLogScreen(child: child, initialDate: _notifDate),
      ProfileScreen(children: _children, parentName: context.read<ParentAuthProvider>().user?.parentName ?? ''),
    ];
  }

  void _navigate(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final auth = context.read<ParentAuthProvider>();
    return PopScope(
      canPop: false,
      onPopInvoked: (_) {
        // Clear search if active
        final tabState = _homeTabKey.currentState;
        if (tabState != null && tabState._search.isNotEmpty) {
          tabState._clearSearch();
          return;
        }
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
        key: _scaffoldKey,
        drawer: _AppDrawer(
          parentName: auth.user?.parentName ?? '',
          initials: auth.initials,
          onProfile: () { setState(() => _idx = 4); Navigator.pop(context); },
          onSchoolContacts: () { Navigator.pop(context); _navigate(SchoolContactsScreen(children: _children)); },
          onSettings: () { Navigator.pop(context); _navigate(const SettingsScreen()); },
          onFaq: () { Navigator.pop(context); _navigate(const FAQScreen()); },
          onAbout: () { Navigator.pop(context); _navigate(const AboutScreen()); },
          onLogout: () async { Navigator.pop(context); await auth.logout(); },
        ),
        body: _loadingProfile
            ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
            : IndexedStack(index: _idx, children: _screens),
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
                  _NavItem(key: const Key('nav_home'), icon: '🏠', label: 'Home', index: 0, current: _idx, onTap: (i) => setState(() => _idx = i)),
                  _NavItem(key: const Key('nav_attendance'), icon: '📋', label: 'Attendance', index: 1, current: _idx, onTap: (i) => setState(() => _idx = i)),
                  _NavItem(key: const Key('nav_results'), icon: '📊', label: 'Results', index: 2, current: _idx, onTap: (i) => setState(() => _idx = i)),
                  _NavItem(key: const Key('nav_work_log'), icon: '📚', label: 'Work Log', index: 3, current: _idx, onTap: (i) => setState(() => _idx = i)),
                  _NavItem(key: const Key('nav_profile'), icon: '👤', label: 'Profile', index: 4, current: _idx, onTap: (i) => setState(() => _idx = i)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Side Drawer ───────────────────────────────────────────────────────────────

class _AppDrawer extends StatelessWidget {
  final String parentName;
  final String initials;
  final VoidCallback onProfile;
  final VoidCallback onSchoolContacts;
  final VoidCallback onSettings;
  final VoidCallback onFaq;
  final VoidCallback onAbout;
  final VoidCallback onLogout;

  const _AppDrawer({
    required this.parentName,
    required this.initials,
    required this.onProfile,
    required this.onSchoolContacts,
    required this.onSettings,
    required this.onFaq,
    required this.onAbout,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.teal, Color(0xFF0D9488)]),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), shape: BoxShape.circle),
                    child: Center(child: Text(initials, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(parentName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                        const Text('Parent', style: TextStyle(fontSize: 11, color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _DrawerItem(icon: Icons.person_outline, label: 'My Profile', onTap: onProfile),
                  _DrawerItem(icon: Icons.school_outlined, label: 'School Contacts', onTap: onSchoolContacts),
                  const Divider(indent: 16, endIndent: 16),
                  _DrawerItem(icon: Icons.settings_outlined, label: 'Settings', onTap: onSettings),
                  _DrawerItem(icon: Icons.help_outline, label: 'FAQ', onTap: onFaq),
                  _DrawerItem(icon: Icons.info_outline, label: 'About Us', onTap: onAbout),
                ],
              ),
            ),
            const Divider(),
            _DrawerItem(
              icon: Icons.logout,
              label: 'Logout',
              color: AppColors.coral,
              onTap: onLogout,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _DrawerItem({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: color ?? AppColors.text2, size: 22),
        title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color ?? AppColors.text)),
        onTap: onTap,
        dense: true,
      );
}

// ── Child Card Switcher (swipeable PageView) ──────────────────────────────────

// ── Home Tab ──────────────────────────────────────────────────────────────────

class _HomeTab extends StatefulWidget {
  final ChildInfo? child;
  final List<ChildInfo> children;
  final int childIdx;
  final void Function(int) onSwitchChild;
  final void Function(int) onSwitchTab;
  final VoidCallback? onMenuTap;
  final void Function(String url)? onPhotoUpdated;

  const _HomeTab({
    super.key,
    this.child,
    required this.children,
    required this.childIdx,
    required this.onSwitchChild,
    required this.onSwitchTab,
    this.onMenuTap,
    this.onPhotoUpdated,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  AttendanceSummary? _attendance;
  bool _loading = true;
  List<ParentNotification> _recentNotifs = [];
  int _unreadCount = 0;
  String _search = '';
  final _searchCtrl = TextEditingController();
  String? _openSection;
  bool _bioAvailable = false;
  bool _bioEnabled = false;

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() => _search = '');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
    _loadBio();
  }

  Future<void> _loadBio() async {
    final auth = context.read<ParentAuthProvider>();
    final available = await auth.isBiometricAvailable;
    final enabled = await auth.isBiometricEnabled;
    if (mounted) setState(() { _bioAvailable = available; _bioEnabled = enabled; });
  }

  Future<void> _setBioEnabled(bool value) async {
    final auth = context.read<ParentAuthProvider>();
    final confirmed = await auth.authenticateBiometric(
      value ? 'Confirm your biometric to enable quick unlock' : 'Confirm your biometric to disable quick unlock',
    );
    if (!confirmed || !mounted) return;

    if (value) {
      await auth.enableBiometric();
      if (mounted) {
        setState(() => _bioEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric unlock enabled'), backgroundColor: AppColors.teal),
        );
      }
    } else {
      await auth.disableBiometric();
      if (mounted) setState(() => _bioEnabled = false);
    }
  }

  @override
  void didUpdateWidget(_HomeTab old) {
    super.didUpdateWidget(old);
    if (old.child?.studentId != widget.child?.studentId) _load();
  }

  Future<void> _load() async {
    final child = widget.child;
    if (child == null) { if (mounted) setState(() => _loading = false); return; }
    if (mounted) setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final results = await Future.wait([
        ParentApiClient.getAttendance(child.studentId, month: now.month, year: now.year),
        ParentApiClient.getNotifications(child.studentId),
      ]);
      final att = results[0] as AttendanceSummary;
      final notifs = results[1] as List<ParentNotification>;
      if (mounted) setState(() {
        _attendance = att;
        _recentNotifs = notifs.take(5).toList();
        _unreadCount = notifs.length;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showNotifSheet(BuildContext context) {
    setState(() => _unreadCount = 0);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, ctrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recent Notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _push(NotificationsScreen(child: widget.child!));
                    },
                    child: const Text('View All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.teal)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _recentNotifs.isEmpty
                  ? const Center(child: Text('No notifications', style: TextStyle(color: AppColors.muted)))
                  : ListView.separated(
                      controller: ctrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: _recentNotifs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final n = _recentNotifs[i];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n.message, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                              const SizedBox(height: 4),
                              Text(n.teacherName ?? '', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _push(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  Widget _buildAvatar(ChildInfo? child) {
    if (child == null) {
      return Container(
        width: 36, height: 36,
        decoration: const BoxDecoration(color: AppColors.bg, shape: BoxShape.circle),
        child: const Center(child: Icon(Icons.person, color: AppColors.muted, size: 20)),
      );
    }
    final isFemale = child.gender?.toLowerCase() == 'female';
    final avatarBg = isFemale ? const Color(0xFFF3E8FF) : const Color(0xFFDBEAFE);
    final avatarFg = isFemale ? const Color(0xFF7C3AED) : const Color(0xFF1D4ED8);
    String initials(String name) {
      final parts = name.trim().split(' ');
      if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
    }
    if (child.photoUrl != null && child.photoUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          child.photoUrl!,
          width: 36, height: 36, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsCircle(initials(child.studentName), avatarBg, avatarFg),
        ),
      );
    }
    return _initialsCircle(initials(child.studentName), avatarBg, avatarFg);
  }

  Widget _initialsCircle(String text, Color bg, Color fg) => Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Center(child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: fg))),
      );

  List<_Tile> get _allTiles {
    final child = widget.child;
    if (child == null) return [];
    final flags = context.read<ParentAuthProvider>().features;
    return [
      _Tile('📋', 'Attendance', AppColors.teal, AppColors.tealLight, () => widget.onSwitchTab(1), 'ACADEMICS'),
      _Tile('📊', 'Results', AppColors.violet, AppColors.violetLight, () => widget.onSwitchTab(2), 'ACADEMICS'),
      _Tile('📅', 'Upcoming Tests', AppColors.sky, AppColors.skyLight, () => _push(UpcomingTestsScreen(child: child)), 'ACADEMICS'),
      if (flags.workLogs)
        _Tile('📚', 'Work Log', AppColors.sun, AppColors.sunLight, () => widget.onSwitchTab(3), 'ACADEMICS'),
      _Tile('🔔', 'Notifications', AppColors.sky, AppColors.skyLight, () => _push(NotificationsScreen(child: child)), 'COMMUNICATION'),
      if (flags.circulars)
        _Tile('📋', 'Circulars', AppColors.teal, AppColors.tealLight, () => _push(CircularsScreen(child: child)), 'COMMUNICATION'),
      _Tile('🏫', 'School Contacts', AppColors.teal, AppColors.tealLight, () => _push(SchoolContactsScreen(children: widget.children)), 'SCHOOL INFO'),
      _Tile('🎓', 'Student Profile', AppColors.violet, AppColors.violetLight, () => _push(StudentProfileScreen(child: child)), 'SCHOOL INFO'),
      _Tile('👩‍🏫', 'Teachers', AppColors.sky, AppColors.skyLight, () => _push(TeachersScreen(child: child)), 'SCHOOL INFO'),
      _Tile('📅', 'Timetable', AppColors.teal, AppColors.tealLight, () => _push(TimetableScreen(studentId: child.studentId)), 'SCHOOL INFO'),
      if (flags.fees)
        _Tile('💰', 'Fees', AppColors.sun, AppColors.sunLight, () => _push(FeesScreen(child: child)), 'PARENT CORNER'),
      _Tile('👤', 'Attender', AppColors.violet, AppColors.violetLight, () => _push(AttenderScreen(child: child)), 'PARENT CORNER'),
      if (flags.transport)
        _Tile('🚌', 'Transport', AppColors.coral, AppColors.coralLight, () => _push(TransportScreen(child: child)), 'OTHERS'),
      _Tile('🔍', 'Search', AppColors.teal, AppColors.tealLight, () => _push(SearchScreen(child: child)), 'ACCOUNT'),
      _Tile('⚙️', 'Settings', AppColors.muted, AppColors.bg, () => _push(const SettingsScreen()), 'ACCOUNT'),
    ];
  }

  List<_Tile> get _searchResults {
    final q = _search.toLowerCase();
    return _allTiles.where((t) =>
        t.label.toLowerCase().contains(q) || t.section.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;

    return Scaffold(
      key: const Key('home_tab_content'),
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header with child info and prev/next arrows
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: AppColors.text2),
                    onPressed: widget.onMenuTap,
                  ),
                  // Prev arrow
                  if (widget.children.length > 1)
                    IconButton(
                      icon: Icon(Icons.chevron_left,
                          color: widget.childIdx > 0 ? AppColors.teal : AppColors.border, size: 22),
                      onPressed: widget.childIdx > 0
                          ? () => widget.onSwitchChild(widget.childIdx - 1)
                          : null,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28),
                    ),
                  // Avatar + name (tappable → ChildSummaryScreen)
                  GestureDetector(
                    onTap: child != null
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChildSummaryScreen(
                                  child: child,
                                  onPhotoUpdated: widget.onPhotoUpdated,
                                ),
                              ),
                            )
                        : null,
                    child: Row(
                      children: [
                        _buildAvatar(child),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              child?.studentName ?? 'No child linked',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.text),
                            ),
                            if (child != null)
                              Text(
                                '${child.classLabel ?? ''} · ${child.schoolName}',
                                style: const TextStyle(fontSize: 10, color: AppColors.muted),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Next arrow
                  if (widget.children.length > 1)
                    IconButton(
                      icon: Icon(Icons.chevron_right,
                          color: widget.childIdx < widget.children.length - 1 ? AppColors.teal : AppColors.border, size: 22),
                      onPressed: widget.childIdx < widget.children.length - 1
                          ? () => widget.onSwitchChild(widget.childIdx + 1)
                          : null,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28),
                    ),
                  // Notification bell
                  if (widget.child != null)
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined, color: AppColors.text2),
                          onPressed: () => _showNotifSheet(context),
                        ),
                        if (_unreadCount > 0)
                          Positioned(
                            right: 6, top: 6,
                            child: Container(
                              width: 16, height: 16,
                              decoration: const BoxDecoration(color: AppColors.coral, shape: BoxShape.circle),
                              child: Center(child: Text('$_unreadCount', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white))),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),

            Expanded(
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
                            if (child == null) ...[
                              const Padding(
                                padding: EdgeInsets.all(32),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Text('👶', style: TextStyle(fontSize: 48)),
                                      SizedBox(height: 12),
                                      Text('No children linked yet',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                                      SizedBox(height: 8),
                                      Text('Go to Profile → Add Child to link your child\'s account.',
                                          textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                                    ],
                                  ),
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: 12),

                              // Search bar
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: TextField(
                                  controller: _searchCtrl,
                                  maxLength: 10,
                                  onChanged: (v) => setState(() => _search = v),
                                  decoration: InputDecoration(
                                    hintText: 'Search features...',
                                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
                                    counterText: '',
                                    prefixIcon: const Icon(Icons.search, color: AppColors.muted, size: 20),
                                    suffixIcon: _search.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
                                            onPressed: _clearSearch,
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              if (_search.isNotEmpty) ...[
                                // Search results list
                                if (_searchResults.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Center(child: Text('No features found', style: TextStyle(color: AppColors.muted))),
                                  )
                                else
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SectionHeader('SEARCH RESULTS'),
                                        GridView.count(
                                          crossAxisCount: 3,
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          crossAxisSpacing: 10,
                                          mainAxisSpacing: 10,
                                          childAspectRatio: 1.0,
                                          children: _searchResults.map((t) => _GridTile(tile: t)).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                              ] else ...[
                                // Attendance quick stats
                                if (_attendance != null)
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
                                      ],
                                    ),
                                  ),

                                const SizedBox(height: 20),

                                // Feature grid — collapsible sections
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _GridSection(
                                        key: const Key('accordion_attendance'),
                                        title: 'ACADEMICS',
                                        expanded: _openSection == 'ACADEMICS',
                                        onToggle: () => setState(() => _openSection = _openSection == 'ACADEMICS' ? null : 'ACADEMICS'),
                                        tiles: [
                                          _Tile('📋', 'Attendance', AppColors.teal, AppColors.tealLight, () => widget.onSwitchTab(1), 'ACADEMICS'),
                                          _Tile('📊', 'Results', AppColors.violet, AppColors.violetLight, () => widget.onSwitchTab(2), 'ACADEMICS'),
                                          _Tile('📅', 'Upcoming Tests', AppColors.sky, AppColors.skyLight, () => _push(UpcomingTestsScreen(child: child)), 'ACADEMICS'),
                                          _Tile('📚', 'Work Log', AppColors.sun, AppColors.sunLight, () => widget.onSwitchTab(3), 'ACADEMICS'),
                                        ]),
                                      const SizedBox(height: 8),
                                      _GridSection(
                                        key: const Key('accordion_tests'),
                                        title: 'COMMUNICATION',
                                        expanded: _openSection == 'COMMUNICATION',
                                        onToggle: () => setState(() => _openSection = _openSection == 'COMMUNICATION' ? null : 'COMMUNICATION'),
                                        tiles: [
                                          _Tile('🔔', 'Notifications', AppColors.sky, AppColors.skyLight, () => _push(NotificationsScreen(child: child)), 'COMMUNICATION'),
                                          _Tile('📋', 'Circulars', AppColors.teal, AppColors.tealLight, () => _push(CircularsScreen(child: child)), 'COMMUNICATION'),
                                        ]),
                                      const SizedBox(height: 8),
                                      _GridSection(
                                        title: 'SCHOOL INFO',
                                        expanded: _openSection == 'SCHOOL INFO',
                                        onToggle: () => setState(() => _openSection = _openSection == 'SCHOOL INFO' ? null : 'SCHOOL INFO'),
                                        tiles: [
                                          _Tile('🏫', 'School Contacts', AppColors.teal, AppColors.tealLight, () => _push(SchoolContactsScreen(children: widget.children)), 'SCHOOL INFO'),
                                          _Tile('🎓', 'Student Profile', AppColors.violet, AppColors.violetLight, () => _push(StudentProfileScreen(child: child)), 'SCHOOL INFO'),
                                          _Tile('👩‍🏫', 'Teachers', AppColors.sky, AppColors.skyLight, () => _push(TeachersScreen(child: child)), 'SCHOOL INFO'),
                                        ]),
                                      const SizedBox(height: 8),
                                      _GridSection(
                                        title: 'PARENT CORNER',
                                        expanded: _openSection == 'PARENT CORNER',
                                        onToggle: () => setState(() => _openSection = _openSection == 'PARENT CORNER' ? null : 'PARENT CORNER'),
                                        tiles: [
                                          _Tile('💰', 'Fees', AppColors.sun, AppColors.sunLight, () => _push(FeesScreen(child: child)), 'PARENT CORNER'),
                                          _Tile('👤', 'Attender', AppColors.violet, AppColors.violetLight, () => _push(AttenderScreen(child: child)), 'PARENT CORNER'),
                                        ]),
                                      const SizedBox(height: 8),
                                      _GridSection(
                                        title: 'OTHERS',
                                        expanded: _openSection == 'OTHERS',
                                        onToggle: () => setState(() => _openSection = _openSection == 'OTHERS' ? null : 'OTHERS'),
                                        tiles: [
                                          _Tile('🚌', 'Transport', AppColors.coral, AppColors.coralLight, () => _push(TransportScreen(child: child)), 'OTHERS'),
                                        ]),
                                      const SizedBox(height: 8),
                                      _GridSection(
                                        title: 'ACCOUNT',
                                        expanded: _openSection == 'ACCOUNT',
                                        onToggle: () => setState(() => _openSection = _openSection == 'ACCOUNT' ? null : 'ACCOUNT'),
                                        tiles: [
                                          _Tile('🔍', 'Search', AppColors.teal, AppColors.tealLight, () => _push(SearchScreen(child: child)), 'ACCOUNT'),
                                          _Tile('⚙️', 'Settings', AppColors.muted, AppColors.bg, () => _push(const SettingsScreen()), 'ACCOUNT'),
                                        ]),
                                      if (_bioAvailable) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(18),
                                            border: Border.all(color: AppColors.border, width: 1),
                                          ),
                                          child: ListTile(
                                            leading: Container(
                                              width: 38, height: 38,
                                              decoration: BoxDecoration(color: AppColors.violetLight, borderRadius: BorderRadius.circular(10)),
                                              child: const Icon(Icons.fingerprint_rounded, color: AppColors.violet, size: 22),
                                            ),
                                            title: const Text('Biometric Unlock', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                                            subtitle: const Text('Fingerprint or face to unlock app', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                                            trailing: Switch(
                                              value: _bioEnabled,
                                              onChanged: _setBioEnabled,
                                              activeColor: AppColors.teal,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                            ],
                          ],
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

// ── Feature Grid ──────────────────────────────────────────────────────────────

class _Tile {
  final String emoji;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;
  final String section;
  const _Tile(this.emoji, this.label, this.color, this.bg, this.onTap, [this.section = '']);
}

class _GridSection extends StatelessWidget {
  final String title;
  final List<_Tile> tiles;
  final bool expanded;
  final VoidCallback onToggle;
  const _GridSection({super.key, required this.title, required this.tiles, required this.expanded, required this.onToggle});

  static const _meta = {
    'ACADEMICS':      ('📚', AppColors.teal,   AppColors.tealLight),
    'COMMUNICATION':  ('🔔', AppColors.sky,    AppColors.skyLight),
    'SCHOOL INFO':    ('🏫', AppColors.violet, AppColors.violetLight),
    'PARENT CORNER':  ('👨‍👩‍👧', AppColors.sun,    AppColors.sunLight),
    'OTHERS':         ('🚌', AppColors.amber,  AppColors.amberLight),
    'ACCOUNT':        ('⚙️', AppColors.muted,  AppColors.bg),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg) = _meta[title] ?? ('📁', AppColors.muted, AppColors.bg);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: expanded ? color.withOpacity(0.35) : AppColors.border,
          width: expanded ? 1.5 : 1,
        ),
        boxShadow: expanded
            ? [BoxShadow(color: color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))]
            : const [],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
                    child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: expanded ? color : AppColors.text),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: expanded ? color.withOpacity(0.12) : AppColors.bg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${tiles.length}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: expanded ? color : AppColors.muted),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: expanded ? color : AppColors.muted,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: expanded
                ? Column(
                    children: [
                      Divider(height: 1, color: color.withOpacity(0.15)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        child: GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.0,
                          children: tiles.map((t) => _GridTile(tile: t)).toList(),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _GridTile extends StatelessWidget {
  final _Tile tile;
  const _GridTile({required this.tile});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: tile.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: tile.bg, borderRadius: BorderRadius.circular(13)),
                child: Center(child: Text(tile.emoji, style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(height: 8),
              Text(
                tile.label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.text),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
}

// ── Nav Item ──────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final String icon;
  final String label;
  final int index;
  final int current;
  final void Function(int) onTap;

  const _NavItem({super.key, required this.icon, required this.label, required this.index, required this.current, required this.onTap});

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
