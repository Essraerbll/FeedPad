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
  final Map<String, Map<String, dynamic>> _markerDataMap = {};
  final Map<String, int> _markerIndexMap = {};
  final ApiService _apiService = ApiService();
  bool _isLocationLoaded = false;

  static const LatLng _initialCenter = LatLng(41.0082, 28.9784);
  static const double _initialZoom = 12.0;
  static const double _userLocationZoom = 18.0;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _loadMarkers();
  }

  Future<void> _requestLocationPermission() async {
    if (_isLocationLoaded) return;

    try {
      PermissionStatus status = await Permission.location.status;

      if (status.isDenied) {
        status = await Permission.location.request();
      }

      if (status.isGranted) {
        await _getCurrentLocation();
      } else {
        _zoomToIstanbul();
      }
    } catch (e) {
      print('Location permission error: $e');
      _zoomToIstanbul();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _zoomToIstanbul();
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final userLocation = LatLng(position.latitude, position.longitude);

      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        mapController.move(userLocation, _userLocationZoom);

        setState(() {
          _isLocationLoaded = true;
        });
      }
    } catch (e) {
      print('Error getting location: $e');
      _zoomToIstanbul();
    }
  }

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

  Future<void> _loadMarkers() async {
    try {
      final response = await _apiService.getMarkers();

      if (response['success'] == true && mounted) {
        final markersData = response['markers'] as List<dynamic>;

        final Set<String> uniqueUserIds = {};
        for (var markerData in markersData) {
          final userId = markerData['userId'] as String?;
          if (userId != null) {
            uniqueUserIds.add(userId);
          }
        }

        final Map<String, String> userIdToUserTypeMap = {};
        final List<Future<void>> userInfoFutures = [];

        for (var userId in uniqueUserIds) {
          userInfoFutures
              .add(_apiService.get('/auth/user/$userId').then((userResponse) {
            if (userResponse['success'] == true &&
                userResponse['user'] != null) {
              final user = userResponse['user'] as Map<String, dynamic>;
              userIdToUserTypeMap[userId] =
                  user['userType'] as String? ?? 'user';
            }
          }).catchError((e) {
            print('User info loading error for $userId: $e');
          }));
        }

        await Future.wait(userInfoFutures);

        setState(() {
          _markers.clear();
          _markerDataMap.clear();
          _markerIndexMap.clear();
          for (var markerData in markersData) {
            final markerId = markerData['id'] as String;

            final latitude = (markerData['latitude'] is int)
                ? (markerData['latitude'] as int).toDouble()
                : (markerData['latitude'] as num).toDouble();
            final longitude = (markerData['longitude'] is int)
                ? (markerData['longitude'] as int).toDouble()
                : (markerData['longitude'] as num).toDouble();

            final position = LatLng(latitude, longitude);

            double? waterLiters;
            if (markerData['waterLiters'] != null) {
              waterLiters = (markerData['waterLiters'] is int)
                  ? (markerData['waterLiters'] as int).toDouble()
                  : (markerData['waterLiters'] as num).toDouble();
            }

            double? addedAmount;
            if (markerData['addedAmount'] != null) {
              addedAmount = (markerData['addedAmount'] is int)
                  ? (markerData['addedAmount'] as int).toDouble()
                  : (markerData['addedAmount'] as num).toDouble();
            }

            final markerUserId = markerData['userId'] as String?;
            final userType =
                markerUserId != null ? userIdToUserTypeMap[markerUserId] : null;
            final isPetShopOwnerMarker = userType == 'pet_shop_owner';

            double? catFoodAmount;
            if (markerData['catFoodAmount'] != null) {
              catFoodAmount = (markerData['catFoodAmount'] is int)
                  ? (markerData['catFoodAmount'] as int).toDouble()
                  : (markerData['catFoodAmount'] as num).toDouble();
            }
            double? dogFoodAmount;
            if (markerData['dogFoodAmount'] != null) {
              dogFoodAmount = (markerData['dogFoodAmount'] is int)
                  ? (markerData['dogFoodAmount'] as int).toDouble()
                  : (markerData['dogFoodAmount'] as num).toDouble();
            }

            _markerDataMap[markerId] = {
              'id': markerId,
              'userId': markerData['userId'] as String?,
              'userType': userType,
              'type': markerData['type'] as String,
              'catFoodAmount': catFoodAmount,
              'dogFoodAmount': dogFoodAmount,
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
        print('Marker loading completed. Total markers: ${_markers.length}');
      } else {
        print(
            'Failed to load markers: ${response['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('Error loading markers: $e');
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng latlng) async {
    String? closestMarkerId;
    double minDistance = double.infinity;

    for (var entry in _markerDataMap.entries) {
      final markerData = entry.value;
      final markerPosition = LatLng(
        markerData['latitude'] as double,
        markerData['longitude'] as double,
      );

      final distance = (latlng.latitude - markerPosition.latitude).abs() +
          (latlng.longitude - markerPosition.longitude).abs();

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

      if (result != null && mounted) {
        final markerId = result['markerId'] as String?;
        final newIsEnough = result['isWaterEnough'] as String?;
        final catFoodAmount = result['catFoodAmount'];
        final dogFoodAmount = result['dogFoodAmount'];

        if (markerId != null && _markerDataMap.containsKey(markerId)) {
          setState(() {
            final existingUserType = _markerDataMap[markerId]!['userType'];
            _markerDataMap[markerId]!['isWaterEnough'] = newIsEnough;

            if (result['addedAmount'] != null) {
              _markerDataMap[markerId]!['addedAmount'] = result['addedAmount'];
            } else {
              _markerDataMap[markerId]!['addedAmount'] = null;
            }
            if (result['addedByUserId'] != null) {
              _markerDataMap[markerId]!['addedByUserId'] =
                  result['addedByUserId'];
            } else {
              _markerDataMap[markerId]!['addedByUserId'] = null;
            }
            if (result['isEnoughNow'] != null) {
              _markerDataMap[markerId]!['isEnoughNow'] = result['isEnoughNow'];
            } else {
              _markerDataMap[markerId]!['isEnoughNow'] = null;
            }

            if (catFoodAmount != null) {
              _markerDataMap[markerId]!['catFoodAmount'] =
                  (catFoodAmount as num).toDouble();
            } else {
              _markerDataMap[markerId]!['catFoodAmount'] = null;
            }
            if (dogFoodAmount != null) {
              _markerDataMap[markerId]!['dogFoodAmount'] =
                  (dogFoodAmount as num).toDouble();
            } else {
              _markerDataMap[markerId]!['dogFoodAmount'] = null;
            }

            if (existingUserType != null) {
              _markerDataMap[markerId]!['userType'] = existingUserType;
            }

            if (_markerIndexMap.containsKey(markerId)) {
              final markerIndex = _markerIndexMap[markerId]!;
              final markerData = _markerDataMap[markerId]!;
              final position = LatLng(
                markerData['latitude'] as double,
                markerData['longitude'] as double,
              );
              final type = markerData['type'] as String;
              final petType = markerData['petType'] as String?;
              final isWaterEnough =
                  newIsEnough ?? markerData['isWaterEnough'] as String?;
              final isEnoughNow = result['isEnoughNow'] as String? ??
                  markerData['isEnoughNow'] as String?;

              final userType = markerData['userType'] as String?;
              final isPetShopOwnerMarker = userType == 'pet_shop_owner';

              final statusToUse = isEnoughNow ?? isWaterEnough;
              Color markerColor;
              bool isHouseShape = false;

              if (isPetShopOwnerMarker) {
                isHouseShape = true;
                markerColor = statusToUse == 'yes'
                    ? Colors.green
                    : statusToUse == 'no'
                        ? Colors.red
                        : Colors.blue;
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

              _markers[markerIndex] = Marker(
                point: position,
                width: 50.0,
                height: 50.0,
                child: GestureDetector(
                  onTap: () async {
                    if (_markerDataMap.containsKey(markerId)) {
                      final result = await showDialog<Map<String, dynamic>>(
                        context: context,
                        builder: (context) => MarkerDetailScreen(
                          markerId: markerId,
                          markerData: _markerDataMap[markerId]!,
                        ),
                      );

                      if (result != null && mounted) {
                        final updatedMarkerId = result['markerId'] as String?;
                        final newIsEnough = result['isWaterEnough'] as String?;
                        final waterLiters = result['waterLiters'];
                        final petType = result['petType'];

                        if (updatedMarkerId != null &&
                            _markerDataMap.containsKey(updatedMarkerId)) {
                          setState(() {
                            final existingUserType =
                                _markerDataMap[updatedMarkerId]!['userType'];
                            _markerDataMap[updatedMarkerId]!['isWaterEnough'] =
                                newIsEnough;

                            if (result['addedAmount'] != null) {
                              _markerDataMap[updatedMarkerId]!['addedAmount'] =
                                  result['addedAmount'];
                            } else {
                              _markerDataMap[updatedMarkerId]!['addedAmount'] =
                                  null;
                            }
                            if (result['addedByUserId'] != null) {
                              _markerDataMap[updatedMarkerId]![
                                  'addedByUserId'] = result['addedByUserId'];
                            } else {
                              _markerDataMap[updatedMarkerId]![
                                  'addedByUserId'] = null;
                            }
                            if (result['isEnoughNow'] != null) {
                              _markerDataMap[updatedMarkerId]!['isEnoughNow'] =
                                  result['isEnoughNow'];
                            } else {
                              _markerDataMap[updatedMarkerId]!['isEnoughNow'] =
                                  null;
                            }

                            if (waterLiters != null) {
                              _markerDataMap[updatedMarkerId]!['waterLiters'] =
                                  (waterLiters as num).toDouble();
                            }
                            if (petType != null) {
                              _markerDataMap[updatedMarkerId]!['petType'] =
                                  petType;
                            }

                            if (existingUserType != null) {
                              _markerDataMap[updatedMarkerId]!['userType'] =
                                  existingUserType;
                            }

                            if (_markerIndexMap.containsKey(updatedMarkerId)) {
                              final updatedMarkerIndex =
                                  _markerIndexMap[updatedMarkerId]!;
                              final updatedMarkerData =
                                  _markerDataMap[updatedMarkerId]!;
                              final updatedPosition = LatLng(
                                updatedMarkerData['latitude'] as double,
                                updatedMarkerData['longitude'] as double,
                              );
                              final updatedType =
                                  updatedMarkerData['type'] as String;
                              final updatedPetType =
                                  updatedMarkerData['petType'] as String?;
                              final updatedIsWaterEnough = newIsEnough ??
                                  updatedMarkerData['isWaterEnough'] as String?;
                              final updatedIsEnoughNow = result['isEnoughNow']
                                      as String? ??
                                  updatedMarkerData['isEnoughNow'] as String?;

                              final updatedUserType =
                                  updatedMarkerData['userType'] as String?;
                              final updatedIsPetShopOwnerMarker =
                                  updatedUserType == 'pet_shop_owner';

                              final updatedStatusToUse =
                                  updatedIsEnoughNow ?? updatedIsWaterEnough;
                              Color updatedMarkerColor;
                              bool updatedIsHouseShape = false;

                              if (updatedIsPetShopOwnerMarker) {
                                updatedIsHouseShape = true;
                                updatedMarkerColor = updatedStatusToUse == 'yes'
                                    ? Colors.green
                                    : updatedStatusToUse == 'no'
                                        ? Colors.red
                                        : Colors.blue;
                              } else if (updatedType == 'food' &&
                                  updatedPetType != null) {
                                updatedMarkerColor = updatedStatusToUse == 'yes'
                                    ? Colors.green
                                    : updatedStatusToUse == 'maybe'
                                        ? Colors.orange
                                        : Colors.red;
                              } else if (updatedType == 'water') {
                                updatedMarkerColor = updatedStatusToUse == 'yes'
                                    ? Colors.green
                                    : updatedStatusToUse == 'maybe'
                                        ? Colors.orange
                                        : Colors.red;
                              } else if (updatedType == 'food') {
                                updatedMarkerColor = updatedStatusToUse == 'yes'
                                    ? Colors.green
                                    : updatedStatusToUse == 'maybe'
                                        ? Colors.orange
                                        : Colors.red;
                              } else {
                                updatedMarkerColor = Colors.blue;
                              }

                              IconData updatedIconData;
                              if (updatedIsPetShopOwnerMarker) {
                                updatedIconData = Icons.home;
                              } else if (updatedType == 'food' &&
                                  updatedPetType != null) {
                                if (updatedPetType == 'cat') {
                                  updatedIconData = Icons.pets;
                                } else if (updatedPetType == 'dog') {
                                  updatedIconData = Icons.donut_large;
                                } else {
                                  updatedIconData = Icons.restaurant;
                                }
                              } else if (updatedType == 'water') {
                                updatedIconData = Icons.water_drop;
                              } else if (updatedType == 'food') {
                                updatedIconData = Icons.restaurant;
                              } else {
                                updatedIconData = Icons.location_on;
                              }

                              _markers[updatedMarkerIndex] = Marker(
                                point: updatedPosition,
                                width: 50.0,
                                height: 50.0,
                                child: GestureDetector(
                                  onTap: () async {
                                    if (_markerDataMap
                                        .containsKey(updatedMarkerId)) {
                                      final result = await showDialog<
                                          Map<String, dynamic>>(
                                        context: context,
                                        builder: (context) =>
                                            MarkerDetailScreen(
                                          markerId: updatedMarkerId,
                                          markerData:
                                              _markerDataMap[updatedMarkerId]!,
                                        ),
                                      );

                                      if (result != null && mounted) {
                                        final nestedMarkerId =
                                            result['markerId'] as String?;
                                        final nestedIsEnough =
                                            result['isWaterEnough'] as String?;
                                        final nestedCatFoodAmount =
                                            result['catFoodAmount'];
                                        final nestedDogFoodAmount =
                                            result['dogFoodAmount'];

                                        if (nestedMarkerId != null &&
                                            _markerDataMap
                                                .containsKey(nestedMarkerId)) {
                                          setState(() {
                                            final existingUserType =
                                                _markerDataMap[nestedMarkerId]![
                                                    'userType'];
                                            _markerDataMap[nestedMarkerId]![
                                                    'isWaterEnough'] =
                                                nestedIsEnough;

                                            if (result['addedAmount'] != null) {
                                              _markerDataMap[nestedMarkerId]![
                                                      'addedAmount'] =
                                                  result['addedAmount'];
                                            } else {
                                              _markerDataMap[nestedMarkerId]![
                                                  'addedAmount'] = null;
                                            }
                                            if (result['addedByUserId'] !=
                                                null) {
                                              _markerDataMap[nestedMarkerId]![
                                                      'addedByUserId'] =
                                                  result['addedByUserId'];
                                            } else {
                                              _markerDataMap[nestedMarkerId]![
                                                  'addedByUserId'] = null;
                                            }
                                            if (result['isEnoughNow'] != null) {
                                              _markerDataMap[nestedMarkerId]![
                                                      'isEnoughNow'] =
                                                  result['isEnoughNow'];
                                            } else {
                                              _markerDataMap[nestedMarkerId]![
                                                  'isEnoughNow'] = null;
                                            }

                                            if (nestedCatFoodAmount != null) {
                                              _markerDataMap[nestedMarkerId]![
                                                      'catFoodAmount'] =
                                                  (nestedCatFoodAmount as num)
                                                      .toDouble();
                                            } else {
                                              _markerDataMap[nestedMarkerId]![
                                                  'catFoodAmount'] = null;
                                            }
                                            if (nestedDogFoodAmount != null) {
                                              _markerDataMap[nestedMarkerId]![
                                                      'dogFoodAmount'] =
                                                  (nestedDogFoodAmount as num)
                                                      .toDouble();
                                            } else {
                                              _markerDataMap[nestedMarkerId]![
                                                  'dogFoodAmount'] = null;
                                            }

                                            if (existingUserType != null) {
                                              _markerDataMap[nestedMarkerId]![
                                                      'userType'] =
                                                  existingUserType;
                                            }

                                            if (_markerIndexMap
                                                .containsKey(nestedMarkerId)) {
                                              final nestedMarkerIndex =
                                                  _markerIndexMap[
                                                      nestedMarkerId]!;
                                              final nestedMarkerData =
                                                  _markerDataMap[
                                                      nestedMarkerId]!;
                                              final nestedPosition = LatLng(
                                                nestedMarkerData['latitude']
                                                    as double,
                                                nestedMarkerData['longitude']
                                                    as double,
                                              );
                                              final nestedType =
                                                  nestedMarkerData['type']
                                                      as String;
                                              final nestedPetType =
                                                  nestedMarkerData['petType']
                                                      as String?;
                                              final nestedIsWaterEnough =
                                                  nestedIsEnough ??
                                                      nestedMarkerData[
                                                              'isWaterEnough']
                                                          as String?;
                                              final nestedIsEnoughNow =
                                                  result['isEnoughNow']
                                                          as String? ??
                                                      nestedMarkerData[
                                                              'isEnoughNow']
                                                          as String?;

                                              final nestedUserType =
                                                  nestedMarkerData['userType']
                                                      as String?;
                                              final nestedIsPetShopOwnerMarker =
                                                  nestedUserType ==
                                                      'pet_shop_owner';

                                              final nestedStatusToUse =
                                                  nestedIsEnoughNow ??
                                                      nestedIsWaterEnough;
                                              Color nestedMarkerColor;
                                              bool nestedIsHouseShape = false;

                                              if (nestedIsPetShopOwnerMarker) {
                                                nestedIsHouseShape = true;
                                                nestedMarkerColor =
                                                    nestedStatusToUse == 'yes'
                                                        ? Colors.green
                                                        : nestedStatusToUse ==
                                                                'no'
                                                            ? Colors.red
                                                            : Colors.blue;
                                              } else if (nestedType == 'food' &&
                                                  nestedPetType != null) {
                                                nestedMarkerColor =
                                                    nestedStatusToUse == 'yes'
                                                        ? Colors.green
                                                        : nestedStatusToUse ==
                                                                'maybe'
                                                            ? Colors.orange
                                                            : Colors.red;
                                              } else if (nestedType ==
                                                  'water') {
                                                nestedMarkerColor =
                                                    nestedStatusToUse == 'yes'
                                                        ? Colors.green
                                                        : nestedStatusToUse ==
                                                                'maybe'
                                                            ? Colors.orange
                                                            : Colors.red;
                                              } else if (nestedType == 'food') {
                                                nestedMarkerColor =
                                                    nestedStatusToUse == 'yes'
                                                        ? Colors.green
                                                        : nestedStatusToUse ==
                                                                'maybe'
                                                            ? Colors.orange
                                                            : Colors.red;
                                              } else {
                                                nestedMarkerColor = Colors.blue;
                                              }

                                              IconData nestedIconData;
                                              if (nestedIsPetShopOwnerMarker) {
                                                nestedIconData = Icons.home;
                                              } else if (nestedType == 'food' &&
                                                  nestedPetType != null) {
                                                if (nestedPetType == 'cat') {
                                                  nestedIconData = Icons.pets;
                                                } else if (nestedPetType ==
                                                    'dog') {
                                                  nestedIconData =
                                                      Icons.donut_large;
                                                } else {
                                                  nestedIconData =
                                                      Icons.restaurant;
                                                }
                                              } else if (nestedType ==
                                                  'water') {
                                                nestedIconData =
                                                    Icons.water_drop;
                                              } else if (nestedType == 'food') {
                                                nestedIconData =
                                                    Icons.restaurant;
                                              } else {
                                                nestedIconData =
                                                    Icons.location_on;
                                              }

                                              _markers[nestedMarkerIndex] =
                                                  Marker(
                                                point: nestedPosition,
                                                width: 50.0,
                                                height: 50.0,
                                                child: GestureDetector(
                                                  onTap: () async {
                                                    if (_markerDataMap
                                                        .containsKey(
                                                            nestedMarkerId)) {
                                                      final result =
                                                          await showDialog<
                                                              Map<String,
                                                                  dynamic>>(
                                                        context: context,
                                                        builder: (context) =>
                                                            MarkerDetailScreen(
                                                          markerId:
                                                              nestedMarkerId,
                                                          markerData:
                                                              _markerDataMap[
                                                                  nestedMarkerId]!,
                                                        ),
                                                      );

                                                      if (result != null &&
                                                          mounted) {
                                                        final deepMarkerId =
                                                            result['markerId']
                                                                as String?;
                                                        if (deepMarkerId !=
                                                                null &&
                                                            _markerDataMap
                                                                .containsKey(
                                                                    deepMarkerId)) {
                                                          _updateMarkerColor(
                                                              deepMarkerId);
                                                        }
                                                      }
                                                    }
                                                  },
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: nestedMarkerColor,
                                                      shape: nestedIsHouseShape
                                                          ? BoxShape.rectangle
                                                          : BoxShape.circle,
                                                      borderRadius:
                                                          nestedIsHouseShape
                                                              ? BorderRadius
                                                                  .circular(8)
                                                              : null,
                                                      border: Border.all(
                                                        color: Colors.white,
                                                        width: 2.0,
                                                      ),
                                                    ),
                                                    child: Icon(
                                                      nestedIconData,
                                                      color: Colors.white,
                                                      size: 25.0,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }
                                          });
                                        }
                                      }
                                    }
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: updatedMarkerColor,
                                      shape: updatedIsHouseShape
                                          ? BoxShape.rectangle
                                          : BoxShape.circle,
                                      borderRadius: updatedIsHouseShape
                                          ? BorderRadius.circular(8)
                                          : null,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2.0,
                                      ),
                                    ),
                                    child: Icon(
                                      updatedIconData,
                                      color: Colors.white,
                                      size: 25.0,
                                    ),
                                  ),
                                ),
                              );
                            }
                          });
                        }
                      }
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: markerColor,
                      shape:
                          isHouseShape ? BoxShape.rectangle : BoxShape.circle,
                      borderRadius:
                          isHouseShape ? BorderRadius.circular(8) : null,
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
            }
          });
        }
      }
    }
  }

  void _onMapLongPress(TapPosition tapPosition, LatLng latlng) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    final isPetShopOwner = currentUser?.userType == 'pet_shop_owner';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddMarkerScreen(position: latlng),
    );

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
      return;
    }

    if (result != null && result['exactLocationDenied'] != true) {
      final type = result['type'] as String;
      final position = result['position'] as LatLng;
      final petType = result['petType'] as String?;
      final waterLiters = result['waterLiters'] as double?;
      final isWaterEnough = result['isWaterEnough'] as String?;

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
          final markerId = response['marker']?['id'] as String?;
          if (markerId != null) {
            final markerResponse = response['marker'] as Map<String, dynamic>?;
            final markerUserId = markerResponse?['userId'] as String?;

            String? userType;
            if (markerUserId != null) {
              try {
                final userResponse =
                    await _apiService.get('/auth/user/$markerUserId');
                if (userResponse['success'] == true &&
                    userResponse['user'] != null) {
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
              'userType': userType,
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

          await _loadMarkers();

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
        print('Error saving marker: $e');
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

      if (isPetShopOwnerMarker == true) {
        isHouseShape = true;
        iconData = Icons.home;
        markerColor = isWaterEnough == 'yes'
            ? Colors.green
            : isWaterEnough == 'no'
                ? Colors.red
                : Colors.blue;
      } else if (type == 'food' && petType != null) {
        markerColor = isWaterEnough == 'yes'
            ? Colors.green
            : isWaterEnough == 'maybe'
                ? Colors.orange
                : Colors.red;
        if (petType == 'cat') {
          iconData = Icons.pets;
        } else if (petType == 'dog') {
          iconData = Icons.donut_large;
        } else {
          iconData = Icons.restaurant;
        }
      } else if (type == 'water') {
        markerColor = isWaterEnough == 'yes'
            ? Colors.green
            : isWaterEnough == 'maybe'
                ? Colors.orange
                : Colors.red;
        iconData = Icons.water_drop;
      } else if (type == 'food') {
        markerColor = Colors.orange;
        iconData = Icons.restaurant;
      } else {
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
                  if (_markerDataMap.containsKey(markerId)) {
                    final result = await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder: (context) => MarkerDetailScreen(
                        markerId: markerId,
                        markerData: _markerDataMap[markerId]!,
                      ),
                    );

                    if (result != null && mounted) {
                      final updatedMarkerId = result['markerId'] as String?;
                      final newIsEnough = result['isWaterEnough'] as String?;

                      if (updatedMarkerId != null &&
                          _markerDataMap.containsKey(updatedMarkerId)) {
                        setState(() {
                          final existingUserType =
                              _markerDataMap[updatedMarkerId]!['userType'];
                          _markerDataMap[updatedMarkerId]!['isWaterEnough'] =
                              newIsEnough;

                          if (result['addedAmount'] != null) {
                            _markerDataMap[updatedMarkerId]!['addedAmount'] =
                                result['addedAmount'];
                          } else {
                            _markerDataMap[updatedMarkerId]!['addedAmount'] =
                                null;
                          }
                          if (result['addedByUserId'] != null) {
                            _markerDataMap[updatedMarkerId]!['addedByUserId'] =
                                result['addedByUserId'];
                          } else {
                            _markerDataMap[updatedMarkerId]!['addedByUserId'] =
                                null;
                          }
                          if (result['isEnoughNow'] != null) {
                            _markerDataMap[updatedMarkerId]!['isEnoughNow'] =
                                result['isEnoughNow'];
                          } else {
                            _markerDataMap[updatedMarkerId]!['isEnoughNow'] =
                                null;
                          }
                          if (existingUserType != null) {
                            _markerDataMap[updatedMarkerId]!['userType'] =
                                existingUserType;
                          }
                        });

                        _updateMarkerColor(updatedMarkerId);
                      }
                    }
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: markerColor,
                    shape: isHouseShape ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius:
                        isHouseShape ? BorderRadius.circular(8) : null,
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

      if (markerId != null) {
        _markerIndexMap[markerId] = _markers.length - 1;
      }
    });
    print(
        'Marker added: ${position.latitude}, ${position.longitude} - Type: $type - Total marker count: ${_markers.length}');
  }

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

    final userType = markerData['userType'] as String?;
    final isPetShopOwnerMarker = userType == 'pet_shop_owner';

    final statusToUse = isEnoughNow ?? isWaterEnough;
    Color markerColor;
    bool isHouseShape = false;

    if (isPetShopOwnerMarker) {
      isHouseShape = true;
      markerColor = statusToUse == 'yes'
          ? Colors.green
          : statusToUse == 'no'
              ? Colors.red
              : Colors.blue;
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
      _markers[markerIndex] = Marker(
        point: position,
        width: 50.0,
        height: 50.0,
        child: GestureDetector(
          onTap: () async {
            if (_markerDataMap.containsKey(markerId)) {
              final result = await showDialog<Map<String, dynamic>>(
                context: context,
                builder: (context) => MarkerDetailScreen(
                  markerId: markerId,
                  markerData: _markerDataMap[markerId]!,
                ),
              );

              if (result != null && mounted) {
                final updatedMarkerId = result['markerId'] as String?;
                final newIsEnough = result['isWaterEnough'] as String?;
                final waterLiters = result['waterLiters'];
                final petType = result['petType'];

                if (updatedMarkerId != null &&
                    _markerDataMap.containsKey(updatedMarkerId)) {
                  setState(() {
                    final existingUserType =
                        _markerDataMap[updatedMarkerId]!['userType'];
                    _markerDataMap[updatedMarkerId]!['isWaterEnough'] =
                        newIsEnough;

                    if (result['addedAmount'] != null) {
                      _markerDataMap[updatedMarkerId]!['addedAmount'] =
                          result['addedAmount'];
                    } else {
                      _markerDataMap[updatedMarkerId]!['addedAmount'] = null;
                    }
                    if (result['addedByUserId'] != null) {
                      _markerDataMap[updatedMarkerId]!['addedByUserId'] =
                          result['addedByUserId'];
                    } else {
                      _markerDataMap[updatedMarkerId]!['addedByUserId'] = null;
                    }
                    if (result['isEnoughNow'] != null) {
                      _markerDataMap[updatedMarkerId]!['isEnoughNow'] =
                          result['isEnoughNow'];
                    } else {
                      _markerDataMap[updatedMarkerId]!['isEnoughNow'] = null;
                    }

                    if (waterLiters != null) {
                      _markerDataMap[updatedMarkerId]!['waterLiters'] =
                          (waterLiters as num).toDouble();
                    }
                    if (petType != null) {
                      _markerDataMap[updatedMarkerId]!['petType'] = petType;
                    }

                    if (existingUserType != null) {
                      _markerDataMap[updatedMarkerId]!['userType'] =
                          existingUserType;
                    }
                  });

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
