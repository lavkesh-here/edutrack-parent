import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _State();
}

class _State extends State<DevicesScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final data = await ParentApiClient.getDevices();
      if (mounted) setState(() { _sessions = data; _loading = false; });
    } on ApiError catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load devices.'; _loading = false; });
    }
  }

  Future<void> _remove(String id) async {
    try {
      await ParentApiClient.removeDevice(id);
      setState(() => _sessions.removeWhere((s) => s['id'] == id));
      if (mounted) showSnack(context, 'Device removed');
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) showSnack(context, 'Could not remove device.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Logged-in Devices'), leading: const BackButton()),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.coral)))
              : _sessions.isEmpty
                  ? _Empty()
                  : RefreshIndicator(
                      color: AppColors.teal,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const SectionHeader('ACTIVE SESSIONS'),
                          ..._sessions.map((s) => _DeviceTile(session: s, onRemove: () => _remove(s['id'].toString()))),
                        ],
                      ),
                    ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('📱', style: TextStyle(fontSize: 56)),
              SizedBox(height: 16),
              Text('No Devices Found', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
              SizedBox(height: 8),
              Text('No login sessions recorded yet.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      );
}

class _DeviceTile extends StatelessWidget {
  final Map<String, dynamic> session;
  final VoidCallback onRemove;
  const _DeviceTile({required this.session, required this.onRemove});

  String _lastActive() {
    final s = session['last_active']?.toString() ?? '';
    if (s.isEmpty) return '—';
    try {
      final dt = DateTime.parse(s).toLocal();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return s; }
  }

  @override
  Widget build(BuildContext context) {
    final device = session['device_name']?.toString() ?? 'Unknown Device';
    final os = session['os_version']?.toString() ?? '';
    final app = session['app_version']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: AppColors.skyLight, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.phone_android, color: AppColors.sky, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.text)),
                if (os.isNotEmpty || app.isNotEmpty)
                  Text([if (os.isNotEmpty) os, if (app.isNotEmpty) 'v$app'].join(' · '),
                      style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                Text('Last active: ${_lastActive()}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
          TextButton(
            onPressed: onRemove,
            child: const Text('Remove', style: TextStyle(fontSize: 12, color: AppColors.coral, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
