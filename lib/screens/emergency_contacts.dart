import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../core/theme.dart';

class EmergencyContactsScreen extends StatefulWidget {
  final ChildInfo child;
  const EmergencyContactsScreen({super.key, required this.child});

  @override
  State<EmergencyContactsScreen> createState() => _State();
}

class _State extends State<EmergencyContactsScreen> {
  List<Map<String, dynamic>> _contacts = [];
  bool _loading = true;
  bool _showForm = false;

  final _nameCtrl = TextEditingController();
  final _relationCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _relationCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ParentApiClientEmergency.getChildEmergencyContacts(widget.child.studentId);
      if (mounted) setState(() { _contacts = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _dial(String phone) async {
    final uri = Uri.parse('tel:$phone');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ParentApiClientEmergency.addEmergencyContact(
        widget.child.studentId,
        name: _nameCtrl.text.trim(),
        relation: _relationCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        priority: 2,
      );
      _nameCtrl.clear();
      _relationCtrl.clear();
      _phoneCtrl.clear();
      setState(() { _showForm = false; _saving = false; });
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.coral),
        );
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove contact?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Remove ${contact['name']} from emergency contacts?',
            style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ParentApiClientEmergency.deleteEmergencyContact(
        widget.child.studentId, contact['id'] as String,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.coral),
        );
      }
    }
  }

  int get _parentContactCount =>
      _contacts.where((c) => c['added_by_type'] == 'parent').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: const BackButton(color: AppColors.text),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Emergency Contacts',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
            Text(widget.child.studentName,
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.coral))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.coral,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  // Info card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.coralLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ℹ️', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'These contacts are notified in an emergency. School-managed contacts can only be edited by the school. You can add up to 3 of your own.',
                            style: TextStyle(fontSize: 12, color: AppColors.coral, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Contact cards
                  if (_contacts.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            const Icon(Icons.contact_phone_outlined, size: 48, color: AppColors.border),
                            const SizedBox(height: 12),
                            const Text('No emergency contacts yet',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                            const SizedBox(height: 4),
                            const Text('Add contacts below or ask the school to add them.',
                                style: TextStyle(fontSize: 12, color: AppColors.muted),
                                textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    ..._contacts.asMap().entries.map((entry) {
                      final i = entry.key;
                      final c = entry.value;
                      final isParentAdded = c['added_by_type'] == 'parent';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ContactCard(
                          contact: c,
                          priority: i + 1,
                          isParentAdded: isParentAdded,
                          onCall: () => _dial(c['phone'] as String? ?? ''),
                          onDelete: isParentAdded ? () => _delete(c) : null,
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 8),

                  // Add contact button / form
                  if (!_showForm) ...[
                    if (_parentContactCount < 3)
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _showForm = true),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Emergency Contact'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.coral,
                          side: const BorderSide(color: AppColors.coral),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Text(
                          'You can add up to 3 emergency contacts. Delete one to add another.',
                          style: TextStyle(fontSize: 12, color: AppColors.muted),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ] else ...[
                    _AddForm(
                      formKey: _formKey,
                      nameCtrl: _nameCtrl,
                      relationCtrl: _relationCtrl,
                      phoneCtrl: _phoneCtrl,
                      saving: _saving,
                      onSave: _save,
                      onCancel: () => setState(() { _showForm = false; }),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

// ── Contact card ──────────────────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  final Map<String, dynamic> contact;
  final int priority;
  final bool isParentAdded;
  final VoidCallback onCall;
  final VoidCallback? onDelete;

  const _ContactCard({
    required this.contact,
    required this.priority,
    required this.isParentAdded,
    required this.onCall,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = contact['name'] as String? ?? '';
    final relation = contact['relation'] as String? ?? '';
    final phone = contact['phone'] as String? ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            decoration: BoxDecoration(
              color: isParentAdded ? AppColors.violetLight : AppColors.coralLight,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(13)),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Column(
              children: [
                Text('#$priority',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isParentAdded ? AppColors.violet : AppColors.coral)),
                const SizedBox(height: 4),
                Icon(
                  isParentAdded ? Icons.person_outline : Icons.school_outlined,
                  size: 18,
                  color: isParentAdded ? AppColors.violet : AppColors.coral,
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                      ),
                      if (!isParentAdded)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.coralLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('School',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.coral)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(relation,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  const SizedBox(height: 6),
                  Text(phone,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text2)),
                ],
              ),
            ),
          ),
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.phone_rounded, color: AppColors.green),
                onPressed: onCall,
                tooltip: 'Call',
              ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.muted, size: 20),
                  onPressed: onDelete,
                  tooltip: 'Remove',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Add form ──────────────────────────────────────────────────────────────────

class _AddForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController relationCtrl;
  final TextEditingController phoneCtrl;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _AddForm({
    required this.formKey,
    required this.nameCtrl,
    required this.relationCtrl,
    required this.phoneCtrl,
    required this.saving,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Emergency Contact',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
            const SizedBox(height: 14),
            _Field(
              controller: nameCtrl,
              label: 'Full Name',
              hint: 'e.g. Priya Sharma',
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Name is required' : null,
            ),
            const SizedBox(height: 10),
            _Field(
              controller: relationCtrl,
              label: 'Relation',
              hint: 'e.g. Mother, Uncle, Guardian',
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Relation is required' : null,
            ),
            const SizedBox(height: 10),
            _Field(
              controller: phoneCtrl,
              label: 'Mobile Number',
              hint: '10-digit number',
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 10,
              validator: (v) {
                final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                return digits.length == 10 ? null : 'Enter a valid 10-digit number';
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: saving ? null : onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.muted,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: saving ? null : onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.coral,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted)),
      const SizedBox(height: 4),
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        validator: validator,
        style: const TextStyle(fontSize: 14, color: AppColors.text),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.coral),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.coral),
          ),
        ),
      ),
    ],
  );
}
