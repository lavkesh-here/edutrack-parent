import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class FeesScreen extends StatefulWidget {
  final ChildInfo child;
  const FeesScreen({super.key, required this.child});

  @override
  State<FeesScreen> createState() => _State();
}

class _State extends State<FeesScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  String _academicYear = '2026-27';
  final List<String> _years = ['2026-27', '2025-26', '2024-25'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final data = await ParentApiClient.getFees(widget.child.studentId, academicYear: _academicYear);
      if (mounted) setState(() { _data = data; _loading = false; });
    } on ApiError catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load fee details.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Fees'),
        leading: const BackButton(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DropdownButton<String>(
              value: _academicYear,
              underline: const SizedBox(),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text),
              items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
              onChanged: (v) {
                if (v != null) { setState(() => _academicYear = v); _load(); }
              },
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.coral)))
              : _data == null
                  ? const SizedBox()
                  : _Body(data: _data!, child: widget.child),
    );
  }
}

class _Body extends StatefulWidget {
  final Map<String, dynamic> data;
  final ChildInfo child;
  const _Body({required this.data, required this.child});

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  final Set<int> _selected = {};

  List<Map<String, dynamic>> get _regular => _filterType('regular');
  List<Map<String, dynamic>> get _misc => _filterType('misc');

  List<Map<String, dynamic>> _filterType(String type) {
    final list = (widget.data['installments'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .where((e) => e['fee_type'] == type)
        .toList();
    return list;
  }

  double get _selectedTotal =>
      _selected.fold(0.0, (sum, id) {
        final item = (widget.data['installments'] as List<dynamic>? ?? [])
            .firstWhere((e) => (e as Map)['id'] == id, orElse: () => <String, dynamic>{});
        return sum + ((item as Map)['amount'] as num? ?? 0).toDouble();
      });

  @override
  Widget build(BuildContext context) {
    final summary = widget.data['summary'] as Map<String, dynamic>? ?? {};
    final payments = (widget.data['payments'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
    final total = (summary['total_fee'] as num? ?? 0).toDouble();
    final paid = (summary['paid'] as num? ?? 0).toDouble();
    final due = (summary['due'] as num? ?? 0).toDouble();

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.teal, Color(0xFF0D9488)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 110, height: 110,
                          child: CustomPaint(
                            painter: _DonutPainter(paid: paid, total: total),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('₹${_fmt(paid)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                                  const Text('Paid', style: TextStyle(fontSize: 10, color: Colors.white70)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SumRow(label: 'Total Fee', value: total, color: Colors.white),
                            const SizedBox(height: 8),
                            _SumRow(label: 'Total Due', value: due, color: const Color(0xFFFCA5A5)),
                            const SizedBox(height: 8),
                            _SumRow(label: 'Paid', value: paid, color: const Color(0xFF6EE7B7)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Regular fees
              if (_regular.isNotEmpty) ...[
                const SectionHeader('REGULAR FEES'),
                ..._regular.map((item) => _InstallmentTile(
                  item: item,
                  selected: _selected.contains(item['id'] as int),
                  onToggle: item['status'] == 'unpaid' || item['status'] == 'overdue'
                      ? () => setState(() {
                            final id = item['id'] as int;
                            if (_selected.contains(id)) _selected.remove(id); else _selected.add(id);
                          })
                      : null,
                )),
                const SizedBox(height: 16),
              ],

              // Misc fees
              if (_misc.isNotEmpty) ...[
                const SectionHeader('MISC FEES'),
                ..._misc.map((item) => _InstallmentTile(
                  item: item,
                  selected: _selected.contains(item['id'] as int),
                  onToggle: item['status'] == 'unpaid' || item['status'] == 'overdue'
                      ? () => setState(() {
                            final id = item['id'] as int;
                            if (_selected.contains(id)) _selected.remove(id); else _selected.add(id);
                          })
                      : null,
                )),
                const SizedBox(height: 16),
              ],

              // Receipts
              if (payments.isNotEmpty) ...[
                const SectionHeader('PAYMENT RECEIPTS'),
                ...payments.map((p) => _ReceiptTile(payment: p)),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),

        // Pay Now footer
        if (_selected.isNotEmpty)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
                boxShadow: [BoxShadow(color: Color(0x1514B8A6), blurRadius: 12)],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_selected.length} item${_selected.length > 1 ? 's' : ''} selected',
                            style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
                        Text('₹${_fmt(_selectedTotal)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.text)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _showPayDialog(context),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                    child: const Text('Pay Now', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showPayDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Online Payment', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Online payment is coming soon!', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Please pay at the school office or contact the admin to record your payment.', style: TextStyle(color: AppColors.muted)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

String _fmtAmount(double v) => '₹${v.toStringAsFixed(0)}';

class _SumRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _SumRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text(_fmtAmount(value), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
        ],
      );
}

class _DonutPainter extends CustomPainter {
  final double paid;
  final double total;
  const _DonutPainter({required this.paid, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final radius = math.min(cx, cy) - 8;
    final stroke = 12.0;
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round;

    paint.color = Colors.white.withOpacity(0.2);
    canvas.drawCircle(Offset(cx, cy), radius, paint);

    final fraction = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;
    paint.color = Colors.white;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.paid != paid || old.total != total;
}

class _InstallmentTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool selected;
  final VoidCallback? onToggle;
  const _InstallmentTile({required this.item, required this.selected, this.onToggle});

  Color get _statusColor {
    switch (item['status']) {
      case 'paid': return AppColors.teal;
      case 'overdue': return AppColors.coral;
      default: return AppColors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = (item['amount'] as num? ?? 0).toDouble();
    final isPaid = item['status'] == 'paid';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? AppColors.teal : AppColors.border, width: selected ? 2 : 1.5),
      ),
      child: ListTile(
        leading: onToggle != null
            ? Checkbox(
                value: selected,
                onChanged: (_) => onToggle?.call(),
                activeColor: AppColors.teal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              )
            : Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: _statusColor.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(isPaid ? Icons.check : Icons.schedule, color: _statusColor, size: 16),
              ),
        title: Text(item['title']?.toString() ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
        subtitle: Text(
          item['due_date'] != null ? 'Due: ${item['due_date']}' : '',
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(_fmtAmount(amount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.text)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: _statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
              child: Text(item['status']?.toString() ?? '', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _statusColor)),
            ),
          ],
        ),
        onTap: onToggle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }
}

class _ReceiptTile extends StatelessWidget {
  final Map<String, dynamic> payment;
  const _ReceiptTile({required this.payment});

  @override
  Widget build(BuildContext context) {
    final amount = (payment['amount'] as num? ?? 0).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.receipt_outlined, color: AppColors.teal, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment['receipt_number']?.toString() ?? 'Receipt',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
                Text('${payment['payment_date'] ?? ''} · ${payment['payment_method'] ?? ''}',
                    style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
          Text(_fmtAmount(amount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.teal)),
        ],
      ),
    );
  }
}
