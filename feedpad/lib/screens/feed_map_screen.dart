import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class FeedMapScreen extends StatefulWidget {
  const FeedMapScreen({super.key});

  @override
  State<FeedMapScreen> createState() => _FeedMapScreenState();
}

class _FeedMapScreenState extends State<FeedMapScreen> {
  final MapController mapController = MapController();
  final List<Marker> _markers = [];

  // Başlangıç konumu (İstanbul örnek olarak)
  static const LatLng _initialCenter = LatLng(41.0082, 28.9784);
  static const double _initialZoom = 12.0;

  /// Haritada uzun basış (2 saniye) ile marker ekler
  void _onMapLongPress(TapPosition tapPosition, LatLng latlng) {
    _addMarker(latlng);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: _initialCenter,
          initialZoom: _initialZoom,
          onLongPress: _onMapLongPress,
        ),
        children: [
          TileLayer(
            // OSM kullanım uyarılarını gidermek için subdomains kaldırılabilir,
            // ancak şimdilik logdaki uyarıya rağmen bırakıyorum.
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: 'com.example.feedpad',
          ),
          MarkerLayer(
            markers: _markers,
          ),
        ],
      ),
    );
  }

  /// Belirtilen konuma yeni bir marker ekler
  void _addMarker(LatLng position) {
    setState(() {
      final newMarker = Marker(
        point: position,
        width: 80.0,
        height: 80.0,
        child: const Icon(
          Icons.location_on,
          color: Colors.red,
          size: 40.0,
        ),
      );
      _markers.add(newMarker);
    });
    print(
        'Marker eklendi: ${position.latitude}, ${position.longitude} - Toplam marker sayısı: ${_markers.length}');
  }

  @override
  void dispose() {
    super.dispose();
  }
}
