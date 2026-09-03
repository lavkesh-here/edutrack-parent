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
class BusMap extends StatefulWidget {
  final double latitude;
  final double longitude;
  final bool isStale;
  final bool? ignitionOn;
  final double height;
  const BusMap({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.isStale,
    this.ignitionOn,
    this.height = 220,
  });

  @override
  State<BusMap> createState() => _BusMapState();
}

class _BusMapState extends State<BusMap> {
  final MapController _controller = MapController();

  @override
  void didUpdateWidget(covariant BusMap old) {
    super.didUpdateWidget(old);
    if (widget.latitude != old.latitude || widget.longitude != old.longitude) {
      _controller.move(LatLng(widget.latitude, widget.longitude), _controller.camera.zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final point = LatLng(widget.latitude, widget.longitude);
    final color = widget.ignitionOn == false ? AppColors.muted : AppColors.teal;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        child: FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: point,
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
            MarkerLayer(
              markers: [
                Marker(
                  point: point,
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
    );
  }
}
