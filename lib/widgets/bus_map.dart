import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/theme.dart';

/// issue-4/10: a single-bus live-position map. Uses OpenStreetMap tiles (no
/// vendor API key, no billing setup) -- same choice as the admin web GPS
/// map, for the same reason: this is pins + a status card, not something
/// that needs Google Maps' extra polish.
class BusMap extends StatelessWidget {
  final double latitude;
  final double longitude;
  final bool isStale;
  final double height;
  const BusMap({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.isStale,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        child: FlutterMap(
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
                  child: Container(
                    decoration: BoxDecoration(
                      color: isStale ? AppColors.muted : AppColors.teal,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    alignment: Alignment.center,
                    child: const Text('🚌', style: TextStyle(fontSize: 18)),
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
