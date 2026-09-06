import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/bus_map.dart';

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
  //
  // Shortened 25s -> 4s -> 2s (2026-09-06, live-verified feedback): Admin
  // Web's own simulation ticks every 3s and patches its screen instantly, so
  // a slower poll here reads as "not moving" even when everything behind it
  // is working. 2s (below the 3s tick rate) is as close to real-time as
  // polling gets without WebSockets/SSE -- explicitly not pursued for this
  // simulator-only feature (real-time push infra deferred, decided
  // 2026-09-06: meaningful new infra -- WebSocket/SSE + Redis pub/sub +
  // client rework on 3 codebases -- to perfectly sync a bus that isn't real
  // hardware yet; GPS-01 still unresolved, see CLAUDE.md's "Customer Ready:
  // No" status).
  Map<String, dynamic>? _location;
  bool _locationLoading = true;
  Timer? _locationTimer;
  static const _pollInterval = Duration(seconds: 2);

  // EDR-0027 (TR-014 Decision B): pickup address + live ETA. Polled on the
  // same cadence as live location, above -- both are cheap reads over the
  // same underlying GPS data.
  Map<String, dynamic>? _pickupAddress;
  Map<String, dynamic>? _eta;
  bool _addressLoading = true;

  // TR-014 Decision C: the route's road-snapped polyline -- loaded once, not
  // re-polled, since a route's shape doesn't change tick to tick.
  List<LatLng>? _routePath;

  // TR-019: this child's recent stop-history -- loaded once per screen open,
  // same as routePath above; it's a look-back over already-recorded events,
  // not something that changes tick to tick like live location.
  List<Map<String, dynamic>>? _stopHistory;

  @override
  void initState() {
    super.initState();
    _load();
    _loadLocation();
    _loadAddressAndEta();
    _loadRoutePath();
    _loadStopHistory();
    _locationTimer = Timer.periodic(_pollInterval, (_) {
      _loadLocation();
      _loadAddressAndEta();
    });
  }

  Future<void> _loadStopHistory() async {
    try {
      final history = await ParentApiClient.getTransportStopHistory(widget.child.studentId);
      if (mounted) setState(() => _stopHistory = history);
    } catch (_) {
      // Same graceful-degradation rule as the rest of this screen -- a
      // history card that fails to load just doesn't render.
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRoutePath() async {
    try {
      final points = await ParentApiClient.getTransportRoutePath(widget.child.studentId);
      if (mounted) setState(() => _routePath = points);
    } catch (_) {
      // No path drawn is a harmless degradation -- the marker itself still works.
    }
  }

  Future<void> _loadAddressAndEta() async {
    try {
      final address = await ParentApiClient.getPickupAddress(widget.child.studentId);
      Map<String, dynamic>? eta;
      if (address != null) {
        try {
          eta = await ParentApiClient.getTransportEta(widget.child.studentId);
        } catch (_) {
          eta = null; // ETA is a bonus on top of a saved address, never blocks the screen
        }
      }
      if (mounted) setState(() { _pickupAddress = address; _eta = eta; _addressLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _addressLoading = false);
    }
  }

  Future<void> _openAddressSheet() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PickupAddressSheet(
        studentId: widget.child.studentId,
        existing: _pickupAddress,
      ),
    );
    if (saved == true) _loadAddressAndEta();
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
                  : _Body(
                      data: _data!, location: _location, locationLoading: _locationLoading,
                      pickupAddress: _pickupAddress, eta: _eta, addressLoading: _addressLoading,
                      onEditAddress: _openAddressSheet, routePath: _routePath,
                      stopHistory: _stopHistory,
                    ),
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
  final Map<String, dynamic>? pickupAddress;
  final Map<String, dynamic>? eta;
  final bool addressLoading;
  final VoidCallback onEditAddress;
  final List<LatLng>? routePath;
  final List<Map<String, dynamic>>? stopHistory;
  const _Body({
    required this.data, required this.location, required this.locationLoading,
    required this.pickupAddress, required this.eta, required this.addressLoading,
    required this.onEditAddress, required this.routePath, required this.stopHistory,
  });

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
          _LiveLocationCard(location: location, loading: locationLoading, routePath: routePath),
          if (location != null) const SizedBox(height: 16),
          if (!addressLoading)
            _EtaAndAddressCard(pickupAddress: pickupAddress, eta: eta, onEdit: onEditAddress),
          if (!addressLoading) const SizedBox(height: 16),
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
            if (data['driver_photo_url'] != null) _StaffPhotoRow(photoUrl: data['driver_photo_url'] as String),
            _Row(label: 'Name', value: _v('driver_name')),
            _Row(label: 'Phone', value: _v('driver_phone')),
          ]),

          if (data['helper_name'] != null && data['helper_name'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            _Card(title: 'HELPER', children: [
              if (data['helper_photo_url'] != null) _StaffPhotoRow(photoUrl: data['helper_photo_url'] as String),
              _Row(label: 'Name', value: _v('helper_name')),
              _Row(label: 'Phone', value: _v('helper_phone')),
            ]),
          ],

          if (stopHistory != null) ...[
            const SizedBox(height: 12),
            _StopHistoryCard(history: stopHistory!),
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

// TR-020: driver/helper photo, only ever present when an admin/dispatch
// teacher has confirmed the driver/helper's consent for it (see
// transport_staff.photo_consent_confirmed_at, backend-side) -- this widget
// just renders whatever the backend already gated, no consent logic here.
class _StaffPhotoRow extends StatelessWidget {
  final String photoUrl;
  const _StaffPhotoRow({required this.photoUrl});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ClipOval(
          child: Image.network(
            photoUrl, width: 56, height: 56, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 56, height: 56,
              decoration: const BoxDecoration(color: AppColors.tealLight, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Text('👤', style: TextStyle(fontSize: 22)),
            ),
          ),
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

// ── Stop history (TR-019) ────────────────────────────────────────────────────
//
// Deliberately just this one child's own recent pickup/drop outcomes -- not
// a full-vehicle route map/breadcrumb (that stays admin-only, TR-021).

class _StopHistoryCard extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  const _StopHistoryCard({required this.history});

  (String, Color, Color) _statusStyle(String status) {
    switch (status) {
      case 'completed':
        return ('Completed', AppColors.teal, AppColors.tealLight);
      case 'missed':
        return ('Missed', AppColors.coral, AppColors.coralLight);
      case 'cancelled':
        return ('Cancelled', AppColors.muted, const Color(0xFFF3F4F6));
      default:
        return ('Pending', AppColors.muted, const Color(0xFFF3F4F6));
    }
  }

  // Matches health_incidents.dart's own _formatTime convention (no shared
  // helper between screens in this app -- see that file).
  String? _formatTime(String? iso) {
    if (iso == null) return null;
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'STOP HISTORY (LAST 7 DAYS)',
      children: history.isEmpty
          ? const [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('No pickup/drop activity recorded yet.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ),
            ]
          : history.map((entry) {
              final (label, fg, bg) = _statusStyle(entry['status']?.toString() ?? 'pending');
              final direction = entry['direction']?.toString() == 'drop' ? 'Drop' : 'Pickup';
              final stopName = entry['stop_name']?.toString();
              // The actual pickup/drop moment, not just the categorical status --
              // occurred_at was already returned by the backend but never rendered.
              final time = _formatTime(entry['occurred_at']?.toString()) ?? _formatTime(entry['planned_at']?.toString());
              final dateLine = time != null ? '${entry['date']} · $direction · $time' : '${entry['date']} · $direction';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dateLine, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text)),
                          if (stopName != null) Text(stopName, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
                    ),
                  ],
                ),
              );
            }).toList(),
    );
  }
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
  final List<LatLng>? routePath;
  const _LiveLocationCard({required this.location, required this.loading, required this.routePath});

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

    final lat = (position['latitude'] as num?)?.toDouble();
    final lng = (position['longitude'] as num?)?.toDouble();

    final shell = _Shell(
      state: state,
      title: 'Live Location',
      subtitle: switch (state) {
        _LiveState.live => 'Live · ${speed ?? 0} km/h${ignitionOn ? '' : ' · engine off'}',
        _LiveState.recent => 'Recently updated · $ageLabel',
        _LiveState.stale => 'Signal is stale · last seen $ageLabel',
        _LiveState.none => 'No GPS signal',
      },
    );

    // issue-4/10: the map itself, on top of the existing status card --
    // "where is the bus" was already answered in words (Live · 12 km/h);
    // this answers it visually, which is what was actually asked for.
    if (lat == null || lng == null) return shell;
    return Column(
      children: [
        BusMap(latitude: lat, longitude: lng, isStale: state == _LiveState.stale, ignitionOn: ignitionOn, routePath: routePath),
        const SizedBox(height: 10),
        shell,
      ],
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

// ── ETA + pickup address (EDR-0027, TR-014 Decision B) ───────────────────────
//
// Simulator-only accuracy until a real GPS vendor is connected (GPS-01) --
// this card doesn't know or care which data source it's reading, same as
// the rest of the live-location plumbing above.

class _EtaAndAddressCard extends StatelessWidget {
  final Map<String, dynamic>? pickupAddress;
  final Map<String, dynamic>? eta;
  final VoidCallback onEdit;
  const _EtaAndAddressCard({required this.pickupAddress, required this.eta, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    if (pickupAddress == null) {
      return GestureDetector(
        onTap: onEdit,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.tealLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.teal.withOpacity(0.3), width: 1.5),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Text('📍', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add a pickup/home address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.text)),
                    SizedBox(height: 2),
                    Text('Get an ETA and an alert when the bus is close', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.teal),
            ],
          ),
        ),
      );
    }

    final etaMinutes = eta?['eta_minutes'];
    final reason = eta?['reason'];
    final subtitle = etaMinutes != null
        ? 'Arriving in about ${etaMinutes.toStringAsFixed(0)} min'
        : reason == 'no_live_position'
            ? 'Waiting for the bus\'s live signal'
            : 'ETA unavailable right now';

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
            decoration: const BoxDecoration(color: AppColors.tealLight, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Text('⏱️', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ETA to your pickup address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.text)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          TextButton(onPressed: onEdit, child: const Text('Edit')),
        ],
      ),
    );
  }
}

class PickupAddressSheet extends StatefulWidget {
  final String studentId;
  final Map<String, dynamic>? existing;
  const PickupAddressSheet({super.key, required this.studentId, required this.existing});

  @override
  State<PickupAddressSheet> createState() => _PickupAddressSheetState();
}

class _PickupAddressSheetState extends State<PickupAddressSheet> {
  // Structured entry redesign (2026-09-06): replaces the old single free-text
  // field + two manual lat/long boxes -- nobody should have to know or type
  // their own GPS coordinates. Coordinates now only ever come from the
  // device itself (via "Use my current location"), never typed.
  Map<String, dynamic>? get _existingComponents =>
      widget.existing?['address_components'] as Map<String, dynamic>?;

  late final _houseNoCtrl = TextEditingController(text: _existingComponents?['house_no'] as String? ?? '');
  late final _sectorCtrl = TextEditingController(text: _existingComponents?['sector'] as String? ?? '');
  late final _addressLine1Ctrl = TextEditingController(
    text: _existingComponents?['address_line1'] as String? ?? widget.existing?['address_text'] as String? ?? '',
  );
  late final _landmarkCtrl = TextEditingController(text: _existingComponents?['landmark'] as String? ?? '');
  late final _cityCtrl = TextEditingController(text: _existingComponents?['city'] as String? ?? '');
  late final _stateCtrl = TextEditingController(text: _existingComponents?['state'] as String? ?? '');
  late final _pincodeCtrl = TextEditingController(text: _existingComponents?['pincode'] as String? ?? '');

  // Not shown to the user at all -- carried silently from either a prior save
  // (re-editing an existing address without necessarily re-capturing location)
  // or a fresh "Use my current location" tap.
  late double? _capturedLat = (widget.existing?['latitude'] as num?)?.toDouble();
  late double? _capturedLon = (widget.existing?['longitude'] as num?)?.toDouble();

  bool _consentChecked = false;
  bool _saving = false;
  bool _locating = false;

  @override
  void dispose() {
    _houseNoCtrl.dispose();
    _sectorCtrl.dispose();
    _addressLine1Ctrl.dispose();
    _landmarkCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final granted = permission == LocationPermission.always || permission == LocationPermission.whileInUse;
      if (!granted) {
        if (mounted) showSnack(context, 'Location permission is needed to fill this in automatically', error: true);
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) showSnack(context, 'Turn on location services and try again', error: true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final suggested = await ParentApiClient.reverseGeocode(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _capturedLat = pos.latitude;
        _capturedLon = pos.longitude;
        _houseNoCtrl.text = (suggested['house_no'] as String?) ?? _houseNoCtrl.text;
        _sectorCtrl.text = (suggested['sector'] as String?) ?? _sectorCtrl.text;
        _addressLine1Ctrl.text = (suggested['address_line1'] as String?) ?? _addressLine1Ctrl.text;
        _landmarkCtrl.text = (suggested['landmark'] as String?) ?? _landmarkCtrl.text;
        _cityCtrl.text = (suggested['city'] as String?) ?? _cityCtrl.text;
        _stateCtrl.text = (suggested['state'] as String?) ?? _stateCtrl.text;
        _pincodeCtrl.text = (suggested['pincode'] as String?) ?? _pincodeCtrl.text;
      });
      showSnack(context, 'Location captured — please check the fields below before saving');
    } catch (_) {
      if (mounted) showSnack(context, 'Could not get your location — check GPS and try again', error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    final pincode = _pincodeCtrl.text.trim();
    if (pincode.isEmpty) {
      showSnack(context, 'Pincode is required', error: true);
      return;
    }
    if (_capturedLat == null || _capturedLon == null) {
      showSnack(context, 'Tap "Use my current location" so we know where to look for the bus', error: true);
      return;
    }
    if (!_consentChecked) {
      showSnack(context, 'Please confirm you agree to share this location', error: true);
      return;
    }

    final components = <String, String?>{
      'house_no': _houseNoCtrl.text.trim().isEmpty ? null : _houseNoCtrl.text.trim(),
      'sector': _sectorCtrl.text.trim().isEmpty ? null : _sectorCtrl.text.trim(),
      'address_line1': _addressLine1Ctrl.text.trim().isEmpty ? null : _addressLine1Ctrl.text.trim(),
      'landmark': _landmarkCtrl.text.trim().isEmpty ? null : _landmarkCtrl.text.trim(),
      'city': _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
      'state': _stateCtrl.text.trim().isEmpty ? null : _stateCtrl.text.trim(),
      'pincode': pincode,
    };
    // The single composed display string every existing consumer of
    // address_text (notifications, admin-entry parity) still expects.
    final addressText = [
      if (components['house_no'] != null) components['house_no'],
      if (components['address_line1'] != null) components['address_line1'],
      if (components['sector'] != null) components['sector'],
      if (components['landmark'] != null) 'near ${components['landmark']}',
      if (components['city'] != null) components['city'],
      if (components['state'] != null) components['state'],
      pincode,
    ].join(', ');

    setState(() => _saving = true);
    try {
      await ParentApiClient.savePickupAddress(
        widget.studentId,
        addressText: addressText,
        latitude: _capturedLat!,
        longitude: _capturedLon!,
        addressComponents: components,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(20))),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pickup / Home Address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.text)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _locating ? null : _useCurrentLocation,
                        icon: _locating
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.my_location, size: 18),
                        label: Text(_capturedLat == null ? 'Use my current location' : 'Update from my current location'),
                      ),
                    ),
                    if (_capturedLat != null)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('Location captured — you can still edit the fields below.',
                            style: TextStyle(fontSize: 11, color: AppColors.muted)),
                      ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _houseNoCtrl, decoration: const InputDecoration(labelText: 'House / Flat No.'))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: _sectorCtrl, decoration: const InputDecoration(labelText: 'Sector / Area'))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _addressLine1Ctrl,
                      decoration: const InputDecoration(labelText: 'Address Line 1', hintText: 'e.g. Green Meadows Society'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _landmarkCtrl,
                      decoration: const InputDecoration(labelText: 'Nearby Landmark (optional)'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _cityCtrl, decoration: const InputDecoration(labelText: 'City'))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: _stateCtrl, decoration: const InputDecoration(labelText: 'State'))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _pincodeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Pincode *'),
                    ),
                    const SizedBox(height: 14),
                    CheckboxListTile(
                      value: _consentChecked,
                      onChanged: (v) => setState(() => _consentChecked = v ?? false),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'I agree to share this location so EduTrack can show me an ETA and alert me when the bus is near.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        child: _saving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text('Save'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
