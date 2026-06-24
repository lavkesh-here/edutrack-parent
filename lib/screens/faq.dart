import 'package:flutter/material.dart';
import '../core/theme.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  static const _faqs = [
    ('What is an admission number?',
        'The admission number is a unique ID assigned to your child by the school at the time of enrollment. You can find it on your child\'s school ID card or any official school document.'),
    ('How do I link my child to my account?',
        'Go to Profile → Add Child. Enter your school code, your child\'s admission number, and confirm your password. If the school code and admission number are correct, the child will be linked instantly.'),
    ('Can I link children from multiple schools?',
        'Yes. Tap Add Child from Profile for each child and provide the respective school codes and admission numbers.'),
    ('How often is attendance updated?',
        'Attendance is entered by teachers and is typically updated on the same day. If you see missing data, please contact the school directly.'),
    ('What does the Work Log contain?',
        'Work Log shows homework assignments, classwork notes, and any other academic tasks logged by your child\'s teachers.'),
    ('How do I change my login password?',
        'Go to Settings → Change Password. Enter your current password and choose a new one (minimum 6 characters).'),
    ('I forgot my password. What should I do?',
        'Contact your school admin. They can reset your password from the admin portal and provide you with new temporary credentials.'),
    ('Why can\'t I see test results for my child?',
        'Test results are only visible after the teacher has graded and published the test. If a test shows "—", it may not have been graded yet.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('FAQs'), leading: const BackButton()),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _faqs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final (q, a) = _faqs[i];
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: ExpansionTile(
              key: Key('faq_tile_$i'),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              leading: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(8)),
                child: const Center(child: Text('?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.teal))),
              ),
              title: Text(q, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
              iconColor: AppColors.teal,
              collapsedIconColor: AppColors.muted,
              children: [
                Text(a, style: const TextStyle(fontSize: 13, color: AppColors.text2, height: 1.6)),
              ],
            ),
          );
        },
      ),
    );
  }
}
