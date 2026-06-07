import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class CircularsScreen extends StatefulWidget {
  final ChildInfo child;
  const CircularsScreen({super.key, required this.child});

  @override
  State<CircularsScreen> createState() => _State();
}

class _State extends State<CircularsScreen> {
  List<Map<String, dynamic>>? _circulars;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ParentApiClient.getCirculars(widget.child.studentId);
      if (mounted) setState(() { _circulars = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('School Circulars'),
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
          : (_circulars == null || _circulars!.isEmpty)
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('📋', style: TextStyle(fontSize: 48)),
                      SizedBox(height: 12),
                      Text('No circulars yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                      SizedBox(height: 4),
                      Text('School notices will appear here', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.teal,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _circulars!.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _CircularCard(data: _circulars![i]),
                  ),
                ),
    );
  }
}

class _CircularCard extends StatefulWidget {
  final Map<String, dynamic> data;
  const _CircularCard({required this.data});

  @override
  State<_CircularCard> createState() => _CircularCardState();
}

class _CircularCardState extends State<_CircularCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final title = widget.data['title'] as String? ?? '';
    final body = widget.data['body'] as String? ?? '';
    final attachmentUrl = widget.data['attachment_url'] as String?;
    final createdAt = (widget.data['created_at'] as String? ?? '').split('T').first;
    final hasBody = body.isNotEmpty;

    return GestureDetector(
      onTap: hasBody ? () => setState(() => _expanded = !_expanded) : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(10)),
                    child: const Center(child: Text('📋', style: TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
                        const SizedBox(height: 3),
                        Text(fmtDate(createdAt),
                            style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  if (hasBody)
                    Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                        size: 18, color: AppColors.muted),
                ],
              ),
            ),
            if (_expanded && hasBody)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 10),
                    Text(body, style: const TextStyle(fontSize: 13, color: AppColors.text2, height: 1.5)),
                    if (attachmentUrl != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.attach_file, size: 14, color: AppColors.teal),
                          const SizedBox(width: 4),
                          const Text('Attachment', style: TextStyle(fontSize: 12, color: AppColors.teal, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
