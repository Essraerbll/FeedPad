import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:developer' as developer;
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../location/coordinates.dart';
// import 'package:feedpad/profile/profile_screen.dart'; // Artık MainScreen'den yönetiliyor

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController mapController = MapController();
  final List<Marker> _markers = [];

  // Başlangıç konumu (İstanbul örnek olarak)
  static const LatLng _initialCenter = LatLng(41.0082, 28.9784);
  static const double _initialZoom = 12.0;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
  }

  Future<void> _loadUserLocation() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user != null && !_isInitialized) {
      try {
        final userData = await authService.getUserData(user.uid);
        if (userData != null && userData['location'] != null) {
          final location = userData['location'] as String;

          // Location formatı: "Province / District" veya sadece "Province"
          if (location.contains(' / ')) {
            final parts = location.split(' / ');
            final province = parts[0].trim();
            final district = parts.length > 1 ? parts[1].trim() : null;

            if (district != null) {
              final coordinates = DistrictCoordinates.getDistrictCoordinates(
                  province, district);
              if (coordinates != null) {
                // Kısa bir gecikme ile haritanın yüklenmesini bekle
                await Future.delayed(const Duration(milliseconds: 500));
                mapController.move(coordinates, 13.0);
                setState(() {
                  _isInitialized = true;
                });
                return;
              }
            }
          }
        }
      } catch (e) {
        developer.log('Kullanıcı konumu yüklenirken hata: $e');
      }
    }

    setState(() {
      _isInitialized = true;
    });
  }

  /// Haritada uzun basış (2 saniye) ile marker ekler
  void _onMapLongPress(TapPosition tapPosition, LatLng latlng) {
    _addMarker(latlng);
  }

  Future<void> _signOut() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Harita'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış Yap',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Çıkış Yap'),
                  content:
                      const Text('Çıkış yapmak istediğinize emin misiniz?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('İptal'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Çıkış Yap'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await _signOut();
              }
            },
          ),
        ],
      ),
      body: SizedBox.expand(
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
    developer.log(
      'Marker eklendi: ${position.latitude}, ${position.longitude} - Toplam marker sayısı: ${_markers.length}',
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
