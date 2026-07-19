import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';

const _actionLabels = {
  'first_aid':        'First Aid Given',
  'medication':       'Medication Given',
  'parent_called':    'Parent Called',
  'sent_home':        'Sent Home',
  'sent_to_hospital': 'Sent to Hospital',
  'other':            'Other Action',
};

const _actionIcons = {
  'first_aid':        Icons.healing_rounded,
  'medication':       Icons.medication_rounded,
  'parent_called':    Icons.phone_rounded,
  'sent_home':        Icons.home_rounded,
  'sent_to_hospital': Icons.local_hospital_rounded,
  'other':            Icons.more_horiz_rounded,
};

class HealthIncidentsScreen extends StatefulWidget {
  final ChildInfo child;
  const HealthIncidentsScreen({super.key, required this.child});

  @override
  State<HealthIncidentsScreen> createState() => _HealthIncidentsScreenState();
}

class _HealthIncidentsScreenState extends State<HealthIncidentsScreen> {
  List<Map<String, dynamic>> _incidents = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ParentApiClient.getHealthIncidents(widget.child.studentId);
      if (mounted) setState(() { _incidents = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.child.studentName} — Health Records'),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _incidents.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🏥', style: TextStyle(fontSize: 48)),
                          SizedBox(height: 12),
                          Text('No health incidents recorded', style: TextStyle(fontSize: 16, color: AppColors.muted)),
                          SizedBox(height: 6),
                          Text('The school will notify you if anything happens', style: TextStyle(fontSize: 13, color: AppColors.muted), textAlign: TextAlign.center),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        itemCount: _incidents.length,
                        itemBuilder: (ctx, i) => _IncidentCard(incident: _incidents[i]),
                      ),
                    ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  final Map<String, dynamic> incident;
  const _IncidentCard({required this.incident});

  @override
  Widget build(BuildContext context) {
    final actions = (incident['actions'] as List?)?.cast<String>() ?? [];
    final hasMedication = actions.contains('medication');
    final sentHome = actions.contains('sent_home');
    final sentHospital = actions.contains('sent_to_hospital');
    final isSerious = sentHospital;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSerious ? const Color(0xFFFCA5A5) : AppColors.border,
          width: isSerious ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date + serious badge
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 14, color: isSerious ? const Color(0xFFDC2626) : AppColors.muted),
                const SizedBox(width: 4),
                Text(
                  _formatDate(incident['occurred_at'] as String?),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSerious ? const Color(0xFFDC2626) : AppColors.muted,
                  ),
                ),
                if (isSerious) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(20)),
                    child: const Text('Hospital', style: TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // Description
            Text(
              incident['description'] as String? ?? '',
              style: const TextStyle(fontSize: 14, color: AppColors.text, height: 1.4, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),

            // Action chips
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: actions.map((a) {
                final label = _actionLabels[a] ?? a;
                final icon = _actionIcons[a] ?? Icons.circle;
                final isAlert = a == 'sent_to_hospital';
                final bg = isAlert ? const Color(0xFFFEE2E2) : AppColors.bg;
                final fg = isAlert ? const Color(0xFFDC2626) : AppColors.muted;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isAlert ? const Color(0xFFFCA5A5) : AppColors.border),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, size: 12, color: fg),
                    const SizedBox(width: 4),
                    Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
                  ]),
                );
              }).toList(),
            ),

            // Medication info
            if (hasMedication && incident['medication_name'] != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.medication_rounded, size: 16, color: primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(incident['medication_name'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: primary)),
                          if (incident['medication_consent'] == true)
                            const Text('Consent obtained before administering', style: TextStyle(fontSize: 11, color: Color(0xFF16A34A))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Pickup info
            if ((sentHome || sentHospital) && incident['pickup_person_name'] != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_car_rounded, size: 16, color: Color(0xFF16A34A)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Picked up by ${incident['pickup_person_name']}${incident['pickup_person_relation'] != null ? ' (${incident['pickup_person_relation']})' : ''}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                          ),
                          if (incident['pickup_person_phone'] != null)
                            Text(incident['pickup_person_phone'] as String, style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A))),
                          if (incident['pickup_time'] != null)
                            Text('Left at ${_formatTime(incident['pickup_time'] as String)}', style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Notes
            const SizedBox(height: 10),
            Text(
              incident['notes'] as String? ?? '',
              style: const TextStyle(fontSize: 13, color: AppColors.text2, height: 1.4),
            ),

            const SizedBox(height: 8),
            Text(
              'Reported by ${incident['reporter_name'] ?? 'school staff'}',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return iso; }
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return iso; }
  }
}
