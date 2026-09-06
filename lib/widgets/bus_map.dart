import 'dart:math' as math;
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
                        width: 34,
                        height: 34,
                        child: Opacity(
                          opacity: widget.isStale ? 0.55 : 1,
                          // Live-verified feedback (2026-09-06, teacher_app's
                          // GPS map): a proper bus glyph instead of a plain
                          // circle+icon marker -- same drawn shape used there,
                          // for visual parity across every map in the app.
                          // No heading data flows to this endpoint yet, so it
                          // stays upright rather than guessing a direction.
                          child: BusGlyph(color: color, headingDeg: null, size: 34),
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

/// Same drawn bus silhouette as teacher_app's BusMap (kept in sync
/// deliberately -- see that file's own docstring for the full reasoning);
/// duplicated rather than shared because these two apps don't share a
/// package, matching this file's existing "brought to parity" pattern for
/// every other marker-styling decision.
class BusGlyph extends StatelessWidget {
  final Color color;
  final double? headingDeg;
  final double size;
  const BusGlyph({super.key, required this.color, required this.headingDeg, required this.size});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: (headingDeg ?? 0) * math.pi / 180,
      child: CustomPaint(
        size: Size(size, size),
        painter: _BusGlyphPainter(color: color),
      ),
    );
  }
}

class _BusGlyphPainter extends CustomPainter {
  final Color color;
  const _BusGlyphPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.22, h * 0.06, w * 0.56, h * 0.88),
      Radius.circular(w * 0.14),
    );
    canvas.drawRRect(body, Paint()..color = Colors.black26..style = PaintingStyle.fill);
    canvas.drawRRect(body.shift(const Offset(0, -1)), Paint()..color = color..style = PaintingStyle.fill);
    canvas.drawRRect(
      body.shift(const Offset(0, -1)),
      Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = w * 0.045,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.30, h * 0.12, w * 0.40, h * 0.16),
        Radius.circular(w * 0.05),
      ),
      Paint()..color = Colors.white.withOpacity(0.85),
    );
    final headlightPaint = Paint()..color = const Color(0xFFFFE58A);
    canvas.drawCircle(Offset(w * 0.30, h * 0.10), w * 0.045, headlightPaint);
    canvas.drawCircle(Offset(w * 0.70, h * 0.10), w * 0.045, headlightPaint);
  }

  @override
  bool shouldRepaint(covariant _BusGlyphPainter old) => old.color != color;
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
