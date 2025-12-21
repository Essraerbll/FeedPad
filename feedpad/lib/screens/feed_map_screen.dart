import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'add_marker_screen.dart';
import 'marker_detail_screen.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class FeedMapScreen extends StatefulWidget {
  const FeedMapScreen({super.key});

  @override
  State<FeedMapScreen> createState() => _FeedMapScreenState();
}

class _FeedMapScreenState extends State<FeedMapScreen> {
  final MapController mapController = MapController();
  final List<Marker> _markers = [];
  final Map<String, Map<String, dynamic>> _markerDataMap =
      {}; // markerId -> markerData
  final Map<String, int> _markerIndexMap =
      {}; // markerId -> marker index in _markers list
  final ApiService _apiService = ApiService();
  bool _isLocationLoaded = false;

  // Başlangıç konumu (İstanbul örnek olarak)
  static const LatLng _initialCenter = LatLng(41.0082, 28.9784);
  static const double _initialZoom = 12.0;
  static const double _userLocationZoom = 18.0; // Cadde seviyesi için zoom

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _loadMarkers();
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

  /// Backend'den marker'ları yükle
  Future<void> _loadMarkers() async {
    try {
      print('Marker yükleme başlatılıyor...');
      final response = await _apiService.getMarkers();
      print('Marker yükleme response: $response');

      if (response['success'] == true && mounted) {
        final markersData = response['markers'] as List<dynamic>;
        print('Yüklenen marker sayısı: ${markersData.length}');

        // Tüm unique userId'leri topla
        final Set<String> uniqueUserIds = {};
        for (var markerData in markersData) {
          final userId = markerData['userId'] as String?;
          if (userId != null) {
            uniqueUserIds.add(userId);
          }
        }

        // Tüm kullanıcı bilgilerini paralel olarak al
        final Map<String, String> userIdToUserTypeMap = {};
        final List<Future<void>> userInfoFutures = [];
        
        for (var userId in uniqueUserIds) {
          userInfoFutures.add(
            _apiService.get('/auth/user/$userId').then((userResponse) {
              if (userResponse['success'] == true && userResponse['user'] != null) {
                final user = userResponse['user'] as Map<String, dynamic>;
                userIdToUserTypeMap[userId] = user['userType'] as String? ?? 'user';
              }
            }).catchError((e) {
              print('User info loading error for $userId: $e');
            })
          );
        }

        // Tüm kullanıcı bilgilerinin yüklenmesini bekle
        await Future.wait(userInfoFutures);

        setState(() {
          _markers.clear();
          _markerDataMap.clear();
          _markerIndexMap.clear();
          for (var markerData in markersData) {
            final markerId = markerData['id'] as String;

            // Güvenli double dönüşümü (int veya double olabilir)
            final latitude = (markerData['latitude'] is int)
                ? (markerData['latitude'] as int).toDouble()
                : (markerData['latitude'] as num).toDouble();
            final longitude = (markerData['longitude'] is int)
                ? (markerData['longitude'] as int).toDouble()
                : (markerData['longitude'] as num).toDouble();

            final position = LatLng(latitude, longitude);

            // waterLiters için güvenli dönüşüm
            double? waterLiters;
            if (markerData['waterLiters'] != null) {
              waterLiters = (markerData['waterLiters'] is int)
                  ? (markerData['waterLiters'] as int).toDouble()
                  : (markerData['waterLiters'] as num).toDouble();
            }

            // addedAmount için güvenli dönüşüm
            double? addedAmount;
            if (markerData['addedAmount'] != null) {
              addedAmount = (markerData['addedAmount'] is int)
                  ? (markerData['addedAmount'] as int).toDouble()
                  : (markerData['addedAmount'] as num).toDouble();
            }

            // Pet shop owner kontrolü - marker'ın userId'sine bakarak kontrol et
            final markerUserId = markerData['userId'] as String?;
            final userType = markerUserId != null ? userIdToUserTypeMap[markerUserId] : null;
            final isPetShopOwnerMarker = userType == 'pet_shop_owner';

            // Marker verilerini sakla (userType bilgisini de ekle)
            _markerDataMap[markerId] = {
              'id': markerId,
              'userId': markerData['userId'] as String?,
              'userType': userType, // userType bilgisini sakla
              'type': markerData['type'] as String,
              'petType': markerData['petType'] as String?,
              'waterLiters': waterLiters,
              'isWaterEnough': markerData['isWaterEnough'] as String?,
              'addedAmount': addedAmount,
              'addedByUserId': markerData['addedByUserId'] as String?,
              'isEnoughNow': markerData['isEnoughNow'] as String?,
              'latitude': latitude,
              'longitude': longitude,
            };

            _addMarkerToMap(
              position,
              markerData['type'] as String,
              markerId: markerId,
              petType: markerData['petType'] as String?,
              waterLiters: waterLiters,
              isWaterEnough: markerData['isWaterEnough'] as String?,
              isPetShopOwnerMarker: isPetShopOwnerMarker,
            );
          }
        });
        print('Marker yükleme tamamlandı. Toplam marker: ${_markers.length}');
      } else {
        print(
            'Marker yükleme başarısız: ${response['message'] ?? 'Bilinmeyen hata'}');
      }
    } catch (e) {
      print('Marker yükleme hatası: $e');
    }
  }

  /// Haritada tıklama ile marker detay popup'ını açar
  void _onMapTap(TapPosition tapPosition, LatLng latlng) async {
    // Tıklanan noktaya en yakın marker'ı bul
    String? closestMarkerId;
    double minDistance = double.infinity;

    for (var entry in _markerDataMap.entries) {
      final markerData = entry.value;
      final markerPosition = LatLng(
        markerData['latitude'] as double,
        markerData['longitude'] as double,
      );

      // Basit mesafe hesaplama (Haversine yerine basit Euclidean)
      final distance = (latlng.latitude - markerPosition.latitude).abs() +
          (latlng.longitude - markerPosition.longitude).abs();

      // Eğer marker'a yakınsa (yaklaşık 0.001 derece = ~100m)
      if (distance < 0.001 && distance < minDistance) {
        minDistance = distance;
        closestMarkerId = entry.key;
      }
    }

    if (closestMarkerId != null &&
        _markerDataMap.containsKey(closestMarkerId)) {
      // Marker detay popup'ını aç
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => MarkerDetailScreen(
          markerId: closestMarkerId!,
          markerData: _markerDataMap[closestMarkerId]!,
        ),
      );

      // Eğer opinion submit edildiyse marker'ı güncelle
      if (result != null && mounted) {
        final markerId = result['markerId'] as String?;
        final newIsEnough = result['isWaterEnough'] as String?;

        if (markerId != null && _markerDataMap.containsKey(markerId)) {
          // Marker verisini güncelle (userType bilgisini koru)
          final existingUserType = _markerDataMap[markerId]!['userType'];
          _markerDataMap[markerId]!['isWaterEnough'] = newIsEnough;
          if (existingUserType != null) {
            _markerDataMap[markerId]!['userType'] = existingUserType;
          }

          // Marker'ı haritada güncelle (isWaterEnough'a göre renk hesaplanacak)
          _updateMarkerColor(markerId);
        }
      }
    }
  }

  /// Haritada uzun basış ile marker ekleme formunu açar
  void _onMapLongPress(TapPosition tapPosition, LatLng latlng) async {
    // Pet shop owner kontrolü
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    final isPetShopOwner = currentUser?.userType == 'pet_shop_owner';

    // Marker ekleme formunu popup olarak aç
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddMarkerScreen(position: latlng),
    );

    // Eğer pet shop owner exact location'ı reddettiyse hata mesajı göster
    if (result != null && result['exactLocationDenied'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sorry, you can only add your exact location.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return; // Marker eklenmesin
    }

    // Eğer form başarıyla tamamlandıysa marker ekle
    if (result != null && result['exactLocationDenied'] != true) {
      final type = result['type'] as String;
      final position = result['position'] as LatLng;
      final petType = result['petType'] as String?;
      final waterLiters = result['waterLiters'] as double?;
      final isWaterEnough = result['isWaterEnough'] as String?;

      // Backend'e kaydet
      try {
        final response = await _apiService.createMarker(
          type: type,
          latitude: position.latitude,
          longitude: position.longitude,
          petType: petType,
          waterLiters: waterLiters,
          isWaterEnough: isWaterEnough,
        );

        if (response['success'] == true && mounted) {
          // Başarılı olursa haritaya ekle
          final markerId = response['marker']?['id'] as String?;
          if (markerId != null) {
            // Marker verilerini sakla
            final markerResponse = response['marker'] as Map<String, dynamic>?;
            final markerUserId = markerResponse?['userId'] as String?;
            
            // Pet shop owner kontrolü için kullanıcı bilgisini al
            String? userType;
            if (markerUserId != null) {
              try {
                final userResponse = await _apiService.get('/auth/user/$markerUserId');
                if (userResponse['success'] == true && userResponse['user'] != null) {
                  final user = userResponse['user'] as Map<String, dynamic>;
                  userType = user['userType'] as String?;
                }
              } catch (e) {
                print('User info loading error for new marker: $e');
              }
            }
            
            _markerDataMap[markerId] = {
              'id': markerId,
              'userId': markerUserId,
              'userType': userType, // userType bilgisini sakla
              'type': type,
              'petType': petType,
              'waterLiters': waterLiters,
              'isWaterEnough': isWaterEnough,
              'latitude': position.latitude,
              'longitude': position.longitude,
            };
          }

          _addMarkerToMap(
            position,
            type,
            markerId: markerId,
            petType: petType,
            waterLiters: waterLiters,
            isWaterEnough: isWaterEnough,
            isPetShopOwnerMarker: isPetShopOwner,
          );

          // Marker'ları tekrar yükle (backend'den güncel listeyi al)
          await _loadMarkers();

          // Başarı mesajı göster
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Marker added successfully',
                  style: TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          // Hata mesajı göster
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  response['message'] ??
                      'An error occurred while adding marker',
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        print('Marker kaydetme hatası: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'An error occurred while adding marker: $e',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
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
          onTap: _onMapTap,
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

  /// Belirtilen konuma yeni bir marker ekler (sadece haritaya, backend'e kaydetmez)
  void _addMarkerToMap(
    LatLng position,
    String type, {
    String? markerId,
    String? petType,
    double? waterLiters,
    String? isWaterEnough,
    bool? isPetShopOwnerMarker,
  }) {
    setState(() {
      Color markerColor;
      IconData iconData;
      bool isHouseShape = false;

      // Pet shop owner marker kontrolü
      if (isPetShopOwnerMarker == true) {
        isHouseShape = true;
        iconData = Icons.home;
        // Pet shop owner marker'ları için varsayılan renk
        markerColor = Colors.blue;
      } else if (type == 'food' && petType != null) {
        // Food + Cat/Dog için: Yes = yeşil, Maybe = turuncu, No = kırmızı
        markerColor = isWaterEnough == 'yes'
            ? Colors.green
            : isWaterEnough == 'maybe'
                ? Colors.orange
                : Colors.red;
        // Cat için kedi patisi, Dog için donut ikonu
        if (petType == 'cat') {
          iconData = Icons.pets; // Kedi patisi için pets ikonu
        } else if (petType == 'dog') {
          iconData = Icons.donut_large; // Köpek için donut ikonu
        } else {
          iconData = Icons.restaurant;
        }
      } else if (type == 'water') {
        // Water için: Yes = yeşil, Maybe = turuncu, No = kırmızı
        markerColor = isWaterEnough == 'yes'
            ? Colors.green
            : isWaterEnough == 'maybe'
                ? Colors.orange
                : Colors.red;
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
        child: markerId != null
            ? GestureDetector(
                onTap: () async {
                  // Marker detay popup'ını aç
                  if (_markerDataMap.containsKey(markerId)) {
                    final result = await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder: (context) => MarkerDetailScreen(
                        markerId: markerId,
                        markerData: _markerDataMap[markerId]!,
                      ),
                    );

                    // Eğer opinion submit edildiyse marker'ı güncelle
                    if (result != null && mounted) {
                      final updatedMarkerId = result['markerId'] as String?;
                      final newIsEnough = result['isWaterEnough'] as String?;

                      if (updatedMarkerId != null &&
                          _markerDataMap.containsKey(updatedMarkerId)) {
                        // Marker verisini güncelle (userType bilgisini koru)
                        final existingUserType = _markerDataMap[updatedMarkerId]!['userType'];
                        _markerDataMap[updatedMarkerId]!['isWaterEnough'] =
                            newIsEnough;

                        // Yeni alanları da güncelle
                        if (result['addedAmount'] != null) {
                          _markerDataMap[updatedMarkerId]!['addedAmount'] =
                              result['addedAmount'];
                        } else {
                          // Eğer null ise de güncelle (temizleme için)
                          _markerDataMap[updatedMarkerId]!['addedAmount'] =
                              null;
                        }
                        if (result['addedByUserId'] != null) {
                          _markerDataMap[updatedMarkerId]!['addedByUserId'] =
                              result['addedByUserId'];
                        } else {
                          // Eğer null ise de güncelle (temizleme için)
                          _markerDataMap[updatedMarkerId]!['addedByUserId'] =
                              null;
                        }
                        if (result['isEnoughNow'] != null) {
                          _markerDataMap[updatedMarkerId]!['isEnoughNow'] =
                              result['isEnoughNow'];
                        } else {
                          // Eğer null ise de güncelle (temizleme için)
                          _markerDataMap[updatedMarkerId]!['isEnoughNow'] =
                              null;
                        }
                        // userType bilgisini koru
                        if (existingUserType != null) {
                          _markerDataMap[updatedMarkerId]!['userType'] = existingUserType;
                        }

                        // Marker'ı haritada güncelle (isWaterEnough veya isEnoughNow'e göre renk hesaplanacak)
                        _updateMarkerColor(updatedMarkerId);
                      }
                    }
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: markerColor,
                    shape: isHouseShape ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: isHouseShape ? BorderRadius.circular(8) : null,
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
              )
            : Container(
                decoration: BoxDecoration(
                  color: markerColor,
                  shape: isHouseShape ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: isHouseShape ? BorderRadius.circular(8) : null,
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

      // Marker index'ini sakla
      if (markerId != null) {
        _markerIndexMap[markerId] = _markers.length - 1;
      }
    });
    print(
        'Marker eklendi: ${position.latitude}, ${position.longitude} - Type: $type - Toplam marker sayısı: ${_markers.length}');
  }

  /// Marker'ın rengini güncelle
  void _updateMarkerColor(String markerId) {
    if (!_markerIndexMap.containsKey(markerId) ||
        !_markerDataMap.containsKey(markerId)) {
      return;
    }

    final markerIndex = _markerIndexMap[markerId]!;
    final markerData = _markerDataMap[markerId]!;
    final position = LatLng(
      markerData['latitude'] as double,
      markerData['longitude'] as double,
    );
    final type = markerData['type'] as String;
    final petType = markerData['petType'] as String?;
    final isWaterEnough = markerData['isWaterEnough'] as String?;
    final isEnoughNow = markerData['isEnoughNow'] as String?;

    // Pet shop owner kontrolü - marker verisinden userType'ı al
    final userType = markerData['userType'] as String?;
    final isPetShopOwnerMarker = userType == 'pet_shop_owner';

    // Renk belirleme: isEnoughNow varsa onu kullan, yoksa isWaterEnough'u kullan
    // Yes = yeşil, Maybe = turuncu, No = kırmızı
    final statusToUse = isEnoughNow ?? isWaterEnough;
    Color markerColor;
    bool isHouseShape = false;
    
    if (isPetShopOwnerMarker) {
      isHouseShape = true;
      markerColor = Colors.blue; // Pet shop owner marker'ları için varsayılan renk
    } else if (type == 'food' && petType != null) {
      markerColor = statusToUse == 'yes'
          ? Colors.green
          : statusToUse == 'maybe'
              ? Colors.orange
              : Colors.red;
    } else if (type == 'water') {
      markerColor = statusToUse == 'yes'
          ? Colors.green
          : statusToUse == 'maybe'
              ? Colors.orange
              : Colors.red;
    } else if (type == 'food') {
      markerColor = statusToUse == 'yes'
          ? Colors.green
          : statusToUse == 'maybe'
              ? Colors.orange
              : Colors.red;
    } else {
      markerColor = Colors.blue;
    }

    // Icon'u belirle
    IconData iconData;
    if (isPetShopOwnerMarker) {
      iconData = Icons.home;
    } else if (type == 'food' && petType != null) {
      if (petType == 'cat') {
        iconData = Icons.pets;
      } else if (petType == 'dog') {
        iconData = Icons.donut_large;
      } else {
        iconData = Icons.restaurant;
      }
    } else if (type == 'water') {
      iconData = Icons.water_drop;
    } else if (type == 'food') {
      iconData = Icons.restaurant;
    } else {
      iconData = Icons.location_on;
    }

    setState(() {
      // Marker'ı güncelle
      _markers[markerIndex] = Marker(
        point: position,
        width: 50.0,
        height: 50.0,
        child: GestureDetector(
          onTap: () async {
            // Marker detay popup'ını aç
            if (_markerDataMap.containsKey(markerId)) {
              final result = await showDialog<Map<String, dynamic>>(
                context: context,
                builder: (context) => MarkerDetailScreen(
                  markerId: markerId,
                  markerData: _markerDataMap[markerId]!,
                ),
              );

              // Eğer opinion submit edildiyse marker'ı güncelle
              if (result != null && mounted) {
                final updatedMarkerId = result['markerId'] as String?;
                final newIsEnough = result['isWaterEnough'] as String?;

                if (updatedMarkerId != null &&
                    _markerDataMap.containsKey(updatedMarkerId)) {
                  // Marker verisini güncelle (userType bilgisini koru)
                  final existingUserType = _markerDataMap[updatedMarkerId]!['userType'];
                  _markerDataMap[updatedMarkerId]!['isWaterEnough'] =
                      newIsEnough;
                  if (existingUserType != null) {
                    _markerDataMap[updatedMarkerId]!['userType'] = existingUserType;
                  }

                  // Marker'ı haritada güncelle (isWaterEnough'a göre renk hesaplanacak)
                  _updateMarkerColor(updatedMarkerId);
                }
              }
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: markerColor,
              shape: isHouseShape ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: isHouseShape ? BorderRadius.circular(8) : null,
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
        ),
      );
    });
  }

  @override
  void dispose() {
    super.dispose();
  }
}
