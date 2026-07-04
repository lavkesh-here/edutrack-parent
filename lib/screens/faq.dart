import 'package:flutter/material.dart';
import '../core/theme.dart';

class FAQScreen extends StatefulWidget {
  const FAQScreen({super.key});

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _openFaqKey;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? _faqSections
        : _faqSections
            .map((s) => _FaqSection(
                  title: s.title,
                  icon: s.icon,
                  items: s.items
                      .where((i) =>
                          i.q.toLowerCase().contains(_query.toLowerCase()) ||
                          i.a.toLowerCase().contains(_query.toLowerCase()))
                      .toList(),
                ))
            .where((s) => s.items.isNotEmpty)
            .toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Help & FAQ'),
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search questions…',
                hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: AppColors.muted, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
                ),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔍', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 12),
                        Text(
                          'No results for "$_query"',
                          style: const TextStyle(color: AppColors.muted, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: filtered.length,
                    itemBuilder: (context, si) {
                      final section = filtered[si];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (si > 0) const SizedBox(height: 16),
                          Row(
                            children: [
                              Text(section.icon, style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Text(
                                section.title.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.muted,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border, width: 1.5),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Column(
                                children: List.generate(section.items.length, (qi) {
                                  final item = section.items[qi];
                                  final isLast = qi == section.items.length - 1;
                                  return Column(
                                    children: [
                                      Theme(
                                        data: Theme.of(context).copyWith(
                                          dividerColor: Colors.transparent,
                                        ),
                                        child: ExpansionTile(
                                          key: ValueKey('faq_${si}_${qi}_$_openFaqKey'),
                                          initiallyExpanded: _openFaqKey == '${si}_$qi',
                                          onExpansionChanged: (expanded) {
                                            setState(() => _openFaqKey = expanded ? '${si}_$qi' : null);
                                          },
                                          tilePadding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 2),
                                          childrenPadding: const EdgeInsets.fromLTRB(
                                              16, 0, 16, 14),
                                          expandedCrossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          iconColor: AppColors.teal,
                                          collapsedIconColor: AppColors.muted,
                                          title: Text(
                                            item.q,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.text,
                                            ),
                                          ),
                                          children: [
                                            Text(
                                              item.a,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: AppColors.text2,
                                                height: 1.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!isLast)
                                        const Divider(
                                          height: 1,
                                          thickness: 1,
                                          color: AppColors.border,
                                          indent: 16,
                                          endIndent: 16,
                                        ),
                                    ],
                                  );
                                }),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Data ─────────────────────────────────────────────────────────────────────

class _FaqItem {
  const _FaqItem(this.q, this.a);
  final String q;
  final String a;
}

class _FaqSection {
  const _FaqSection({required this.title, required this.icon, required this.items});
  final String title;
  final String icon;
  final List<_FaqItem> items;
}

const _faqSections = <_FaqSection>[
  _FaqSection(
    title: 'Getting Started',
    icon: '🚀',
    items: [
      _FaqItem(
        'What is an admission number?',
        'The admission number is a unique ID assigned to your child by the school at enrollment. '
            'You can find it on your child\'s school ID card or any official school document.',
      ),
      _FaqItem(
        'How do I log in?',
        'Enter your registered mobile number and password on the login screen. '
            'Your credentials are set up by your school administrator.',
      ),
      _FaqItem(
        'How do I link my child to my account?',
        'Go to Profile → Add Child. Enter your school code, your child\'s admission number, '
            'and confirm your password. If the details are correct, the child will be linked instantly.',
      ),
      _FaqItem(
        'Can I link children from multiple schools?',
        'Yes. Tap Add Child from Profile for each child and provide the respective '
            'school codes and admission numbers.',
      ),
      _FaqItem(
        'How do I set up fingerprint / face unlock?',
        'Go to Settings → Biometric Unlock and toggle it on. '
            'You will be asked to verify your biometric once to activate it.',
      ),
    ],
  ),
  _FaqSection(
    title: 'Attendance',
    icon: '✅',
    items: [
      _FaqItem(
        'Where can I see my child\'s attendance?',
        'Tap Attendance in the bottom navigation bar. '
            'You will see a monthly calendar with colour-coded days — '
            'green for present, red for absent, yellow for late.',
      ),
      _FaqItem(
        'How often is attendance updated?',
        'Attendance is marked by teachers and is typically updated the same day. '
            'If you see missing data, please contact the school directly.',
      ),
      _FaqItem(
        'What do the different attendance statuses mean?',
        'Present — your child was in school. Absent — your child was not in school. '
            'Late — your child arrived after the start time.',
      ),
    ],
  ),
  _FaqSection(
    title: 'Tests & Scores',
    icon: '📝',
    items: [
      _FaqItem(
        'Where can I see my child\'s test results?',
        'Tap Tests in the bottom navigation bar to see all tests with scores and remarks.',
      ),
      _FaqItem(
        'Why can\'t I see scores for a test?',
        'Scores are only visible after the teacher has graded and saved the results. '
            'If a test shows "—", it may not have been graded yet.',
      ),
      _FaqItem(
        'What does the AI Analysis on a test mean?',
        'The AI Analysis summarises how the class performed, '
            'highlights chapters where your child may need extra practice, '
            'and gives the teacher suggestions for follow-up.',
      ),
      _FaqItem(
        'Where can I see upcoming tests?',
        'Tap the calendar icon or go to the Upcoming Tests section on the home screen '
            'to see all scheduled tests for your child\'s classes.',
      ),
    ],
  ),
  _FaqSection(
    title: 'Work Log & Homework',
    icon: '📚',
    items: [
      _FaqItem(
        'What is the Work Log?',
        'Work Log shows classwork notes, homework assignments, and any other academic tasks '
            'logged by your child\'s teachers for each subject.',
      ),
      _FaqItem(
        'How do I acknowledge a work log entry?',
        'Open the Work Log entry and tap Acknowledge at the bottom. '
            'This lets the teacher know you have seen the assignment.',
      ),
    ],
  ),
  _FaqSection(
    title: 'Fees',
    icon: '💰',
    items: [
      _FaqItem(
        'Where can I check my child\'s fee status?',
        'Go to the Fees section from the home screen or drawer menu. '
            'You can see outstanding dues, payment history, and fee structure.',
      ),
      _FaqItem(
        'The fee amount looks wrong. What should I do?',
        'Please contact the school\'s accounts office directly. '
            'Fee corrections need to be made by the school administrator.',
      ),
    ],
  ),
  _FaqSection(
    title: 'Notifications',
    icon: '🔔',
    items: [
      _FaqItem(
        'What notifications will I receive?',
        'You will get alerts for new test scores, attendance marked absent, '
            'new circulars from the school, homework assignments, and fee reminders.',
      ),
      _FaqItem(
        'How do I manage which notifications I receive?',
        'Go to Settings → Notification Preferences to turn individual alert types on or off.',
      ),
      _FaqItem(
        'I am not receiving any notifications. What should I do?',
        'Make sure notifications are enabled for EduTrack in your phone\'s Settings → Apps. '
            'Also check that you are not in Do Not Disturb mode.',
      ),
    ],
  ),
  _FaqSection(
    title: 'Account & Settings',
    icon: '⚙️',
    items: [
      _FaqItem(
        'How do I change my password?',
        'Go to Settings → Change Password. Enter your current password and choose a new one.',
      ),
      _FaqItem(
        'I forgot my password. What should I do?',
        'Contact your school administrator. They can reset your password from the admin portal '
            'and provide you with new temporary credentials.',
      ),
      _FaqItem(
        'The text in the app looks too small. What can I do?',
        'You can increase the font size from your phone\'s Settings → Display → Font Size. '
            'The app automatically adjusts to your phone\'s font setting.',
      ),
      _FaqItem(
        'How do I sign out?',
        'Go to Settings and tap Sign Out at the bottom of the page.',
      ),
    ],
  ),
];
