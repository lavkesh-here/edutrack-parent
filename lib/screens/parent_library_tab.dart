import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';

class ParentLibraryTab extends StatefulWidget {
  final String studentId;
  const ParentLibraryTab({super.key, required this.studentId});

  @override
  State<ParentLibraryTab> createState() => _ParentLibraryTabState();
}

class _ParentLibraryTabState extends State<ParentLibraryTab> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ParentApiClientLibrary.childLibraryBooks(widget.studentId);
      setState(() { _data = data; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.teal));
    if (_data == null) return const Center(child: Text('Unable to load library data', style: TextStyle(color: AppColors.muted)));

    final current = (_data!['current_issues'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final history = (_data!['history'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return RefreshIndicator(
      color: AppColors.teal,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (current.isNotEmpty) ...[
            const Text('CURRENTLY ISSUED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1)),
            const SizedBox(height: 8),
            ...current.map((b) => _BookCard(book: b)),
            const SizedBox(height: 16),
          ] else
            Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
              child: const Column(
                children: [
                  Text('📚', style: TextStyle(fontSize: 32)),
                  SizedBox(height: 8),
                  Text('No books currently issued', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 14)),
                ],
              ),
            ),
          if (history.isNotEmpty) ...[
            const Text('RETURN HISTORY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1)),
            const SizedBox(height: 8),
            ...history.map((b) => _BookCard(book: b, isHistory: true)),
          ],
        ],
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final Map<String, dynamic> book;
  final bool isHistory;
  const _BookCard({required this.book, this.isHistory = false});

  @override
  Widget build(BuildContext context) {
    final status = book['status'] as String? ?? 'issued';
    final isOverdue = status == 'overdue';
    final fine = book['fine_amount_due'];
    final hasFine = fine != null && (fine is num) && fine > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isOverdue ? AppColors.coral.withOpacity(0.3) : AppColors.border),
        boxShadow: isOverdue
            ? [BoxShadow(color: AppColors.coral.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 52,
                decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(8)),
                child: const Center(child: Text('📖', style: TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book['book_title'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.text), maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (book['book_author'] != null)
                      Text(book['book_author'], style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                ),
              ),
              if (isHistory)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: status == 'lost' ? AppColors.border : AppColors.tealLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status == 'lost' ? 'LOST' : 'RETURNED',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                        color: status == 'lost' ? AppColors.muted : AppColors.teal),
                  ),
                )
              else if (isOverdue)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.coralLight, borderRadius: BorderRadius.circular(8)),
                  child: const Text('OVERDUE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.coral)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _DatePill('Issued', book['issued_date'] as String?),
              const SizedBox(width: 8),
              _DatePill('Due', book['due_date'] as String?, highlight: isOverdue),
              if (book['returned_date'] != null) ...[
                const SizedBox(width: 8),
                _DatePill('Returned', book['returned_date'] as String?),
              ],
            ],
          ),
          if (isOverdue && hasFine) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppColors.coralLight, borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⚠️ ', style: TextStyle(fontSize: 14)),
                  Text('Fine due: ₹$fine', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.coral)),
                  const SizedBox(width: 6),
                  const Text('Please contact the school librarian.', style: TextStyle(fontSize: 11, color: AppColors.coral)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  final String label;
  final String? date;
  final bool highlight;
  const _DatePill(this.label, this.date, {this.highlight = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: highlight ? AppColors.coralLight : const Color(0xFFF8F8F8),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: highlight ? AppColors.coral.withOpacity(0.3) : AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: highlight ? AppColors.coral : AppColors.muted)),
        Text(date ?? '—', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: highlight ? AppColors.coral : AppColors.text)),
      ],
    ),
  );
}
