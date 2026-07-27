import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../core/auth.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'add_child.dart';

class ProfileScreen extends StatefulWidget {
  final List<ChildInfo> children;
  final String parentName;

  const ProfileScreen({super.key, required this.children, required this.parentName});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _appVersion = '';
  bool _uploadingPhoto = false;
  bool _bioAvailable = false;
  bool _bioEnabled = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _appVersion = '${info.version}+${info.buildNumber}');
    });
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

  Future<void> _pickAndUploadPhoto(BuildContext context) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 800);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      if (mounted) showSnack(context, 'Image must be under 5MB', error: true);
      return;
    }
    final ext = file.path.split('.').last.toLowerCase();
    final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
    setState(() => _uploadingPhoto = true);
    try {
      final resp = await ParentApiClient.getProfilePhotoUploadUrl(file.name, contentType, bytes.lengthInBytes);
      final uploadUrl = resp['upload_url'] as String;
      final photoUrl = resp['photo_url'] as String;
      await http.put(Uri.parse(uploadUrl), headers: {'Content-Type': contentType}, body: bytes);
      await ParentApiClient.saveProfilePhotoUrl(photoUrl);
      if (mounted) await context.read<ParentAuthProvider>().updatePhotoUrl(photoUrl);
      if (mounted) showSnack(context, 'Photo updated');
    } catch (e) {
      if (mounted) showSnack(context, 'Upload failed', error: true);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ParentAuthProvider>();
    final initials = auth.initials;
    final children = widget.children;
    final parentName = widget.parentName;

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
                    GestureDetector(
                      onTap: () => _pickAndUploadPhoto(context),
                      child: Stack(
                        children: [
                          Container(
                            width: 90, height: 90,
                            decoration: BoxDecoration(
                              gradient: auth.user?.photoUrl == null
                                  ? const LinearGradient(colors: [AppColors.teal, Color(0xFF0D9488)])
                                  : null,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
                            ),
                            child: ClipOval(
                              child: _uploadingPhoto
                                  ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : auth.user?.photoUrl != null
                                      ? Image.network(auth.user!.photoUrl!, fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Center(child: Text(initials,
                                              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white))))
                                      : Center(child: Text(initials,
                                          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white))),
                            ),
                          ),
                          Positioned(
                            bottom: 2, right: 2,
                            child: Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.teal,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
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
                          key: const Key('add_child_button'),
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
                            _ChildAvatar(child: c, size: 48),
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
                    if (_bioAvailable) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border, width: 1),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(color: AppColors.violetLight, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.fingerprint_rounded, color: AppColors.violet, size: 20),
                          ),
                          title: const Text('Biometric Unlock', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
                          subtitle: const Text('Fingerprint or face to unlock app', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                          trailing: Switch(value: _bioEnabled, onChanged: _setBioEnabled, activeColor: AppColors.teal),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
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
              Center(
                child: Text(
                  _appVersion.isEmpty ? 'EduTrack Parent' : 'EduTrack Parent v$_appVersion',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ),
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
            key: const Key('confirm_sign_out_button'),
            onPressed: () { Navigator.pop(ctx); context.read<ParentAuthProvider>().logout(); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _ChildAvatar extends StatelessWidget {
  final ChildInfo child;
  final double size;
  const _ChildAvatar({required this.child, required this.size});

  @override
  Widget build(BuildContext context) {
    final isFemale = child.gender?.toLowerCase() == 'female';
    final bg = isFemale ? const Color(0xFFF3E8FF) : const Color(0xFFDBEAFE);
    final fg = isFemale ? const Color(0xFF7C3AED) : const Color(0xFF1D4ED8);
    final initial = child.studentName.isNotEmpty ? child.studentName[0].toUpperCase() : '?';
    if (child.photoUrl != null && child.photoUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          child.photoUrl!,
          width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initials(initial, bg, fg),
        ),
      );
    }
    return _initials(initial, bg, fg);
  }

  Widget _initials(String text, Color bg, Color fg) => Container(
        width: size, height: size,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Center(child: Text(text, style: TextStyle(fontSize: size * 0.38, fontWeight: FontWeight.w900, color: fg))),
      );
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
