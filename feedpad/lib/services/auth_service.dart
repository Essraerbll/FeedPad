import 'package:flutter/material.dart';
import 'api_service.dart';

class User {
  final String id;
  final String email;
  final String name;
  final String username;
  final String userType;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.username,
    required this.userType,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      username: json['username'] as String? ?? '',
      userType: json['userType'] as String,
    );
  }
}

class AuthService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  User? _currentUser;
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  Future<String?> signUp({
    required String email,
    required String password,
    required String name,
    String? username,
    required String userType,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _apiService.post('/auth/register', {
        'email': email,
        'password': password,
        'name': name,
        'username': username ?? '',
        'userType': userType,
      });

      _isLoading = false;
      notifyListeners();

      if (response['success'] == true) {
        _currentUser = null;
        return null;
      } else {
        if (response['errors'] != null) {
          final errors = response['errors'] as List;
          if (errors.isNotEmpty) {
            return errors[0]['msg'] as String? ??
                response['message'] as String? ??
                'Registration failed';
          }
        }
        return response['message'] as String? ?? 'Registration failed';
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString().replaceAll('Exception: ', '');
    }
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      debugPrint('🔐 Attempting login for: $email');

      final response = await _apiService.post('/auth/login', {
        'email': email,
        'password': password,
      });

      _isLoading = false;
      notifyListeners();

      debugPrint('📥 Login response: $response');

      if (response['success'] == true) {
        _currentUser = User.fromJson(response['user']);
        notifyListeners();
        return null;
      } else {
        debugPrint('❌ Login failed: ${response['message']}');
        if (response['errors'] != null) {
          final errors = response['errors'] as List;
          if (errors.isNotEmpty) {
            return errors[0]['msg'] as String? ??
                response['message'] as String? ??
                'Login failed';
          }
        }
        return response['message'] as String? ?? 'Login failed';
      }
    } catch (e) {
      debugPrint('❌ Login error: $e');
      _isLoading = false;
      notifyListeners();
      return e.toString().replaceAll('Exception: ', '');
    }
  }

  Future<void> signOut() async {
    try {
      await _apiService.post('/auth/logout', {});
    } catch (e) {
      debugPrint('Logout error: $e');
      print('Logout error: $e');
    } finally {
      _currentUser = null;
      _apiService.clearSession();
      notifyListeners();
    }
  }

  Future<void> getCurrentUser() async {
    try {
      final response = await _apiService.get('/auth/me');

      if (response['success'] == true) {
        _currentUser = User.fromJson(response['user']);
        notifyListeners();
      } else {
        _currentUser = null;
        _apiService.clearSession();
        notifyListeners();
      }
    } catch (e) {
      _currentUser = null;
      _apiService.clearSession();
      notifyListeners();
    }
  }
}
