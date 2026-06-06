import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class NotificationsScreen extends StatefulWidget {
  final ChildInfo? child;
  const NotificationsScreen({super.key, this.child});

  @override
  State<NotificationsScreen> createState() => _State();
}

class _State extends State<NotificationsScreen> {
  // Teacher broadcast notifications (old parent_notifications table)
  List<ParentNotification> _broadcasts = [];
  // System in-app notifications (parent_inbox table)
  List<Map<String, dynamic>> _inbox = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(NotificationsScreen old) {
    super.didUpdateWidget(old);
    if (old.child?.studentId != widget.child?.studentId) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        if (widget.child != null)
          ParentApiClient.getNotifications(widget.child!.studentId)
        else
          Future.value(<ParentNotification>[]),
        ParentApiClient.getInbox(),
      ]);
      if (mounted) {
        setState(() {
          _broadcasts = results[0] as List<ParentNotification>;
          _inbox = results[1] as List<Map<String, dynamic>>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(int notifId) async {
    try {
      await ParentApiClient.markInboxRead(notifId);
      setState(() {
        final idx = _inbox.indexWhere((n) => n['id'] == notifId);
        if (idx != -1) _inbox[idx] = {..._inbox[idx], 'is_read': true};
      });
    } catch (_) {}
  }

  String _broadcastIcon(String type) {
    switch (type) {
      case 'homework': return '📚';
      case 'attention': return '⚠️';
      case 'announcement': return '📢';
      case 'test_result': return '📊';
      default: return '✉️';
    }
  }

  String _inboxIcon(String type) {
    switch (type) {
      case 'attendance_absent': return '🚨';
      case 'fee_reminder': return '💳';
      case 'fee_overdue': return '⚠️';
      case 'leave_reviewed': return '🗓️';
      default: return '🔔';
    }
  }

  Color _inboxColor(String type) {
    switch (type) {
      case 'attendance_absent': return AppColors.coralLight;
      case 'fee_reminder':
      case 'fee_overdue': return AppColors.amberLight;
      default: return AppColors.tealLight;
    }
  }

  bool get _hasAny => _broadcasts.isNotEmpty || _inbox.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Notifications'), leading: const BackButton()),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : !_hasAny
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🔔', style: TextStyle(fontSize: 48)),
                      SizedBox(height: 12),
                      Text('No notifications yet',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.teal,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      // ── System alerts (parent_inbox) ──────────────────────
                      if (_inbox.isNotEmpty) ...[
                        const _SectionLabel('ALERTS'),
                        ..._inbox.map((n) {
                          final id = n['id'] as int;
                          final title = n['title'] as String? ?? '';
                          final body = n['body'] as String? ?? '';
                          final type = n['notification_type'] as String? ?? '';
                          final isRead = n['is_read'] as bool? ?? false;
                          final date = (n['created_at'] as String? ?? '').split('T').first;
                          return _NotifTile(
                            icon: _inboxIcon(type),
                            iconBg: _inboxColor(type),
                            title: title,
                            subtitle: body,
                            date: fmtDate(date),
                            isRead: isRead,
                            onTap: isRead ? null : () => _markRead(id),
                          );
                        }),
                      ],

                      // ── Teacher broadcasts (parent_notifications) ─────────
                      if (_broadcasts.isNotEmpty) ...[
                        const _SectionLabel('FROM SCHOOL'),
                        ..._broadcasts.map((n) => _NotifTile(
                              icon: _broadcastIcon(n.notificationType),
                              iconBg: AppColors.tealLight,
                              title: n.message,
                              subtitle: n.teacherName != null ? 'by ${n.teacherName}' : null,
                              date: fmtDate(n.createdAt.split('T').first),
                              isRead: true,
                            )),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                color: AppColors.muted, letterSpacing: 1.2)),
      );
}

class _NotifTile extends StatelessWidget {
  final String icon;
  final Color iconBg;
  final String title;
  final String? subtitle;
  final String date;
  final bool isRead;
  final VoidCallback? onTap;

  const _NotifTile({
    required this.icon,
    required this.iconBg,
    required this.title,
    this.subtitle,
    required this.date,
    required this.isRead,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : AppColors.tealLight.withOpacity(0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isRead ? AppColors.border : AppColors.teal.withOpacity(0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                          color: AppColors.text)),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(date, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                      if (!isRead) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 6, height: 6,
                          decoration: const BoxDecoration(
                              color: AppColors.teal, shape: BoxShape.circle),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
