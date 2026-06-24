import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
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

  static const _maxAttenders = 3;

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

  Future<void> _delete(String id) async {
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
    if (_attenders.length >= _maxAttenders) {
      showSnack(context, 'Maximum $_maxAttenders attenders allowed per student', error: true);
      return;
    }

    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final relCtrl = TextEditingController(text: 'Parent');
    bool saving = false;
    XFile? pickedPhoto;

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
              // Photo picker
              Center(
                child: GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 80);
                    if (picked != null) setS(() => pickedPhoto = picked);
                  },
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.tealLight,
                        backgroundImage: pickedPhoto != null ? FileImage(File(pickedPhoto!.path)) : null,
                        child: pickedPhoto == null
                            ? const Icon(Icons.person_outline, size: 32, color: AppColors.teal)
                            : null,
                      ),
                      Positioned(
                        right: 0, bottom: 0,
                        child: Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(color: AppColors.teal, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                          child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _Field(fieldKey: const Key('attender_name_field'), ctrl: nameCtrl, label: 'Full Name', icon: Icons.person_outline),
              const SizedBox(height: 12),
              _Field(fieldKey: const Key('attender_phone_field'), ctrl: phoneCtrl, label: 'Phone Number', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _Field(fieldKey: const Key('attender_relation_field'), ctrl: relCtrl, label: 'Relation (e.g. Uncle, Driver)', icon: Icons.people_outline),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  key: const Key('add_attender_button'),
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
                            // Upload photo if picked
                            if (pickedPhoto != null && mounted) {
                              try {
                                final latest = await ParentApiClient.getAttenders(widget.child.studentId);
                                if (latest.isNotEmpty) {
                                  final newId = latest.last['id'].toString();
                                  await _doUpload(pickedPhoto!, newId);
                                }
                              } catch (_) {}
                            }
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

  Future<void> _doUpload(XFile photo, String attenderId) async {
    final bytes = await photo.readAsBytes();
    final ext = photo.name.split('.').last.toLowerCase();
    final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
    final urlData = await ParentApiClient.getAttenderUploadUrl(
      widget.child.studentId,
      filename: photo.name,
      contentType: contentType,
      fileSize: bytes.lengthInBytes,
    );
    final uploadUrl = urlData['upload_url'] as String;
    final gcsUrl = urlData['gcs_url'] as String;
    final res = await http.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': contentType},
      body: bytes,
    );
    if (res.statusCode >= 300) throw Exception('Upload failed (${res.statusCode})');
    await ParentApiClient.updateAttenderPhoto(widget.child.studentId, attenderId, gcsUrl);
  }

  Future<void> _uploadPhoto(String attenderId) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 80);
    if (picked == null) return;
    try {
      await _doUpload(picked, attenderId);
      if (mounted) {
        showSnack(context, 'Photo updated');
        _load();
      }
    } catch (_) {
      if (mounted) showSnack(context, 'Could not upload photo', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _attenders.length;
    final atMax = count >= _maxAttenders;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Attenders'), leading: const BackButton()),
      floatingActionButton: FloatingActionButton(
        key: const Key('add_attender_fab'),
        onPressed: atMax ? null : _showAddDialog,
        backgroundColor: atMax ? AppColors.border : AppColors.teal,
        tooltip: atMax ? 'Maximum 3 attenders reached' : 'Add Attender',
        child: Icon(Icons.add, color: atMax ? AppColors.muted : Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.coral)))
              : RefreshIndicator(
                  color: AppColors.teal,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: atMax ? AppColors.coralLight : AppColors.tealLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              atMax ? Icons.warning_amber_outlined : Icons.people_outline,
                              color: atMax ? AppColors.coral : AppColors.teal,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$count / $_maxAttenders Attenders',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: atMax ? AppColors.coral : AppColors.teal,
                              ),
                            ),
                            if (atMax) ...[
                              const SizedBox(width: 6),
                              const Text('(limit reached)',
                                  style: TextStyle(fontSize: 11, color: AppColors.coral)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_attenders.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
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
                        )
                      else ...[
                        const SectionHeader('AUTHORIZED PICKUP PERSONS'),
                        const SizedBox(height: 4),
                        ..._attenders.map((a) => _AttenderTile(
                          attender: a,
                          onDelete: () => _confirmDelete(context, a),
                          onPhotoTap: () => _uploadPhoto(a['id'].toString()),
                        )),
                      ],
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
    if (confirmed == true) _delete(a['id'].toString());
  }
}

class _AttenderTile extends StatelessWidget {
  final Map<String, dynamic> attender;
  final VoidCallback onDelete;
  final VoidCallback onPhotoTap;
  const _AttenderTile({required this.attender, required this.onDelete, required this.onPhotoTap});

  @override
  Widget build(BuildContext context) {
    final name = attender['name']?.toString() ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final photoUrl = attender['photo_url'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onPhotoTap,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.tealLight,
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? Text(initial, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.teal))
                      : null,
                ),
                Positioned(
                  right: 0, bottom: 0,
                  child: Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(color: AppColors.teal, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                    child: const Icon(Icons.camera_alt, size: 10, color: Colors.white),
                  ),
                ),
              ],
            ),
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
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final Key? fieldKey;
  const _Field({super.key, required this.ctrl, required this.label, required this.icon, this.keyboardType, this.fieldKey});

  @override
  Widget build(BuildContext context) => TextField(
        key: fieldKey,
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.muted, size: 20),
        ),
      );
}
