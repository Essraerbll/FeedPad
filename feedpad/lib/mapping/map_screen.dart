import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:developer' as developer;
import 'package:feedpad/profile/profile_screen.dart'; // Profil Ekranı için import

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController mapController = MapController(); // GoogleMapController yerine MapController
  // String? _mapError; // Artık kullanılmıyor
  final List<Marker> _markers = []; // Set<Marker> yerine List<Marker>
  // int _markerIdCounter = 0; // Artık kullanılmıyor

  // Başlangıç konumu (İstanbul örnek olarak)
  static const LatLng _initialCenter = LatLng(41.0082, 28.9784); // CameraPosition yerine LatLng
  static const double _initialZoom = 12.0;

  /// Haritada uzun basış (2 saniye) ile marker ekler
  void _onMapLongPress(TapPosition tapPosition, LatLng latlng) {
    _addMarker(latlng);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Harita'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => const ProfileScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SizedBox.expand(
        child: FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: _initialCenter, // 'center' yerine 'initialCenter'
            initialZoom: _initialZoom, // 'zoom' yerine 'initialZoom'
            onLongPress: _onMapLongPress,
          ),
          children: [
            TileLayer(
              // Use subdomains to improve tile loading and reduce missing tile blocks
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.example.feedpad', // Uygulamanızın paket adı
            ),
            MarkerLayer(
              markers: _markers,
            ),
          ],
        ),
      ),
    );
  }

  /// Belirtilen konuma yeni bir marker ekler
  void _addMarker(LatLng position) {
    setState(() {
      // final String markerId = 'marker_${_markerIdCounter++}'; // Artık kullanılmıyor
      final newMarker = Marker(
        point: position,
        width: 80.0,
        height: 80.0,
        child: const Icon( // 'builder' yerine 'child'
          Icons.location_on,
          color: Colors.red,
          size: 40.0,
        ),
      );
      _markers.add(newMarker);
    });
    developer.log(
      'Marker eklendi: ${position.latitude}, ${position.longitude} - Toplam marker sayısı: ${_markers.length}',
    );
  }

  @override
  void dispose() {
    // mapController?.dispose(); // flutter_map için dispose gerekmez
    super.dispose();
  }
}
