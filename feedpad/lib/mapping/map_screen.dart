import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:developer' as developer;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  String? _mapError;
  final Set<Marker> _markers = {};
  int _markerIdCounter = 0;

  // Başlangıç konumu (İstanbul örnek olarak)
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(41.0082, 28.9784),
    zoom: 12.0,
  );

  /// Haritada uzun basış (2 saniye) ile marker ekler
  void _onMapLongPress(LatLng position) {
    _addMarker(position);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialPosition,
            onMapCreated: (GoogleMapController controller) {
              try {
                mapController = controller;
                developer.log('Google Maps başarıyla oluşturuldu');
                setState(() {
                  _mapError = null;
                });
              } catch (e) {
                developer.log('Google Maps oluşturulurken hata: $e', error: e);
                setState(() {
                  _mapError = 'Harita yüklenirken hata oluştu: $e';
                });
              }
            },
            onLongPress: _onMapLongPress,
            markers: _markers,
            mapType: MapType.normal,
            zoomControlsEnabled: true,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            // Performans için tilt ve rotate gesture'ları kapatıldı
            tiltGesturesEnabled: false,
            rotateGesturesEnabled: false,
            myLocationButtonEnabled: true,
            // Performans için myLocationEnabled geçici olarak kapatıldı
            // İhtiyaç duyulursa location permission ekleyip açılabilir
            myLocationEnabled: false,
            compassEnabled: true,
            trafficEnabled: false,
            // Performans için buildings kapatıldı
            buildingsEnabled: false,
            mapToolbarEnabled: false,
            // Performans optimizasyonları
            liteModeEnabled: false,
            minMaxZoomPreference: const MinMaxZoomPreference(3.0, 20.0),
            // Render optimizasyonları - frame buffer hatalarını azaltmak için
            padding: EdgeInsets.zero,
          ),
          if (_mapError != null)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _mapError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _mapError = null;
                        });
                      },
                      child: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Belirtilen konuma yeni bir marker ekler
  void _addMarker(LatLng position) {
    setState(() {
      final String markerId = 'marker_${_markerIdCounter++}';
      final newMarker = Marker(
        markerId: MarkerId(markerId),
        position: position,
        infoWindow: InfoWindow(
          title: 'İşaretçi $_markerIdCounter',
          snippet:
              '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
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
    mapController?.dispose();
    super.dispose();
  }
}
