import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../core/theme.dart';

class DocumentsScreen extends StatefulWidget {
  final ChildInfo child;
  const DocumentsScreen({super.key, required this.child});

  @override
  State<DocumentsScreen> createState() => _State();
}

class _State extends State<DocumentsScreen> {
  List<Map<String, dynamic>>? _docs;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ParentApiClient.getDocuments(widget.child.studentId);
      if (mounted) setState(() { _docs = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open document')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Documents'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : (_docs == null || _docs!.isEmpty)
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('📄', style: TextStyle(fontSize: 48)),
                      SizedBox(height: 12),
                      Text('No documents yet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                      SizedBox(height: 4),
                      Text('Certificates and reports will appear here',
                          style: TextStyle(fontSize: 13, color: AppColors.muted)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.teal,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _docs!.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _DocCard(doc: _docs![i], onOpen: _openUrl),
                  ),
                ),
    );
  }
}

class _DocCard extends StatelessWidget {
  final Map<String, dynamic> doc;
  final Future<void> Function(String) onOpen;

  const _DocCard({required this.doc, required this.onOpen});

  static const _typeLabel = {
    'certificate': 'Certificate',
    'report_card': 'Report Card',
    'id_card': 'ID Card',
    'medical': 'Medical',
    'other': 'Document',
  };

  static const _typeColor = {
    'certificate': AppColors.teal,
    'report_card': AppColors.violet,
    'id_card': AppColors.sky,
    'medical': AppColors.coral,
    'other': AppColors.muted,
  };

  static const _typeIcon = {
    'certificate': '🏆',
    'report_card': '📊',
    'id_card': '🪪',
    'medical': '🏥',
    'other': '📄',
  };

  @override
  Widget build(BuildContext context) {
    final type = doc['document_type'] as String? ?? 'other';
    final label = _typeLabel[type] ?? 'Document';
    final color = _typeColor[type] ?? AppColors.muted;
    final icon = _typeIcon[type] ?? '📄';
    final dateStr = doc['created_at'] as String?;
    String date = '';
    if (dateStr != null) {
      final dt = DateTime.tryParse(dateStr);
      if (dt != null) {
        date = '${dt.day} ${_month(dt.month)} ${dt.year}';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          final url = doc['file_url'] as String?;
          if (url != null) onOpen(url);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(icon, style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc['title'] as String? ?? 'Document',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(label,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                      ),
                      if (date.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(date, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                      ],
                    ]),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new, size: 18, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  String _month(int m) => const [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ][m];
}
