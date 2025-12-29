import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiService {
  static const String realDeviceIp = '192.168.1.7';

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    } else if (Platform.isAndroid) {
      return 'http://$realDeviceIp:3000/api';
    } else if (Platform.isIOS) {
      return 'http://$realDeviceIp:3000/api';
    } else {
      return 'http://localhost:3000/api';
    }
  }

  static String? sessionId;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (sessionId != null) 'Cookie': 'sessionId=$sessionId',
      };

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final url = Uri.parse('${baseUrl}$endpoint');
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(body),
      );

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      final setCookie = response.headers['set-cookie'];
      if (setCookie != null) {
        final cookieMatch = RegExp(r'sessionId=([^;]+)').firstMatch(setCookie);
        if (cookieMatch != null) {
          sessionId = cookieMatch.group(1);
        }
      }

      if (sessionId == null && responseData['sessionId'] != null) {
        sessionId = responseData['sessionId'] as String;
      }

      return responseData;
    } on SocketException {
      throw Exception('Sunucuya bağlanılamadı. Backend çalışıyor mu?');
    } catch (e) {
      throw Exception('İstek başarısız: $e');
    }
  }

  Future<Map<String, dynamic>> postMultipart(
    String endpoint,
    Map<String, String> fields, {
    Uint8List? fileBytes,
    String? filename,
    String fileField = 'image',
  }) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      debugPrint('🌐 POST Multipart to: $url');
      final request = http.MultipartRequest('POST', url);
      request.fields.addAll(fields);
      if (sessionId != null) {
        request.headers['Cookie'] = 'sessionId=$sessionId';
      }
      if (fileBytes != null && fileBytes.isNotEmpty) {
        request.files.add(
          http.MultipartFile.fromBytes(
            fileField,
            fileBytes,
            filename: filename ?? 'upload.jpg',
          ),
        );
      }

      final streamed = await request.send();
      final responseBody = await streamed.stream.bytesToString();
      debugPrint('📬 Multipart Status: ${streamed.statusCode}');
      debugPrint('📬 Multipart Body: $responseBody');

      final responseData = jsonDecode(responseBody) as Map<String, dynamic>;

      final setCookie = streamed.headers['set-cookie'];
      if (setCookie != null) {
        final cookieMatch = RegExp(r'sessionId=([^;]+)').firstMatch(setCookie);
        if (cookieMatch != null) {
          sessionId = cookieMatch.group(1);
        }
      }

      if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
        return responseData;
      }
      throw Exception(responseData['message'] ?? 'İstek başarısız');
    } on SocketException {
      throw Exception('Sunucuya bağlanılamadı. Backend çalışıyor mu?');
    } catch (e) {
      throw Exception('İstek başarısız: $e');
    }
  }
  Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final url = Uri.parse('${baseUrl}$endpoint');
      debugPrint('🌐 GET request to: $url');
      final response = await http.get(url, headers: _headers);
      
      debugPrint('📥 GET response status: ${response.statusCode}');
      debugPrint('📥 GET response body length: ${response.body.length}');
      
      if (response.statusCode != 200) {
        debugPrint('❌ GET response error: ${response.body}');
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      try {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('✅ GET response parsed successfully');
        return responseData;
      } catch (e) {
        debugPrint('❌ JSON parse error: $e');
        debugPrint('Response body (first 500 chars): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
        throw Exception('JSON parse error: $e');
      }
    } on SocketException {
      throw Exception('Sunucuya bağlanılamadı. Backend çalışıyor mu?');
    } catch (e) {
      debugPrint('❌ GET request error: $e');
      throw Exception('İstek başarısız: $e');
    }
  }

  Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final url = Uri.parse('${baseUrl}$endpoint');
      final response = await http.put(
        url,
        headers: _headers,
        body: jsonEncode(body),
      );

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      return responseData;
    } on SocketException {
      throw Exception('Sunucuya bağlanılamadı. Backend çalışıyor mu?');
    } catch (e) {
      throw Exception('İstek başarısız: $e');
    }
  }

  Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final url = Uri.parse('${baseUrl}$endpoint');
      final response = await http.delete(url, headers: _headers);

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      return responseData;
    } on SocketException {
      throw Exception('Sunucuya bağlanılamadı. Backend çalışıyor mu?');
    } catch (e) {
      throw Exception('İstek başarısız: $e');
    }
  }

  Future<Map<String, dynamic>> createMarker({
    required String type,
    required double latitude,
    required double longitude,
    String? petType,
    double? waterLiters,
    String? isWaterEnough,
  }) async {
    final body = {
      'type': type,
      'latitude': latitude,
      'longitude': longitude,
      if (petType != null) 'petType': petType,
      if (waterLiters != null) 'waterLiters': waterLiters,
      if (isWaterEnough != null) 'isWaterEnough': isWaterEnough,
    };
    return await post('/markers', body);
  }

  Future<Map<String, dynamic>> getMarkers({
    double? latitude,
    double? longitude,
    double? radius,
  }) async {
    String endpoint = '/markers';
    if (latitude != null && longitude != null && radius != null) {
      endpoint += '?latitude=$latitude&longitude=$longitude&radius=$radius';
    }
    return await get(endpoint);
  }

  Future<Map<String, dynamic>> getMyMarkers() async {
    return await get('/markers/my-markers');
  }

  Future<Map<String, dynamic>> getMarker(String id) async {
    return await get('/markers/$id');
  }

  Future<Map<String, dynamic>> updateMarker(
    String id, {
    String? type,
    double? latitude,
    double? longitude,
    String? petType,
    double? waterLiters,
    double? catFoodAmount,
    double? dogFoodAmount,
    String? isWaterEnough,
    double? addedAmount,
    String? addedByUserId,
    String? isEnoughNow,
    bool?
        shouldUpdateCatDogAmounts,
  }) async {
    final body = {
      if (type != null) 'type': type,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (petType != null) 'petType': petType,
      if (waterLiters != null) 'waterLiters': waterLiters,
      if (shouldUpdateCatDogAmounts == true) 'catFoodAmount': catFoodAmount,
      if (shouldUpdateCatDogAmounts == true) 'dogFoodAmount': dogFoodAmount,
      if (isWaterEnough != null) 'isWaterEnough': isWaterEnough,
      if (addedAmount != null) 'addedAmount': addedAmount,
      if (addedByUserId != null) 'addedByUserId': addedByUserId,
      if (isEnoughNow != null) 'isEnoughNow': isEnoughNow,
    };
    return await put('/markers/$id', body);
  }

  Future<Map<String, dynamic>> deleteMarker(String id) async {
    return await delete('/markers/$id');
  }

  void clearSession() {
    sessionId = null;
  }
}
