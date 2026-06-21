import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'devices.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _State();
}

class _State extends State<SettingsScreen> {
  bool _expanded = false;
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _error;
  String? _success;
  bool _isProd = true;
  bool _bioEnabled = false;
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    ParentApiClient.getBaseUrl().then((url) {
      if (mounted) setState(() => _isProd = url == ParentApiClient.defaultBaseUrl);
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
    if (!value) {
      await auth.disableBiometric();
      if (mounted) setState(() => _bioEnabled = false);
      return;
    }

    final phone = await auth.getStoredPhone();
    if (phone == null) {
      if (mounted) showSnack(context, 'Sign out and sign in again to enable biometric', error: true);
      return;
    }

    String? password;
    final passCtrl = TextEditingController();
    bool obscure = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            title: const Text('Enable Biometric Unlock', style: TextStyle(fontWeight: FontWeight.w800)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Enter your current password to confirm.', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: obscure,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.muted, size: 18),
                    suffixIcon: GestureDetector(
                      onTap: () => setS(() => obscure = !obscure),
                      child: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: AppColors.muted, size: 18),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enable')),
            ],
          ),
        ),
      );
      password = passCtrl.text;
      if (confirmed != true || password.isEmpty || !mounted) return;
    } finally {
      passCtrl.dispose();
    }

    try {
      await auth.enableBiometric(phone, password!);
      if (mounted) {
        setState(() => _bioEnabled = true);
        showSnack(context, 'Biometric unlock enabled');
      }
    } catch (_) {
      if (mounted) showSnack(context, 'Could not enable biometric. Check your password.', error: true);
    }
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'New passwords do not match');
      return;
    }
    if (_newCtrl.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }

    final proceed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'Changing your password will log out all other active sessions on other devices.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    setState(() { _saving = true; _error = null; _success = null; });
    try {
      await ParentApiClient.changePassword(
        currentPassword: _currentCtrl.text,
        newPassword: _newCtrl.text,
      );
      if (!mounted) return;
      final auth = context.read<ParentAuthProvider>();
      final wasBioEnabled = await auth.isBiometricEnabled;
      if (wasBioEnabled) await auth.disableBiometric();
      setState(() {
        _success = 'Password changed successfully';
        _expanded = false;
        _bioEnabled = false;
      });
      _currentCtrl.clear(); _newCtrl.clear(); _confirmCtrl.clear();
      if (wasBioEnabled && mounted) {
        showSnack(context, 'Biometric unlock disabled — re-enable in Settings with your new password.');
      }
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not change password. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Settings'), leading: const BackButton()),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Change password
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.lock_outline, color: AppColors.teal, size: 20),
                  ),
                  title: const Text('Change Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                  subtitle: const Text('Update your login password', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                  trailing: Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.muted),
                  onTap: () => setState(() { _expanded = !_expanded; _error = null; _success = null; }),
                ),
                if (_expanded) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PassField(label: 'Current Password', ctrl: _currentCtrl, obscure: _obscureCurrent,
                            onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent)),
                        const SizedBox(height: 12),
                        _PassField(label: 'New Password', ctrl: _newCtrl, obscure: _obscureNew,
                            onToggle: () => setState(() => _obscureNew = !_obscureNew)),
                        const SizedBox(height: 12),
                        _PassField(label: 'Confirm New Password', ctrl: _confirmCtrl, obscure: _obscureConfirm,
                            onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm)),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppColors.coralLight, borderRadius: BorderRadius.circular(10)),
                            child: Text(_error!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFBE123C))),
                          ),
                        ],
                        if (_success != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(10)),
                            child: Text(_success!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.teal)),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _changePassword,
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
                            child: _saving
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                : const Text('Update Password'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_success != null && !_expanded)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(_success!, style: const TextStyle(fontSize: 12, color: AppColors.teal, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Biometric toggle
          if (_bioAvailable)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: ListTile(
                leading: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: AppColors.violetLight, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.fingerprint_rounded, color: AppColors.violet, size: 22),
                ),
                title: const Text('Biometric Unlock', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                subtitle: const Text('Use Face ID or fingerprint to sign in', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                trailing: Switch(
                  value: _bioEnabled,
                  onChanged: _setBioEnabled,
                  activeColor: AppColors.teal,
                ),
              ),
            ),

          // Server environment tile
          GestureDetector(
            onTap: () async {
              if (_isProd) {
                // Switch to Dev — prompt for URL
                final current = await ParentApiClient.getBaseUrl();
                final ctrl = TextEditingController(text: current == ParentApiClient.defaultBaseUrl ? '' : current);
                if (!mounted) return;
                final result = await showDialog<String>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Dev Server URL', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('e.g. http://192.168.1.5:8000 or ngrok URL',
                            style: TextStyle(color: AppColors.muted, fontSize: 12)),
                        const SizedBox(height: 12),
                        TextField(controller: ctrl, autocorrect: false, keyboardType: TextInputType.url,
                            decoration: const InputDecoration(hintText: 'http://192.168.x.x:8000')),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Save')),
                    ],
                  ),
                );
                if (result == null || result.isEmpty) return;
                setState(() => _isProd = false);
                await ParentApiClient.setBaseUrl(result);
                if (mounted) showSnack(context, 'Switched to Dev server');
              } else {
                setState(() => _isProd = true);
                await ParentApiClient.setBaseUrl(ParentApiClient.defaultBaseUrl);
                if (mounted) showSnack(context, 'Switched to Production');
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: ListTile(
                leading: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: AppColors.skyLight, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.dns_outlined, color: AppColors.sky, size: 20),
                ),
                title: const Text('Server', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                subtitle: Text(_isProd ? 'Tap to switch to Dev' : 'Tap to switch to Production',
                    style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isProd ? AppColors.tealLight : AppColors.amberLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _isProd ? AppColors.teal.withOpacity(0.3) : AppColors.amber.withOpacity(0.4)),
                  ),
                  child: Text(
                    _isProd ? 'PRODUCTION' : 'DEV',
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800,
                      color: _isProd ? AppColors.teal : AppColors.amber,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Devices
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: ListTile(
              leading: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: AppColors.violetLight, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.phone_android, color: AppColors.violet, size: 20),
              ),
              title: const Text('Logged-in Devices', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
              subtitle: const Text('View and manage active sessions', style: TextStyle(fontSize: 11, color: AppColors.muted)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DevicesScreen())),
            ),
          ),
        ],
      ),
    );
  }
}

class _PassField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool obscure;
  final VoidCallback onToggle;
  const _PassField({required this.label, required this.ctrl, required this.obscure, required this.onToggle});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            obscureText: obscure,
            decoration: InputDecoration(
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.muted, size: 18),
              suffixIcon: GestureDetector(
                onTap: onToggle,
                child: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: AppColors.muted, size: 18),
              ),
            ),
          ),
        ],
      );
}
