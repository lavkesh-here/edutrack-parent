import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth.dart';
import '../core/api.dart';
import '../core/theme.dart';
import 'force_change_password.dart';

// ── Build flavour ─────────────────────────────────────────────────────────────
// Pass --dart-define=APP_ENV=production at build time for store releases.
// Dev builds show an env picker; production builds hide it entirely.

const bool _kIsProdBuild =
    String.fromEnvironment('APP_ENV', defaultValue: 'dev') == 'production';

class _ServerEnv {
  final String label;
  final String url;
  const _ServerEnv(this.label, this.url);
}

const _kKnownServers = <_ServerEnv>[
  _ServerEnv('Production', ParentApiClient.defaultBaseUrl),
  // Add staging here when available:
  // _ServerEnv('Staging', 'https://edutrack-staging.run.app'),
];

// ── Step 1: School code ───────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  _ServerEnv _selectedEnv = _kKnownServers[0];

  @override
  void initState() {
    super.initState();
    if (_kIsProdBuild) {
      ParentApiClient.setBaseUrl(ParentApiClient.defaultBaseUrl);
    } else {
      ParentApiClient.getBaseUrl().then((saved) {
        final match = _kKnownServers.firstWhere(
          (e) => e.url == saved,
          orElse: () => _kKnownServers[0],
        );
        ParentApiClient.setBaseUrl(match.url);
        if (mounted) setState(() => _selectedEnv = match);
      });
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _showEnvPicker() async {
    final result = await showDialog<_ServerEnv>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Select Environment',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        children: _kKnownServers.map((env) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, env),
          child: Row(children: [
            Icon(
              env == _selectedEnv ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: env == _selectedEnv ? AppColors.teal : AppColors.muted,
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(env.label,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(env.url,
                  style: const TextStyle(fontSize: 10, color: AppColors.muted)),
            ]),
          ]),
        )).toList(),
      ),
    );
    if (result == null) return;
    await ParentApiClient.setBaseUrl(result.url);
    if (mounted) setState(() => _selectedEnv = result);
  }

  Future<void> _next() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter your school code');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final school = await ParentApiClient.lookupSchool(code);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _CredentialsScreen(school: school)),
      );
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not connect. Check your network.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 64),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.teal, Color(0xFF0D9488)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.teal.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(child: Text('👨‍👩‍👧', style: TextStyle(fontSize: 30))),
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'EduTrack',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.text),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Parent App',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.muted),
                ),
              ),
              const SizedBox(height: 48),
              if (!_kIsProdBuild) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.dns_outlined, size: 12, color: AppColors.muted),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _showEnvPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.amberLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.amber.withOpacity(0.4)),
                        ),
                        child: Text(
                          'DEV · ${_selectedEnv.label.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.amber,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.teal.withOpacity(0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Enter School Code',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.text),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Your school code is available from the school admin.',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'SCHOOL CODE',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      key: const Key('school_code_field'),
                      controller: _codeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _next(),
                      decoration: const InputDecoration(
                        hintText: 'e.g. DEMO001',
                        prefixIcon: Icon(Icons.school_outlined, color: AppColors.muted, size: 18),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.coralLight, borderRadius: BorderRadius.circular(10)),
                        child: Text(_error!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFBE123C))),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        key: const Key('school_code_next'),
                        onPressed: _loading ? null : _next,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
                        child: _loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text('Continue'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step 2: Phone + password ──────────────────────────────────────────────────

class _CredentialsScreen extends StatefulWidget {
  final SchoolInfo school;
  const _CredentialsScreen({required this.school});

  @override
  State<_CredentialsScreen> createState() => _CredentialsScreenState();
}

class _CredentialsScreenState extends State<_CredentialsScreen> {
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      final deviceName = Platform.isAndroid ? 'Android Device' : Platform.isIOS ? 'iOS Device' : 'Unknown';
      final osVersion = Platform.operatingSystemVersion;
      final auth = context.read<ParentAuthProvider>();
      final mustChange = await auth.login(
        _phoneCtrl.text.trim(),
        _passCtrl.text,
        deviceName: deviceName,
        osVersion: osVersion,
      );
      if (!mounted) return;

      // Offer biometric enrollment after first successful login
      final canUseBio = await auth.isBiometricAvailable;
      final alreadyEnabled = await auth.isBiometricEnabled;
      if (canUseBio && !alreadyEnabled && mounted) {
        final enable = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Quick unlock', style: TextStyle(fontWeight: FontWeight.w800)),
            content: const Text('Use Face ID or fingerprint to unlock EduTrack when you come back to the app.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enable')),
            ],
          ),
        );
        if (enable == true && mounted) {
          final confirmed = await auth.authenticateBiometric('Confirm your biometric to enable quick unlock');
          if (confirmed) await auth.enableBiometric();
        }
      }

      if (!mounted) return;
      if (mustChange) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ForceChangePasswordScreen()),
        );
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // School branding banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.teal, Color(0xFF0D9488)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(child: Text('🏫', style: TextStyle(fontSize: 22))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.school.name,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text)),
                          Text(widget.school.code,
                              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(8)),
                      child: const Text('Verified', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.teal)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('MOBILE NUMBER',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    TextField(
                      key: const Key('phone_field'),
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      maxLength: 20,
                      decoration: const InputDecoration(
                        hintText: '9876543210',
                        counterText: '',
                        prefixIcon: Icon(Icons.phone_outlined, color: AppColors.muted, size: 18),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('PASSWORD',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    TextField(
                      key: const Key('password_field'),
                      controller: _passCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      maxLength: 128,
                      onSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        counterText: '',
                        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.muted, size: 18),
                        suffixIcon: GestureDetector(
                          onTap: () => setState(() => _obscure = !_obscure),
                          child: Icon(
                            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppColors.muted, size: 18,
                          ),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.coralLight, borderRadius: BorderRadius.circular(10)),
                        child: Text(_error!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFBE123C))),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        key: const Key('login_button'),
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
                        child: _loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text('Sign In'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
