import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth.dart';
import '../core/api.dart';
import '../core/theme.dart';

class ForceChangePasswordScreen extends StatefulWidget {
  const ForceChangePasswordScreen({super.key});

  @override
  State<ForceChangePasswordScreen> createState() => _State();
}

class _State extends State<ForceChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure1 = true, _obscure2 = true, _obscure3 = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose(); _newCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_newCtrl.text != _confirmCtrl.text) { setState(() => _error = 'New passwords do not match'); return; }
    if (_newCtrl.text.length < 6) { setState(() => _error = 'Password must be at least 6 characters'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final auth = context.read<ParentAuthProvider>();
      await ParentApiClient.changePassword(
        parentId: auth.user!.parentId,
        currentPassword: _currentCtrl.text,
        newPassword: _newCtrl.text,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Try again.');
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
              const SizedBox(height: 48),
              Center(child: Container(
                width: 64, height: 64,
                decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(20)),
                child: const Center(child: Text('🔐', style: TextStyle(fontSize: 30))),
              )),
              const SizedBox(height: 20),
              const Center(child: Text('Set New Password',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.text))),
              const SizedBox(height: 8),
              const Center(child: Text(
                'Your school admin set a temporary password.\nPlease create a new one to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5),
              )),
              const SizedBox(height: 36),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border, width: 1.5)),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PwdField(label: 'TEMPORARY PASSWORD', ctrl: _currentCtrl, obscure: _obscure1, onToggle: () => setState(() => _obscure1 = !_obscure1), hint: 'Password from admin'),
                    const SizedBox(height: 16),
                    _PwdField(label: 'NEW PASSWORD', ctrl: _newCtrl, obscure: _obscure2, onToggle: () => setState(() => _obscure2 = !_obscure2), hint: 'At least 6 characters'),
                    const SizedBox(height: 16),
                    _PwdField(label: 'CONFIRM PASSWORD', ctrl: _confirmCtrl, obscure: _obscure3, onToggle: () => setState(() => _obscure3 = !_obscure3), hint: 'Repeat new password', isDone: true, onSubmit: _submit),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.coralLight, borderRadius: BorderRadius.circular(10)),
                        child: Text(_error!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFBE123C))),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(height: 50, child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
                      child: _loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text('Set Password & Continue'),
                    )),
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

class _PwdField extends StatelessWidget {
  final String label, hint;
  final TextEditingController ctrl;
  final bool obscure, isDone;
  final VoidCallback onToggle;
  final VoidCallback? onSubmit;

  const _PwdField({required this.label, required this.ctrl, required this.obscure, required this.onToggle, required this.hint, this.isDone = false, this.onSubmit});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.5)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        obscureText: obscure,
        textInputAction: isDone ? TextInputAction.done : TextInputAction.next,
        onSubmitted: onSubmit != null ? (_) => onSubmit!() : null,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.lock_outline, color: AppColors.muted, size: 18),
          suffixIcon: GestureDetector(onTap: onToggle, child: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.muted, size: 18)),
        ),
      ),
    ],
  );
}
