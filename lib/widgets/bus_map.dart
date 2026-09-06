import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/theme.dart';

/// issue-4/10: a single-bus live-position map. Uses OpenStreetMap tiles (no
/// vendor API key, no billing setup) -- same choice as the admin web GPS
/// map, for the same reason: this is pins + a status card, not something
/// that needs Google Maps' extra polish.
///
/// Brought to parity with the admin web map fix (same session): a real bus
/// icon instead of an emoji; ignition-off greys the marker independently of
/// the existing staleness signal (opacity), same two-signal split as web,
/// TR-008/TR-009. Converted from stateless to a MapController-backed widget
/// specifically because this screen already polls the bus's live position on
/// a timer (`transport.dart`'s `_locationTimer`) -- previously the map's
/// camera never moved after first paint, so a parent watching their child's
/// bus approach would see the marker silently drift toward the edge with no
/// follow. There's no "selection" concept here (always exactly one bus), so
/// unlike the multi-bus maps, following every update is simply correct, not
/// an optional mode.
///
/// TR-014 Decision C (2026-09-06): the marker now glides smoothly between
/// consecutive poll updates instead of snapping instantly (hand-rolled tween,
/// same approach as teacher_app's multi-bus map -- no new dependency), an
/// optional route polyline can be drawn under it, and a fullscreen toggle
/// opens the same map larger.
class BusMap extends StatefulWidget {
  final double latitude;
  final double longitude;
  final bool isStale;
  final bool? ignitionOn;
  final double height;
  final List<LatLng>? routePath;
  final bool fullscreenEnabled;
  const BusMap({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.isStale,
    this.ignitionOn,
    this.height = 220,
    this.routePath,
    this.fullscreenEnabled = true,
  });

  @override
  State<BusMap> createState() => _BusMapState();
}

class _BusMapState extends State<BusMap> with SingleTickerProviderStateMixin {
  final MapController _controller = MapController();
  late final AnimationController _glide = AnimationController(vsync: this, duration: const Duration(seconds: 2));
  late LatLng _glideFrom = LatLng(widget.latitude, widget.longitude);
  late LatLng _glideTo = LatLng(widget.latitude, widget.longitude);

  LatLng _lerp(LatLng a, LatLng b, double t) =>
      LatLng(a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t);

  LatLng get _displayed {
    final eased = Curves.easeInOut.transform(_glide.value);
    return _lerp(_glideFrom, _glideTo, eased);
  }

  @override
  void dispose() {
    _glide.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BusMap old) {
    super.didUpdateWidget(old);
    final newPoint = LatLng(widget.latitude, widget.longitude);
    if (widget.latitude != old.latitude || widget.longitude != old.longitude) {
      _glideFrom = _displayed;
      _glideTo = newPoint;
      _glide
        ..reset()
        ..forward();
      _controller.move(newPoint, _controller.camera.zoom);
    }
  }

  void _openFullscreen() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => FullscreenBusMap(
      latitude: widget.latitude, longitude: widget.longitude, isStale: widget.isStale,
      ignitionOn: widget.ignitionOn, routePath: widget.routePath,
    )));
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.ignitionOn == false ? AppColors.muted : AppColors.teal;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: widget.height,
            child: AnimatedBuilder(
              animation: _glide,
              builder: (context, _) => FlutterMap(
                mapController: _controller,
                options: MapOptions(
                  initialCenter: _glideTo,
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.edutrack.parent',
                  ),
                  if (widget.routePath != null && widget.routePath!.length > 1)
                    PolylineLayer(polylines: [
                      Polyline(points: widget.routePath!, strokeWidth: 4, color: AppColors.violet.withOpacity(0.6)),
                    ]),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _displayed,
                        width: 40,
                        height: 40,
                        child: Opacity(
                          opacity: widget.isStale ? 0.55 : 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.directions_bus, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors',
                          onTap: () {}),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (widget.fullscreenEnabled)
          Positioned(
            right: 8, top: 8,
            child: GestureDetector(
              onTap: _openFullscreen,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                child: const Icon(Icons.fullscreen, size: 20, color: AppColors.text),
              ),
            ),
          ),
      ],
    );
  }
}

class FullscreenBusMap extends StatelessWidget {
  final double latitude;
  final double longitude;
  final bool isStale;
  final bool? ignitionOn;
  final List<LatLng>? routePath;
  const FullscreenBusMap({
    super.key, required this.latitude, required this.longitude, required this.isStale,
    this.ignitionOn, this.routePath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Live Location', style: TextStyle(color: Colors.white)),
      ),
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: BusMap(
          latitude: latitude, longitude: longitude, isStale: isStale, ignitionOn: ignitionOn,
          routePath: routePath, height: MediaQuery.of(context).size.height, fullscreenEnabled: false,
        ),
      ),
    );
  }
}
