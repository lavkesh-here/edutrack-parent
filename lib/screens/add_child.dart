import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key});

  @override
  State<AddChildScreen> createState() => _State();
}

class _State extends State<AddChildScreen> {
  final _codeCtrl = TextEditingController();
  final _admCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  SchoolInfo? _school;
  bool _lookingUp = false;
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose(); _admCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookupSchool() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() { _lookingUp = true; _school = null; _error = null; });
    try {
      final school = await ParentApiClient.lookupSchool(code);
      setState(() { _school = school; _lookingUp = false; });
    } on ApiError catch (e) {
      setState(() { _error = e.message; _lookingUp = false; });
    }
  }

  Future<void> _submit() async {
    if (_school == null) { showSnack(context, 'Please verify the school code first', error: true); return; }
    if (_admCtrl.text.trim().isEmpty) { showSnack(context, 'Enter student admission number', error: true); return; }
    if (_passCtrl.text.isEmpty) { showSnack(context, 'Confirm your password', error: true); return; }
    setState(() { _saving = true; _error = null; });
    try {
      await ParentApiClient.addChild(
        schoolCode: _school!.code,
        admissionNumber: _admCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (!mounted) return;
      showSnack(context, 'Child linked successfully ✓');
      Navigator.pop(context, true);
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Add Child'), leading: const BackButton()),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('SCHOOL CODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 50,
                    onChanged: (_) => setState(() => _school = null),
                    decoration: const InputDecoration(hintText: 'e.g. DEMO001', counterText: ''),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _lookingUp ? null : _lookupSchool,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, padding: const EdgeInsets.symmetric(horizontal: 16)),
                    child: _lookingUp
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Verify'),
                  ),
                ),
              ],
            ),
            if (_school != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.teal.withOpacity(0.3))),
                child: Row(
                  children: [
                    const Text('🏫', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_school!.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text))),
                    const Text('✓', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('ADMISSION NUMBER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              TextField(
                controller: _admCtrl,
                maxLength: 50,
                decoration: const InputDecoration(hintText: 'Student admission number', counterText: ''),
              ),
              const SizedBox(height: 16),
              const Text('YOUR PASSWORD (CONFIRM)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                maxLength: 128,
                decoration: InputDecoration(
                  hintText: 'Re-enter your password',
                  counterText: '',
                  suffixIcon: GestureDetector(
                    onTap: () => setState(() => _obscure = !_obscure),
                    child: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.muted, size: 18),
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
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Link Child'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
