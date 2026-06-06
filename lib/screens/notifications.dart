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
  List<ParentNotification> _notifications = [];
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
    final child = widget.child;
    if (child == null) { setState(() => _loading = false); return; }
    setState(() => _loading = true);
    try {
      final data = await ParentApiClient.getNotifications(child.studentId);
      setState(() { _notifications = data; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  String _icon(String type) {
    switch (type) {
      case 'homework': return '📚';
      case 'attention': return '⚠️';
      case 'announcement': return '📢';
      case 'test_result': return '📊';
      default: return '✉️';
    }
  }

  Color _bgColor(String type) {
    switch (type) {
      case 'attention': return AppColors.coralLight;
      case 'homework': return AppColors.sunLight;
      case 'test_result': return AppColors.violetLight;
      default: return AppColors.tealLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Notifications'), leading: const BackButton()),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : _notifications.isEmpty
              ? const Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🔔', style: TextStyle(fontSize: 48)),
                    SizedBox(height: 12),
                    Text('No notifications yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                  ],
                ))
              : RefreshIndicator(
                  color: AppColors.teal,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: _notifications.length,
                    itemBuilder: (_, i) {
                      final n = _notifications[i];
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
                              decoration: BoxDecoration(color: _bgColor(n.notificationType), borderRadius: BorderRadius.circular(12)),
                              child: Center(child: Text(_icon(n.notificationType), style: const TextStyle(fontSize: 18))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(n.message, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (n.teacherName != null) ...[
                                        Text('by ${n.teacherName}', style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                                        const Text(' · ', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                                      ],
                                      Text(fmtDate(n.createdAt.split('T').first), style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
