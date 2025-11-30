import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'add_marker_screen.dart';

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

  /// Haritada uzun basış ile marker ekleme formunu açar
  void _onMapLongPress(TapPosition tapPosition, LatLng latlng) async {
    // Marker ekleme formunu popup olarak aç
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddMarkerScreen(position: latlng),
    );

    // Eğer form başarıyla tamamlandıysa marker ekle
    if (result != null) {
      final type = result['type'] as String;
      final position = result['position'] as LatLng;
      final petType = result['petType'] as String?;
      final waterLiters = result['waterLiters'] as double?;
      final isWaterEnough = result['isWaterEnough'] as String?;
      _addMarker(position, type,
          petType: petType,
          waterLiters: waterLiters,
          isWaterEnough: isWaterEnough);
    }
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
            // OpenStreetMap - Renkli harita, dükkan isimleri görünür
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
  void _addMarker(
    LatLng position,
    String type, {
    String? petType,
    double? waterLiters,
    String? isWaterEnough,
  }) {
    setState(() {
      Color markerColor;
      IconData iconData;

      if (type == 'food' && petType != null) {
        // Food + Cat/Dog için: Yes = yeşil, Maybe = turuncu
        markerColor = isWaterEnough == 'yes' ? Colors.green : Colors.orange;
        // Cat için kedi patisi, Dog için donut ikonu
        if (petType == 'cat') {
          iconData = Icons.pets; // Kedi patisi için pets ikonu
        } else if (petType == 'dog') {
          iconData = Icons.donut_large; // Köpek için donut ikonu
        } else {
          iconData = Icons.restaurant;
        }
      } else if (type == 'water') {
        // Water için: Yes = yeşil, Maybe = turuncu
        markerColor = isWaterEnough == 'yes' ? Colors.green : Colors.orange;
        iconData = Icons.water_drop;
      } else if (type == 'food') {
        // Food seçildi ama pet type seçilmedi (eski durum için)
        markerColor = Colors.orange;
        iconData = Icons.restaurant;
      } else {
        // Varsayılan
        markerColor = Colors.blue;
        iconData = Icons.location_on;
      }

      final newMarker = Marker(
        point: position,
        width: 50.0,
        height: 50.0,
        child: Container(
          decoration: BoxDecoration(
            color: markerColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 2.0,
            ),
          ),
          child: Icon(
            iconData,
            color: Colors.white,
            size: 25.0,
          ),
        ),
      );
      _markers.add(newMarker);
    });
    print(
        'Marker eklendi: ${position.latitude}, ${position.longitude} - Type: $type - Toplam marker sayısı: ${_markers.length}');
  }

  @override
  void dispose() {
    super.dispose();
  }
}
