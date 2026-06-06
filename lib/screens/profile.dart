import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'add_child.dart';

class ProfileScreen extends StatelessWidget {
  final List<ChildInfo> children;
  final String parentName;

  const ProfileScreen({super.key, required this.children, required this.parentName});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ParentAuthProvider>();
    final initials = auth.initials;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Hero header
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0C3B36), Color(0xFF134E4A)],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
                child: Column(
                  children: [
                    Container(
                      width: 70, height: 70,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.teal, Color(0xFF0D9488)]),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.25), width: 3),
                      ),
                      child: Center(child: Text(initials,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white))),
                    ),
                    const SizedBox(height: 10),
                    Text(parentName,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 4),
                    const Text('Parent Account',
                        style: TextStyle(fontSize: 12, color: Colors.white60, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // My Children
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('MY CHILDREN',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddChildScreen())),
                          icon: const Icon(Icons.add_rounded, size: 14, color: AppColors.teal),
                          label: const Text('Add Child', style: TextStyle(fontSize: 12, color: AppColors.teal, fontWeight: FontWeight.w700)),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (children.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                        child: const Center(child: Text('No children linked yet. Tap Add Child to get started.',
                            textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 13))),
                      )
                    else
                      ...children.map((c) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                        child: Row(
                          children: [
                            Container(
                              width: 42, height: 42,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [AppColors.teal, Color(0xFF0D9488)]),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(child: Text(c.studentName[0],
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.studentName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text)),
                                  Text('${c.classLabel ?? ''} · ${c.schoolName}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(8)),
                              child: Text(c.schoolCode, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.teal)),
                            ),
                          ],
                        ),
                      )),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Account
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ACCOUNT',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _confirmLogout(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.coral.withOpacity(0.3), width: 1.5),
                        ),
                        child: const Row(
                          children: [
                            _IconBox(icon: '🚪', bg: AppColors.coralLight),
                            SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Sign Out', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.coral)),
                                Text('You will need to sign in again', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              const Center(child: Text('EduTrack Parent v1.0', style: TextStyle(fontSize: 11, color: AppColors.muted))),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('You will need to sign in again to access the app.', style: TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.muted))),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); context.read<ParentAuthProvider>().logout(); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final String icon;
  final Color bg;
  const _IconBox({required this.icon, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
        width: 34, height: 34,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Center(child: Text(icon, style: const TextStyle(fontSize: 15))),
      );
}
