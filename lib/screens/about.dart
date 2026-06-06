import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('About'), leading: const BackButton()),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [AppColors.teal, Color(0xFF0D9488)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: AppColors.teal.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: const Center(child: Text('👨‍👩‍👧', style: TextStyle(fontSize: 34))),
            ),
            const SizedBox(height: 16),
            const Text('EduTrack Parent', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.text)),
            const SizedBox(height: 4),
            const Text('Version 1.0.0', style: TextStyle(fontSize: 13, color: AppColors.muted)),
            const SizedBox(height: 32),

            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('About EduTrack',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text)),
                  const SizedBox(height: 10),
                  const Text(
                    'EduTrack is a school management platform that helps parents stay connected with their child\'s academic progress. View attendance, test results, homework, and important school communications — all in one place.',
                    style: TextStyle(fontSize: 13, color: AppColors.text2, height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: Column(
                children: [
                  _ContactRow(
                    icon: Icons.email_outlined,
                    label: 'Support Email',
                    value: 'support@edutrack.app',
                    onTap: () => _launch('mailto:support@edutrack.app'),
                  ),
                  const Divider(height: 1, indent: 56),
                  _ContactRow(
                    icon: Icons.language_outlined,
                    label: 'Website',
                    value: 'edutrack.app',
                    onTap: () => _launch('https://edutrack.app'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              '© 2026 EduTrack. All rights reserved.',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _ContactRow({required this.icon, required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: AppColors.teal, size: 20),
        title: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
        subtitle: Text(value, style: const TextStyle(fontSize: 13, color: AppColors.teal, fontWeight: FontWeight.w700)),
        onTap: onTap,
      );
}
