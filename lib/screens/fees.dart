import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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

// ── Body ──────────────────────────────────────────────────────────────────────

class _Body extends StatefulWidget {
  final Map<String, dynamic> data;
  final ChildInfo child;
  const _Body({required this.data, required this.child});

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  final Set<String> _selected = {};
  bool _showPaid = false;
  final _today = DateTime.now();

  // ── Data helpers ────────────────────────────────────────────────────────────

  String get _currentYM =>
      '${_today.year}-${_today.month.toString().padLeft(2, '0')}';

  /// Extract "YYYY-MM" from a fee_month string (may be "YYYY-MM-DD" or "YYYY-MM").
  String? _ym(Map item) {
    final fm = item['fee_month'] as String?;
    if (fm == null || fm.length < 7) return null;
    return fm.substring(0, 7);
  }

  bool _isCurrentOrPast(Map item) {
    final ym = _ym(item);
    if (ym != null) return ym.compareTo(_currentYM) <= 0;
    final dd = item['due_date'] as String?;
    if (dd != null) {
      return DateTime.tryParse(dd)
              ?.isBefore(_today.add(const Duration(days: 1))) ??
          true;
    }
    return true;
  }

  List<Map<String, dynamic>> get _all =>
      (widget.data['installments'] as List? ?? [])
          .cast<Map<String, dynamic>>();

  List<Map<String, dynamic>> get _overdueItems =>
      _all.where((i) => i['status'] == 'overdue').toList();

  List<Map<String, dynamic>> get _currentDueItems =>
      _all.where((i) => i['status'] == 'unpaid' && _isCurrentOrPast(i)).toList();

  List<Map<String, dynamic>> get _upcomingItems =>
      _all.where((i) => i['status'] == 'unpaid' && !_isCurrentOrPast(i)).toList();

  List<Map<String, dynamic>> get _paidItems =>
      _all.where((i) => i['status'] == 'paid').toList();

  /// True when there are outstanding dues (overdue or current-month unpaid).
  bool get _hasUnpaidDue =>
      _overdueItems.isNotEmpty || _currentDueItems.isNotEmpty;

  /// Map from installment id (string) → linked payment record.
  Map<String, Map<String, dynamic>> get _paymentByInstId {
    final payments =
        (widget.data['payments'] as List? ?? []).cast<Map<String, dynamic>>();
    return {
      for (final p in payments)
        if (p['fee_structure_id'] != null) p['fee_structure_id'].toString(): p,
    };
  }

  double get _selectedTotal => _selected.fold(0.0, (sum, id) {
        final item = _all.firstWhere(
          (e) => e['id']?.toString() == id,
          orElse: () => <String, dynamic>{},
        );
        return sum + ((item['amount'] as num?) ?? 0).toDouble();
      });

  @override
  void initState() {
    super.initState();
    // Auto-expand paid section when there are no actionable items.
    if (_overdueItems.isEmpty && _currentDueItems.isEmpty && _upcomingItems.isEmpty) {
      _showPaid = true;
    }
  }

  void _toggleSelected(String id) => setState(() {
        if (_selected.contains(id)) {
          _selected.remove(id);
        } else {
          _selected.add(id);
        }
      });

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final summary = widget.data['summary'] as Map<String, dynamic>? ?? {};
    final total = (summary['total_fee'] as num? ?? 0).toDouble();
    final paid = (summary['paid'] as num? ?? 0).toDouble();
    final due = (summary['due'] as num? ?? 0).toDouble();
    final payByInst = _paymentByInstId;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Fixed summary card ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _SummaryCard(total: total, paid: paid, due: due),
            ),

            // ── Scrollable installment list ───────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  // OVERDUE
                  if (_overdueItems.isNotEmpty) ...[
                    _SectionLabel(
                      'OVERDUE (${_overdueItems.length})',
                      color: AppColors.coral,
                    ),
                    ..._overdueItems.map((item) => _InstallmentTile(
                          key: ValueKey(item['id']),
                          item: item,
                          selected: _selected.contains(item['id'].toString()),
                          onToggle: () => _toggleSelected(item['id'].toString()),
                          child: widget.child,
                        )),
                    const SizedBox(height: 12),
                  ],

                  // DUE NOW
                  if (_currentDueItems.isNotEmpty) ...[
                    const _SectionLabel('DUE NOW'),
                    ..._currentDueItems.map((item) => _InstallmentTile(
                          key: ValueKey(item['id']),
                          item: item,
                          selected: _selected.contains(item['id'].toString()),
                          onToggle: () => _toggleSelected(item['id'].toString()),
                          child: widget.child,
                        )),
                    const SizedBox(height: 12),
                  ],

                  // UPCOMING — all upcoming installments, selectable for advance payment
                  if (_upcomingItems.isNotEmpty) ...[
                    const _SectionLabel('UPCOMING'),
                    if (_hasUnpaidDue) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3CD),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: const Color(0xFFFFC107)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 14, color: Color(0xFF856404)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You have pending dues. You can still select upcoming installments to pay in advance.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF856404),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    ..._upcomingItems.map((item) => _InstallmentTile(
                          key: ValueKey(item['id']),
                          item: item,
                          selected: _selected.contains(item['id'].toString()),
                          onToggle: () => _toggleSelected(item['id'].toString()),
                          child: widget.child,
                        )),
                    const SizedBox(height: 12),
                  ],

                  // PAID — collapsible
                  if (_paidItems.isNotEmpty) ...[
                    InkWell(
                      onTap: () => setState(() => _showPaid = !_showPaid),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Text(
                              'PAID (${_paidItems.length})',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.teal,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              _showPaid
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 18,
                              color: AppColors.teal,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showPaid)
                      ..._paidItems.map((item) => _InstallmentTile(
                            key: ValueKey(item['id']),
                            item: item,
                            selected: false,
                            onToggle: null,
                            linkedPayment:
                                payByInst[item['id']?.toString()],
                            child: widget.child,
                          )),
                  ],
                ],
              ),
            ),
          ],
        ),

        // ── Pay Now footer ───────────────────────────────────────────────────
        if (_selected.isNotEmpty)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                border:
                    Border(top: BorderSide(color: AppColors.border)),
                boxShadow: [
                  BoxShadow(
                      color: Color(0x1514B8A6), blurRadius: 12)
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_selected.length} item${_selected.length > 1 ? 's' : ''} selected',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                              fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '₹${_fmtLarge(_selectedTotal)}',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.text),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    key: const Key('pay_now_button'),
                    onPressed: () => _showPayDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                    ),
                    child: const Text('Pay Now',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800)),
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
        title: const Text('Online Payment',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Online payment is coming soon!',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
                'Please pay at the school office or contact the admin to record your payment.',
                style: TextStyle(color: AppColors.muted)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'))
        ],
      ),
    );
  }

  String _fmtLarge(double v) => v.toStringAsFixed(0);
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double total, paid, due;
  const _SummaryCard({required this.total, required this.paid, required this.due});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.teal, Color(0xFF0D9488)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 110,
              height: 110,
              child: CustomPaint(
                painter: _DonutPainter(paid: paid, total: total),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '₹${_fmt(paid)}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white),
                      ),
                      const Text('Paid',
                          style: TextStyle(
                              fontSize: 10, color: Colors.white70)),
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
      );

  String _fmt(double v) => v.toStringAsFixed(0);
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionLabel(this.text, {this.color = AppColors.muted});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.8,
          ),
        ),
      );
}

// ── Installment tile ──────────────────────────────────────────────────────────

class _InstallmentTile extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool selected;
  final VoidCallback? onToggle;
  final bool isLocked;
  final Map<String, dynamic>? linkedPayment;
  final ChildInfo child;

  const _InstallmentTile({
    super.key,
    required this.item,
    required this.selected,
    this.onToggle,
    this.isLocked = false,
    this.linkedPayment,
    required this.child,
  });

  @override
  State<_InstallmentTile> createState() => _InstallmentTileState();
}

class _InstallmentTileState extends State<_InstallmentTile> {
  bool _showBreakdown = false;

  bool get _isPaid => widget.item['status'] == 'paid';
  bool get _isOverdue => widget.item['status'] == 'overdue';

  Color get _statusColor {
    if (_isPaid) return AppColors.teal;
    if (_isOverdue) return AppColors.coral;
    if (widget.isLocked) return AppColors.muted;
    return AppColors.amber;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final amount = (item['amount'] as num? ?? 0).toDouble();
    final lineItems = List<Map<String, dynamic>>.from(
        (item['line_items'] as List? ?? []).cast<Map<String, dynamic>>())
      ..sort((a, b) => (a['component_name']?.toString() ?? '')
          .compareTo(b['component_name']?.toString() ?? ''));

    return Opacity(
      opacity: widget.isLocked ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.selected
                ? AppColors.teal
                : widget.isLocked
                    ? AppColors.border
                    : AppColors.border,
            width: widget.selected ? 2 : 1.5,
          ),
        ),
        child: Column(
          children: [
            ListTile(
              leading: _leading(),
              title: Text(
                item['title']?.toString() ?? '',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text),
              ),
              subtitle: item['due_date'] != null
                  ? Text('Due: ${item['due_date']}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.muted))
                  : null,
              trailing: _trailing(amount),
              onTap: widget.isLocked ? null : widget.onToggle,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),

            // Breakdown toggle
            if (lineItems.isNotEmpty) ...[
              Divider(height: 1, color: AppColors.border),
              InkWell(
                onTap: () =>
                    setState(() => _showBreakdown = !_showBreakdown),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        _showBreakdown
                            ? 'Hide Breakdown'
                            : 'View Breakdown',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.teal),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _showBreakdown
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 16,
                        color: AppColors.teal,
                      ),
                    ],
                  ),
                ),
              ),
              if (_showBreakdown)
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    children: lineItems.map((li) {
                      final liAmt =
                          (li['amount'] as num? ?? 0).toDouble();
                      final waived = li['is_waived'] as bool? ?? false;
                      return Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                li['component_name']?.toString() ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: waived
                                      ? AppColors.muted
                                      : AppColors.text2,
                                  decoration: waived
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            Text(
                              waived
                                  ? 'Waived'
                                  : '₹${liAmt.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: waived
                                    ? AppColors.muted
                                    : AppColors.text,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],

            // Download receipt row (paid items with linked payment only)
            if (_isPaid && widget.linkedPayment != null) ...[
              if (lineItems.isEmpty) Divider(height: 1, color: AppColors.border),
              InkWell(
                onTap: () => _downloadReceipt(context),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.download_outlined,
                          size: 14, color: AppColors.teal),
                      const SizedBox(width: 6),
                      Text(
                        'Receipt ${widget.linkedPayment!['receipt_number'] ?? ''} · ${widget.linkedPayment!['payment_date'] ?? ''}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.teal),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _leading() {
    if (_isPaid) {
      return Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
            color: AppColors.teal.withOpacity(0.1),
            shape: BoxShape.circle),
        child: const Icon(Icons.check, color: AppColors.teal, size: 16),
      );
    }
    if (widget.isLocked) {
      return Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
            color: AppColors.muted.withOpacity(0.1),
            shape: BoxShape.circle),
        child:
            const Icon(Icons.lock_outline, color: AppColors.muted, size: 16),
      );
    }
    return Checkbox(
      value: widget.selected,
      onChanged: widget.onToggle != null ? (_) => widget.onToggle!() : null,
      activeColor: AppColors.teal,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    );
  }

  Widget _trailing(double amount) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.text),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.item['status']?.toString() ?? '',
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: _statusColor),
            ),
          ),
        ],
      );

  Future<void> _downloadReceipt(BuildContext context) async {
    final payment = widget.linkedPayment!;
    final doc = pw.Document();
    final amount = (payment['amount'] as num? ?? 0).toDouble();
    final lineItems = (payment['line_items'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.teal,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('PAYMENT RECEIPT',
                    style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
                pw.SizedBox(height: 4),
                pw.Text(widget.child.schoolName,
                    style: const pw.TextStyle(
                        fontSize: 13, color: PdfColors.white)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Student: ${widget.child.studentName}',
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.Text('Receipt: ${payment['receipt_number'] ?? ''}',
                  style: const pw.TextStyle(fontSize: 12)),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Date: ${payment['payment_date'] ?? ''}',
                  style: const pw.TextStyle(fontSize: 12)),
              pw.Text('Method: ${payment['payment_method'] ?? ''}',
                  style: const pw.TextStyle(fontSize: 12)),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Divider(),
          if (lineItems.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text('Fee Breakdown',
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            ...lineItems.map((li) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Row(
                    mainAxisAlignment:
                        pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(li['component_name']?.toString() ?? '',
                          style: const pw.TextStyle(fontSize: 12)),
                      pw.Text(
                          '₹${(li['amount'] as num? ?? 0).toStringAsFixed(0)}',
                          style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                )),
            pw.Divider(),
          ],
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('TOTAL PAID',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text('₹${amount.toStringAsFixed(0)}',
                  style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.teal)),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text('This is a computer-generated receipt.',
              style: const pw.TextStyle(
                  fontSize: 10, color: PdfColors.grey)),
        ],
      ),
    ));

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'receipt_${payment['receipt_number'] ?? 'fee'}.pdf',
    );
  }
}

// ── Shared widgets & painters ─────────────────────────────────────────────────

class _SumRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _SumRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text('₹${value.toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900, color: color)),
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
    const stroke = 12.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

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
  bool shouldRepaint(_DonutPainter old) =>
      old.paid != paid || old.total != total;
}

String _fmtAmount(double v) => '₹${v.toStringAsFixed(0)}';
