import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiService {
  // Gerçek cihaz için IP adresi (bilgisayarınızın yerel IP'si)
  // Eğer IP değişirse burayı güncelleyin
  static const String realDeviceIp = '192.168.1.7';

  // Backend URL - platforma göre otomatik seçilir
  static String get baseUrl {
    if (kIsWeb) {
      // Web için
      return 'http://localhost:3000/api';
    } else if (Platform.isAndroid) {
      // Android için: Emulator ise 10.0.2.2, gerçek cihaz ise yerel IP
      // Gerçek cihaz kullanıyorsanız aşağıdaki satırı kullanın:
      return 'http://$realDeviceIp:3000/api';
      // Emulator için (yukarıdaki satırı yorum yapıp bunu açın):
      // return 'http://10.0.2.2:3000/api';
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

  // POST multipart (image upload)
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
    double? catFoodAmount,
    double? dogFoodAmount,
    String? isWaterEnough,
    double? addedAmount,
    String? addedByUserId,
    String? isEnoughNow,
    bool?
        shouldUpdateCatDogAmounts, // Pet shop owner için null değerleri göndermek için flag
  }) async {
    final body = {
      if (type != null) 'type': type,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (petType != null) 'petType': petType,
      if (waterLiters != null) 'waterLiters': waterLiters,
      // catFoodAmount ve dogFoodAmount için null değerleri de gönder (sıfırlama için)
      // shouldUpdateCatDogAmounts true olduğunda null değerleri de gönder
      // null değerleri de göndermek için her zaman ekle (undefined kontrolü yapmıyoruz)
      if (shouldUpdateCatDogAmounts == true) 'catFoodAmount': catFoodAmount,
      if (shouldUpdateCatDogAmounts == true) 'dogFoodAmount': dogFoodAmount,
      if (isWaterEnough != null) 'isWaterEnough': isWaterEnough,
      if (addedAmount != null) 'addedAmount': addedAmount,
      if (addedByUserId != null) 'addedByUserId': addedByUserId,
      if (isEnoughNow != null) 'isEnoughNow': isEnoughNow,
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
