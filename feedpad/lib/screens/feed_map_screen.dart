import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class FeedMapScreen extends StatefulWidget {
  const FeedMapScreen({super.key});

  @override
  State<FeedMapScreen> createState() => _FeedMapScreenState();
}

class _FeedMapScreenState extends State<FeedMapScreen> {
  final MapController mapController = MapController();
  final List<Marker> _markers = [];
  bool _isLocationLoaded = false;

  // Başlangıç konumu (İstanbul örnek olarak)
  static const LatLng _initialCenter = LatLng(41.0082, 28.9784);
  static const double _initialZoom = 12.0;
  static const double _userLocationZoom = 18.0; // Cadde seviyesi için zoom

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  /// Konum izni iste ve konum al
  Future<void> _requestLocationPermission() async {
    if (_isLocationLoaded) return;

    try {
      // Konum izni durumunu kontrol et
      PermissionStatus status = await Permission.location.status;

      if (status.isDenied) {
        // İzin iste
        status = await Permission.location.request();
      }

      if (status.isGranted) {
        // İzin verildi, konumu al
        await _getCurrentLocation();
      } else {
        // İzin reddedildi, İstanbul'a zoom yap
        _zoomToIstanbul();
      }
    } catch (e) {
      print('Konum izni hatası: $e');
      _zoomToIstanbul();
    }
  }

  /// Kullanıcının mevcut konumunu al
  Future<void> _getCurrentLocation() async {
    try {
      // Konum servislerinin açık olup olmadığını kontrol et
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _zoomToIstanbul();
        return;
      }

      // Konum al
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Haritaya kullanıcı konumuna zoom yap
      final userLocation = LatLng(position.latitude, position.longitude);

      if (mounted) {
        // Kısa bir gecikme ile haritanın yüklenmesini bekle
        await Future.delayed(const Duration(milliseconds: 500));
        mapController.move(userLocation, _userLocationZoom);

        setState(() {
          _isLocationLoaded = true;
        });
      }
    } catch (e) {
      print('Konum alma hatası: $e');
      _zoomToIstanbul();
    }
  }

  /// İstanbul'a zoom yap
  void _zoomToIstanbul() {
    if (mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          mapController.move(_initialCenter, _initialZoom);
          setState(() {
            _isLocationLoaded = true;
          });
        }
      });
    }
  }

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
            // OpenStreetMap tile layer
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: 'com.example.feedpad',
            maxZoom: 19,
            minZoom: 1,
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
