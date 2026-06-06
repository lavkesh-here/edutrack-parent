import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'force_change_password.dart';

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
  bool _isProd = true; // true = Production, false = Dev

  @override
  void initState() {
    super.initState();
    ParentApiClient.getBaseUrl().then((url) {
      if (mounted) setState(() => _isProd = url == ParentApiClient.defaultBaseUrl || !url.contains('10.0.2.2'));
    });
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _onServerSwitch(bool prod) async {
    setState(() => _isProd = prod);
    await ParentApiClient.setBaseUrl(prod ? ParentApiClient.defaultBaseUrl : ParentApiClient.devBaseUrl);
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.dns_outlined, size: 12, color: AppColors.muted),
                  const SizedBox(width: 6),
                  DropdownButton<bool>(
                    value: _isProd,
                    underline: const SizedBox(),
                    isDense: true,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
                    items: const [
                      DropdownMenuItem(value: true, child: Text('Production')),
                      DropdownMenuItem(value: false, child: Text('Dev (Emulator)')),
                    ],
                    onChanged: (v) { if (v != null) _onServerSwitch(v); },
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
      final mustChange = await context.read<ParentAuthProvider>().login(
        _phoneCtrl.text.trim(),
        _passCtrl.text,
        deviceName: deviceName,
        osVersion: osVersion,
      );
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
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: '9876543210',
                        prefixIcon: Icon(Icons.phone_outlined, color: AppColors.muted, size: 18),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('PASSWORD',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        hintText: '••••••••',
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
