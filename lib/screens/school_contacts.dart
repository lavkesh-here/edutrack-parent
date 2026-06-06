import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class SchoolContactsScreen extends StatefulWidget {
  final List<ChildInfo> children;
  const SchoolContactsScreen({super.key, required this.children});

  @override
  State<SchoolContactsScreen> createState() => _State();
}

class _State extends State<SchoolContactsScreen> {
  final List<Map<String, dynamic>> _contacts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final seen = <int>{};
    final results = <Map<String, dynamic>>[];
    for (final c in widget.children) {
      if (seen.contains(c.schoolId)) continue;
      seen.add(c.schoolId);
      try {
        final data = await ParentApiClient.getSchoolContacts(c.schoolId);
        results.add(data);
      } catch (_) {}
    }
    if (mounted) setState(() { _contacts.addAll(results); _loading = false; });
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('School Contacts'), leading: const BackButton()),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.coral)))
              : _contacts.isEmpty
                  ? const Center(child: Text('No school info available.', style: TextStyle(color: AppColors.muted)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _contacts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _SchoolCard(info: _contacts[i], onLaunch: _launch),
                    ),
    );
  }
}

class _SchoolCard extends StatelessWidget {
  final Map<String, dynamic> info;
  final Future<void> Function(String) onLaunch;

  const _SchoolCard({required this.info, required this.onLaunch});

  @override
  Widget build(BuildContext context) {
    final name = info['name'] as String? ?? '';
    final code = info['code'] as String? ?? '';
    final board = info['board_affiliation'] as String? ?? '';
    final phone = info['phone'] as String?;
    final email = info['email'] as String?;
    final website = info['website'] as String?;
    final address = info['address'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.teal, Color(0xFF0D9488)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                const Text('🏫', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                      Text('$code · $board', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (address != null) _Row(icon: Icons.location_on_outlined, text: address),
                if (phone != null)
                  _TapRow(icon: Icons.phone_outlined, text: phone, onTap: () => onLaunch('tel:$phone')),
                if (email != null)
                  _TapRow(icon: Icons.email_outlined, text: email, onTap: () => onLaunch('mailto:$email')),
                if (website != null)
                  _TapRow(icon: Icons.language_outlined, text: website, onTap: () => onLaunch(website)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Row({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.muted),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.text2))),
          ],
        ),
      );
}

class _TapRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  const _TapRow({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GestureDetector(
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: AppColors.teal),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text,
                    style: const TextStyle(fontSize: 13, color: AppColors.teal, decoration: TextDecoration.underline)),
              ),
            ],
          ),
        ),
      );
}
