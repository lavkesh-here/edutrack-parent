import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class AttenderScreen extends StatefulWidget {
  final ChildInfo child;
  const AttenderScreen({super.key, required this.child});

  @override
  State<AttenderScreen> createState() => _State();
}

class _State extends State<AttenderScreen> {
  List<Map<String, dynamic>> _attenders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final data = await ParentApiClient.getAttenders(widget.child.studentId);
      if (mounted) setState(() { _attenders = data; _loading = false; });
    } on ApiError catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load attenders.'; _loading = false; });
    }
  }

  Future<void> _delete(int id) async {
    try {
      await ParentApiClient.deleteAttender(widget.child.studentId, id);
      setState(() => _attenders.removeWhere((a) => a['id'] == id));
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) showSnack(context, 'Could not remove attender.', error: true);
    }
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final relCtrl = TextEditingController(text: 'Parent');
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Add Attender', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
              const SizedBox(height: 4),
              const Text('Authorized person to pick up your child', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              const SizedBox(height: 20),
              _Field(ctrl: nameCtrl, label: 'Full Name', icon: Icons.person_outline),
              const SizedBox(height: 12),
              _Field(ctrl: phoneCtrl, label: 'Phone Number', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _Field(ctrl: relCtrl, label: 'Relation (e.g. Uncle, Driver)', icon: Icons.people_outline),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
                            showSnack(ctx, 'Name and phone are required', error: true);
                            return;
                          }
                          setS(() => saving = true);
                          try {
                            await ParentApiClient.addAttender(
                              widget.child.studentId,
                              name: nameCtrl.text.trim(),
                              phone: phoneCtrl.text.trim(),
                              relation: relCtrl.text.trim().isEmpty ? 'Parent' : relCtrl.text.trim(),
                            );
                            if (mounted) {
                              Navigator.pop(ctx);
                              _load();
                            }
                          } on ApiError catch (e) {
                            setS(() => saving = false);
                            showSnack(ctx, e.message, error: true);
                          } catch (_) {
                            setS(() => saving = false);
                            showSnack(ctx, 'Could not add attender.', error: true);
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
                  child: saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Add Attender', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Attenders'), leading: const BackButton()),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.coral)))
              : _attenders.isEmpty
                  ? _Empty()
                  : RefreshIndicator(
                      color: AppColors.teal,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const SectionHeader('AUTHORIZED PICKUP PERSONS'),
                          const SizedBox(height: 4),
                          ..._attenders.map((a) => _AttenderTile(
                            attender: a,
                            onDelete: () => _confirmDelete(context, a),
                          )),
                        ],
                      ),
                    ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Map<String, dynamic> a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Attender', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        content: Text('Remove ${a['name']} from authorized pickup persons?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.coral),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) _delete(a['id'] as int);
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('👤', style: TextStyle(fontSize: 56)),
              SizedBox(height: 16),
              Text('No Attenders Yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
              SizedBox(height: 8),
              Text('Tap + to add authorized persons who can pick up your child from school.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      );
}

class _AttenderTile extends StatelessWidget {
  final Map<String, dynamic> attender;
  final VoidCallback onDelete;
  const _AttenderTile({required this.attender, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name = attender['name']?.toString() ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Dismissible(
      key: ValueKey(attender['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AppColors.coral.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.delete_outline, color: AppColors.coral),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // parent handles removal after API call
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: AppColors.tealLight, shape: BoxShape.circle),
              child: Center(child: Text(initial, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.teal))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text)),
                  Text('${attender['relation'] ?? ''} · ${attender['phone'] ?? ''}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.coral, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  const _Field({required this.ctrl, required this.label, required this.icon, this.keyboardType});

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.muted, size: 20),
        ),
      );
}
