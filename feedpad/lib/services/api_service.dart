import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiService {
  // Gerçek cihaz için IP adresi (bilgisayarınızın yerel IP'si)
  // Eğer IP değişirse burayı güncelleyin
  static const String realDeviceIp = '192.168.1.108';

  // Backend URL - platforma göre otomatik seçilir
  static String get baseUrl {
    if (kIsWeb) {
      // Web için
      return 'http://localhost:3000/api';
    } else if (Platform.isAndroid) {
      // Android için (emülatör): Android emülatörü host makineyi 10.0.2.2 ile görür.
      // Gerçek cihaz kullanıyorsanız değiştirin: 'http://<PC_IP>:3000/api'
      return 'http://10.0.2.2:3000/api';
    } else if (Platform.isIOS) {
      // iOS için: Simulator ise localhost, gerçek cihaz ise yerel IP
      // Gerçek cihaz kullanıyorsanız aşağıdaki satırı kullanın:
      return 'http://$realDeviceIp:3000/api';
      // Simulator için (yukarıdaki satırı yorum yapıp bunu açın):
      // return 'http://localhost:3000/api';
    } else {
      // Windows, Linux, macOS için
      return 'http://localhost:3000/api';
    }
  }

  // Cookie'leri saklamak için
  static String? sessionId;

  // HTTP headers
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (sessionId != null) 'Cookie': 'sessionId=$sessionId',
      };

  // POST isteği
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

      // Cookie'yi response'dan al (hem header'dan hem de body'den)
      final setCookie = response.headers['set-cookie'];
      if (setCookie != null) {
        final cookieMatch = RegExp(r'sessionId=([^;]+)').firstMatch(setCookie);
        if (cookieMatch != null) {
          sessionId = cookieMatch.group(1);
        }
      }

      // Eğer header'da yoksa body'den al
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

  // GET isteği
  Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final url = Uri.parse('${baseUrl}$endpoint');
      final response = await http.get(url, headers: _headers);

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      return responseData;
    } on SocketException {
      throw Exception('Sunucuya bağlanılamadı. Backend çalışıyor mu?');
    } catch (e) {
      throw Exception('İstek başarısız: $e');
    }
  }

  // PUT isteği
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

  // DELETE isteği
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

  // Marker oluştur
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

  // Tüm marker'ları getir
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

  // Kullanıcının marker'larını getir
  Future<Map<String, dynamic>> getMyMarkers() async {
    return await get('/markers/my-markers');
  }

  // Marker getir (ID ile)
  Future<Map<String, dynamic>> getMarker(String id) async {
    return await get('/markers/$id');
  }

  // Marker güncelle
  Future<Map<String, dynamic>> updateMarker(
    String id, {
    String? type,
    double? latitude,
    double? longitude,
    String? petType,
    double? waterLiters,
    String? isWaterEnough,
  }) async {
    final body = {
      if (type != null) 'type': type,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (petType != null) 'petType': petType,
      if (waterLiters != null) 'waterLiters': waterLiters,
      if (isWaterEnough != null) 'isWaterEnough': isWaterEnough,
    };
    return await put('/markers/$id', body);
  }

  // Marker sil
  Future<Map<String, dynamic>> deleteMarker(String id) async {
    return await delete('/markers/$id');
  }

  // Session'ı temizle
  void clearSession() {
    sessionId = null;
  }
}
