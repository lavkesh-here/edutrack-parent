import 'package:flutter/material.dart';
import '../core/theme.dart';

void showSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
    backgroundColor: error ? AppColors.coral : AppColors.teal,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.all(16),
    duration: const Duration(seconds: 3),
  ));
}

Widget statusBadge(String status) {
  Color bg;
  Color fg;
  switch (status.toLowerCase()) {
    case 'present':
      bg = AppColors.tealLight; fg = AppColors.teal; break;
    case 'absent':
      bg = AppColors.coralLight; fg = AppColors.coral; break;
    case 'late':
      bg = AppColors.amberLight; fg = AppColors.amber; break;
    default:
      bg = AppColors.bg; fg = AppColors.muted;
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Text(
      status[0].toUpperCase() + status.substring(1).toLowerCase(),
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
    ),
  );
}

String fmtDate(String raw) {
  try {
    final d = DateTime.parse(raw);
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month]} ${d.year}';
  } catch (_) {
    return raw;
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.muted,
            letterSpacing: 1,
          ),
        ),
      );
}

class InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String? icon;

  const InfoCard({super.key, required this.label, required this.value, required this.color, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) Text(icon!, style: const TextStyle(fontSize: 18)),
            if (icon != null) const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
