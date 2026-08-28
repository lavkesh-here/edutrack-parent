import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class TransportScreen extends StatefulWidget {
  final ChildInfo child;
  const TransportScreen({super.key, required this.child});

  @override
  State<TransportScreen> createState() => _State();
}

class _State extends State<TransportScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  // Live location — polled independently of the static route/driver info
  // above (V1 polling, not a socket — see backend/docs, GPS section of the
  // transport/GPS mission: a sensible interval, never hammering the vendor,
  // with an explicit stale/offline state rather than pretending a bus is
  // still "live" once its last fix is old).
  Map<String, dynamic>? _location;
  bool _locationLoading = true;
  Timer? _locationTimer;
  static const _pollInterval = Duration(seconds: 25);

  @override
  void initState() {
    super.initState();
    _load();
    _loadLocation();
    _locationTimer = Timer.periodic(_pollInterval, (_) => _loadLocation());
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ParentApiClient.getTransport(widget.child.studentId);
      if (mounted) setState(() { _data = data; _loading = false; });
    } on ApiError catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load transport info.'; _loading = false; });
    }
  }

  Future<void> _loadLocation() async {
    try {
      final data = await ParentApiClient.getTransportLocation(widget.child.studentId);
      if (mounted) setState(() { _location = data; _locationLoading = false; });
    } catch (_) {
      // Live location is a bonus on top of the static route info above —
      // never blocks or errors out the whole screen if it fails; the card
      // itself just won't render.
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Transport'), leading: const BackButton()),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.coral)))
              : _data == null || _data!['assigned'] == false
                  ? _NoTransport()
                  : _Body(data: _data!, location: _location, locationLoading: _locationLoading),
    );
  }
}

class _NoTransport extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🚌', style: TextStyle(fontSize: 56)),
              SizedBox(height: 16),
              Text('No Transport Assigned', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
              SizedBox(height: 8),
              Text('No transport route has been assigned to this student.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      );
}

class _Body extends StatelessWidget {
  final Map<String, dynamic> data;
  final Map<String, dynamic>? location;
  final bool locationLoading;
  const _Body({required this.data, required this.location, required this.locationLoading});

  String _v(String key, [String fallback = '—']) {
    final v = data[key];
    if (v == null || v.toString().isEmpty) return fallback;
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LiveLocationCard(location: location, loading: locationLoading),
          if (location != null) const SizedBox(height: 16),
          // Time banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.teal, Color(0xFF0D9488)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(child: _TimeBlock(label: 'PICK UP', time: _v('pickup_time'), icon: '🌅')),
                Container(width: 1, height: 50, color: Colors.white30),
                Expanded(child: _TimeBlock(label: 'DROP OFF', time: _v('dropoff_time'), icon: '🌆')),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Route & vehicle
          _Card(title: 'ROUTE DETAILS', children: [
            _Row(label: 'Route', value: _v('route_name')),
            _Row(label: 'Vehicle No.', value: _v('vehicle_number')),
          ]),
          const SizedBox(height: 12),

          // Pick up details
          _Card(title: 'PICK UP DETAILS', children: [
            _Row(label: 'Stop', value: _v('pickup_stop')),
            _Row(label: 'Time', value: _v('pickup_time')),
          ]),
          const SizedBox(height: 12),

          // Drop off details
          _Card(title: 'DROP OFF DETAILS', children: [
            _Row(label: 'Stop', value: _v('dropoff_stop')),
            _Row(label: 'Time', value: _v('dropoff_time')),
          ]),
          const SizedBox(height: 12),

          // Driver
          _Card(title: 'DRIVER', children: [
            _Row(label: 'Name', value: _v('driver_name')),
            _Row(label: 'Phone', value: _v('driver_phone')),
          ]),

          if (data['helper_name'] != null && data['helper_name'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            _Card(title: 'HELPER', children: [
              _Row(label: 'Name', value: _v('helper_name')),
              _Row(label: 'Phone', value: _v('helper_phone')),
            ]),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  final String label;
  final String time;
  final String icon;
  const _TimeBlock({required this.label, required this.time, required this.icon});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text(time, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
        ],
      );
}

class _Card extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Card({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [SectionHeader(title), ...children],
        ),
      );
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 110), child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600))),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: AppColors.text, fontWeight: FontWeight.w700))),
          ],
        ),
      );
}

// ── Live location (TR-006/EDR-0019) ─────────────────────────────────────────
//
// Four states, matching the mission's own "never show Live when data is
// stale" requirement: Live (fix < 2 min old), Recently Updated (< 5 min,
// matches the backend's own is_stale cutoff), Stale (older but a fix
// exists), and No GPS (position is null — device/vehicle not reporting at
// all). "available: false" (no vehicle linked to this route yet) is a
// distinct fifth case, shown as its own quiet placeholder rather than
// folded into "No GPS".

enum _LiveState { live, recent, stale, none }

class _LiveLocationCard extends StatelessWidget {
  final Map<String, dynamic>? location;
  final bool loading;
  const _LiveLocationCard({required this.location, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading && location == null) return const SizedBox.shrink();
    if (location == null) return const SizedBox.shrink(); // silent failure — the static card above still works
    if (location!['available'] != true) {
      return const _Shell(
        state: _LiveState.none,
        title: 'Live Location',
        subtitle: 'Live tracking is not set up for this bus yet.',
      );
    }

    final position = location!['position'] as Map<String, dynamic>?;
    if (position == null) {
      return const _Shell(
        state: _LiveState.none,
        title: 'Live Location',
        subtitle: 'Waiting for the first GPS signal from this bus.',
      );
    }

    final lastUpdate = DateTime.tryParse(position['last_update']?.toString() ?? '');
    final age = lastUpdate == null ? null : DateTime.now().toUtc().difference(lastUpdate.toUtc());
    final state = age == null
        ? _LiveState.stale
        : age.inMinutes < 2
            ? _LiveState.live
            : age.inMinutes < 5
                ? _LiveState.recent
                : _LiveState.stale;

    final speed = position['speed_kmh'];
    final ignitionOn = position['ignition_on'] == true;
    final ageLabel = age == null
        ? 'unknown'
        : age.inSeconds < 60
            ? 'just now'
            : age.inMinutes < 60
                ? '${age.inMinutes} min ago'
                : age.inHours < 24
                    ? '${age.inHours}h ago'
                    : '${age.inDays}d ago';

    return _Shell(
      state: state,
      title: 'Live Location',
      subtitle: switch (state) {
        _LiveState.live => 'Live · ${speed ?? 0} km/h${ignitionOn ? '' : ' · engine off'}',
        _LiveState.recent => 'Recently updated · $ageLabel',
        _LiveState.stale => 'Signal is stale · last seen $ageLabel',
        _LiveState.none => 'No GPS signal',
      },
    );
  }
}

class _Shell extends StatelessWidget {
  final _LiveState state;
  final String title;
  final String subtitle;
  const _Shell({required this.state, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final (dot, dotBg) = switch (state) {
      _LiveState.live => ('🟢', AppColors.greenLight),
      _LiveState.recent => ('🟡', const Color(0xFFFEF9C3)),
      _LiveState.stale => ('🟠', const Color(0xFFFFE9D6)),
      _LiveState.none => ('⚪️', const Color(0xFFF3F4F6)),
    };
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: dotBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(dot, style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.text)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
