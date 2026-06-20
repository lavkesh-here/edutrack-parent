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
  int? _openIdx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ParentApiClient.getCirculars(widget.child.studentId);
      if (mounted) setState(() { _circulars = data; _loading = false; _openIdx = null; });
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
                    itemBuilder: (_, i) => _CircularCard(
                      data: _circulars![i],
                      isOpen: _openIdx == i,
                      onToggle: () => setState(() => _openIdx = _openIdx == i ? null : i),
                    ),
                  ),
                ),
    );
  }
}

class _CircularCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isOpen;
  final VoidCallback onToggle;
  const _CircularCard({required this.data, required this.isOpen, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    final attachmentUrl = data['attachment_url'] as String?;
    final createdAt = (data['created_at'] as String? ?? '').split('T').first;
    final hasBody = body.isNotEmpty;

    return GestureDetector(
      onTap: hasBody ? onToggle : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isOpen ? AppColors.teal.withOpacity(0.4) : AppColors.border, width: 1.5),
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
                    decoration: BoxDecoration(
                      color: isOpen ? AppColors.teal.withOpacity(0.12) : AppColors.tealLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
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
                    Icon(isOpen ? Icons.expand_less : Icons.expand_more,
                        size: 18, color: AppColors.muted),
                ],
              ),
            ),
            if (isOpen && hasBody)
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
