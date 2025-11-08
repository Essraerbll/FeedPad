import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:developer' as developer;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FeedPad Harita',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const MapScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  String? _mapError;

  // Başlangıç konumu (İstanbul örnek olarak)
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(41.0082, 28.9784),
    zoom: 12.0,
  );

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

  @override
  void dispose() {
    mapController?.dispose();
    super.dispose();
  }
}
