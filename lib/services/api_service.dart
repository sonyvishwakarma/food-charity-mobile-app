// lib/services/api_service.dart 

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/user_role.dart';
import '../models/user_model.dart';

class ApiService {
  // Common fallback - use PC's WiFi IP when running on physical phone
  // static const String _defaultUrl = 'http://localhost:3000/api'; // only for emulator/web
  static const String _defaultUrl = 'https://food-charity-mobile-app.onrender.com'; // current PC WiFi IP

  // Use API_URL from .env or fallback, with smart detection
  static String get baseUrl {
    try {
      // Priority 1: .env URL (ensure it's not local if using physical phone)
      String? envUrl = dotenv.env['API_URL'];
      String url = (envUrl != null && envUrl.isNotEmpty) ? envUrl : _defaultUrl;
      
      // Smart detection for Android Emulator
      if (!kIsWeb && Platform.isAndroid) {
        if (url.contains('localhost')) {
          return url.replaceAll('localhost', '10.0.2.2');
        }
        if (url.contains('127.0.0.1')) {
          return url.replaceAll('127.0.0.1', '10.0.2.2');
        }
      }
      
      return url;
    } catch (e) {
      return _defaultUrl;
    }
  }

  // Helper to check if we are in local development mode
  static bool get isLocalMode {
    final url = baseUrl.toLowerCase();
    return url.contains('localhost') || url.contains('127.0.0.1') || url.contains('192.168.');
  }

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Shared preferences key for token
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';

  // HTTP client
  final http.Client _client = http.Client();

  // Default timeout duration
  // Default timeout duration - Extended for Render Free Tier wakeup
  static const Duration _timeout = Duration(seconds: 60);

  // ========== TEST CONNECTION METHOD ==========
  Future<Map<String, dynamic>> testConnection() async {
    try {
      final url = Uri.parse('$baseUrl/');

      final response = await _client.get(
        url,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': '✅ Backend connection successful!',
          'status': response.statusCode,
        };
      } else {
        return {
          'success': false,
          'message': '❌ Backend responded with status ${response.statusCode}',
          'status': response.statusCode,
        };
      }
    } on SocketException {
      return {
        'success': false,
        'message': '❌ Cannot connect to server. Make sure backend is running.',
        'status': 0,
      };
    } catch (error) {
      return {
        'success': false,
        'message': '❌ Error: ${error.toString()}',
        'status': 0,
      };
    }
  }

  // ========== HEADERS ==========
  Future<Map<String, String>> getHeaders({bool includeAuth = false}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final token = await _getToken();
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // ========== LOCAL STORAGE METHODS ==========
  Future<void> _saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(tokenKey, token);
    } catch (e) {
      print('Error saving token: $e');
    }
  }

  Future<String> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(tokenKey) ?? '';
    } catch (e) {
      print('Error getting token: $e');
      return '';
    }
  }

  Future<void> _saveUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(userKey, json.encode(user.toJson()));
    } catch (e) {
      print('Error saving user: $e');
    }
  }

  Future<void> clearStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(tokenKey);
      await prefs.remove(userKey);
    } catch (e) {
      print('Error clearing storage: $e');
    }
  }

  // ========== ERROR HANDLING ==========
  String _handleError(dynamic error) {
    if (error is SocketException) {
      return 'Network Error: Cannot reach server.\n1. Check if backend is running\n2. Phone & PC must be on SAME WiFi\n3. Use PC IP, not localhost';
    } else if (error is http.ClientException) {
      return 'Network error: ${error.message}';
    } else if (error is FormatException) {
      return 'Invalid response from server';
    } else {
      return 'An unexpected error occurred: ${error.toString()}';
    }
  }

  // ========== AUTHENTICATION ==========
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required UserRole role,
    Map<String, dynamic>? additionalInfo,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/auth/register');

      final body = json.encode({
        'name': name,
        'email': email,
        'phoneNumber': phone,
        'password': password,
        'role': role.name,
        'additionalInfo': additionalInfo ?? {},
      });

      final response = await _client.post(
        url,
        headers: await getHeaders(),
        body: body,
      );

      final responseData = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 201 || response.statusCode == 200) {
        return await _handleLoginResponse(responseData);
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Registration failed',
          'error': responseData['error'],
        };
      }
    } catch (error) {
      return {
        'success': false,
        'message': _handleError(error),
      };
    }
  }

  Future<Map<String, dynamic>> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/auth/login');

      final body = json.encode({
        'email': email,
        'password': password,
        'loginMethod': 'email',
      });

      final response = await _client.post(
        url,
        headers: await getHeaders(),
        body: body,
      ).timeout(_timeout, onTimeout: () {
        throw SocketException('Connection timed out. Check your network.');
      });

      final responseData = json.decode(response.body) as Map<String, dynamic>;
      return await _handleLoginResponse(responseData);
    } catch (error) {
      return {'success': false, 'message': _handleError(error)};
    }
  }

  Future<Map<String, dynamic>> forgotPassword({
    String? email,
    String? phone,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/auth/forgot-password');
      final body = json.encode({
        'email': email,
        'phoneNumber': phone,
      });

      final response = await _client.post(
        url,
        headers: await getHeaders(),
        body: body,
      );

      return json.decode(response.body);
    } catch (error) {
      return {'success': false, 'message': _handleError(error)};
    }
  }

  Future<Map<String, dynamic>> loginWithPhone({
    required String phone,
    required String password,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/auth/login');

      final body = json.encode({
        'phone': phone,
        'password': password,
        'loginMethod': 'phone',
      });

      final response = await _client.post(
        url,
        headers: await getHeaders(),
        body: body,
      ).timeout(_timeout, onTimeout: () {
        throw SocketException('Connection timed out. Check your network.');
      });

      final responseData = json.decode(response.body) as Map<String, dynamic>;
      return await _handleLoginResponse(responseData);
    } catch (error) {
      return {'success': false, 'message': _handleError(error)};
    }
  }

  Future<Map<String, dynamic>> _handleLoginResponse(
      Map<String, dynamic> responseData) async {
    if (responseData['success'] == true) {
      if (responseData['token'] != null) {
        await _saveToken(responseData['token'].toString());

        final userData = responseData['user'] as Map<String, dynamic>;
        final user = User(
          id: userData['id']?.toString() ?? '',
          name: userData['name']?.toString() ?? '',
          email: userData['email']?.toString() ?? '',
          phone: userData['phone']?.toString() ?? '',
          role: UserRole.values.firstWhere(
            (role) => role.name == (userData['role']?.toString() ?? 'donor'),
            orElse: () => UserRole.donor,
          ),
          additionalInfo:
              Map<String, dynamic>.from(userData['additionalInfo'] ?? {}),
        );

        await _saveUser(user);

        return {
          'success': true,
          'user': user,
          'token': responseData['token'].toString(),
          'message': 'Login successful',
        };
      }
    }

    return {
      'success': false,
      'message': responseData['message']?.toString() ?? 'Login failed',
    };
  }

  Future<Map<String, dynamic>> logout() async {
    try {
      final url = Uri.parse('$baseUrl/auth/logout');
      final response = await _client.get(
        url,
        headers: await getHeaders(includeAuth: true),
      );
      await clearStorage();
      return {'success': response.statusCode == 200, 'message': 'Logged out'};
    } catch (error) {
      await clearStorage();
      return {'success': false, 'message': _handleError(error)};
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/auth/change-password');
      final body = json.encode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
      final response = await _client.post(
        url,
        headers: await getHeaders(includeAuth: true),
        body: body,
      );
      return json.decode(response.body);
    } catch (error) {
      return {'success': false, 'message': _handleError(error)};
    }
  }

  Future<Map<String, dynamic>> exportData() async {
    try {
      final url = Uri.parse('$baseUrl/auth/export-data');
      final response = await _client.get(
        url,
        headers: await getHeaders(includeAuth: true),
      );
      return json.decode(response.body);
    } catch (error) {
      return {'success': false, 'message': _handleError(error)};
    }
  }

  Future<Map<String, dynamic>> removeActiveSessions() async {
    try {
      final url = Uri.parse('$baseUrl/auth/remove-sessions');
      final response = await _client.post(
        url,
        headers: await getHeaders(includeAuth: true),
      );
      final data = json.decode(response.body);
      if (data['success'] == true && data['token'] != null) {
        await _saveToken(data['token']);
      }
      return data;
    } catch (error) {
      return {'success': false, 'message': _handleError(error)};
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await _getToken();
    return token.isNotEmpty;
  }

  Future<User?> getStoredUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(userKey);
      if (userJson != null) {
        return User.fromJson(json.decode(userJson));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ========== DONATION APIs ==========
  Future<Map<String, dynamic>> createDonation(Map<String, dynamic> donationData,
      {File? imageFile}) async {
    try {
      final url = Uri.parse('$baseUrl/donations');
      final request = http.MultipartRequest('POST', url);
      final token = await _getToken();
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      donationData.forEach((key, value) {
        if (value != null) {
          request.fields[key] = (value is List || value is Map)
              ? json.encode(value)
              : value.toString();
        }
      });

      if (imageFile != null) {
        request.files
            .add(await http.MultipartFile.fromPath('image', imageFile.path));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return json.decode(response.body);
    } catch (error) {
      return {'success': false, 'message': _handleError(error)};
    }
  }

  Future<Map<String, dynamic>> getDonorDonations(String donorId) async {
    try {
      final url = Uri.parse('$baseUrl/donations/donor/$donorId');
      final response =
          await _client.get(url, headers: await getHeaders(includeAuth: true));
      return json.decode(response.body);
    } catch (error) {
      return {'success': false, 'message': _handleError(error)};
    }
  }

  // ========== TASK APIs ==========
  Future<Map<String, dynamic>> getVolunteerTasks(String volunteerId) async {
    try {
      final url = Uri.parse('$baseUrl/tasks/volunteer/$volunteerId');
      final response =
          await _client.get(url, headers: await getHeaders(includeAuth: true));
      return json.decode(response.body);
    } catch (error) {
      return {'success': false, 'message': _handleError(error)};
    }
  }

  Future<Map<String, dynamic>> updateTaskStatus(
      String taskId, String status) async {
    try {
      final url = Uri.parse('$baseUrl/tasks/status');
      final response = await _client.post(
        url,
        headers: await getHeaders(includeAuth: true),
        body: json.encode({'taskId': taskId, 'status': status}),
      );
      return json.decode(response.body);
    } catch (error) {
      return {'success': false, 'message': _handleError(error)};
    }
  }

  Future<Map<String, dynamic>> assignTask({
    String? donationId,
    required String volunteerId,
    String? requestId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/tasks/assign');
      final response = await _client.post(
        url,
        headers: await getHeaders(includeAuth: true),
        body: json.encode({
          'donationId': donationId,
          'volunteerId': volunteerId,
          'requestId': requestId
        }),
      );
      return json.decode(response.body);
    } catch (error) {
      return {'success': false, 'message': _handleError(error)};
    }
  }

  // ========== STATS APIs ==========
  Future<Map<String, dynamic>> getDonorStats(String donorId) async {
    try {
      final url = Uri.parse('$baseUrl/donations/stats/$donorId');
      final response = await _client.get(
        url,
        headers: await getHeaders(includeAuth: true),
      );

      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        return responseData;
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to fetch stats',
        };
      }
    } catch (error) {
      return {'success': false, 'message': _handleError(error)};
    }
  }

  Future<Map<String, dynamic>> getVolunteerStats(String volunteerId) async {
    try {
      final url = Uri.parse('$baseUrl/tasks/stats/$volunteerId');
      final response = await _client.get(
        url,
        headers: await getHeaders(includeAuth: true),
      );
      return json.decode(response.body);
    } catch (error) {
      return {'success': false, 'message': _handleError(error)};
    }
  }

  Future<Map<String, dynamic>> getRecipientStats(String recipientId) async {
    try {
      final url = Uri.parse('$baseUrl/food-requests/stats/$recipientId');
      final response = await _client.get(
        url,
        headers: await getHeaders(includeAuth: true),
      );
      return json.decode(response.body);
    } catch (error) {
      return {'success': false, 'message': _handleError(error)};
    }
  }

  // ========== ADMIN APIs ==========
  Future<Map<String, dynamic>> getAdminStats() async {
    try {
      final url = Uri.parse('$baseUrl/admin/stats');
      final response = await _client.get(
        url,
        headers: await getHeaders(includeAuth: true),
      );
      return json.decode(response.body);
    } catch (error) {
      return {'success': false, 'message': _handleError(error)};
    }
  }

  Future<Map<String, dynamic>> getAdminUsers(String role) async {
    try {
      final url = Uri.parse('$baseUrl/admin/users/$role');
      final response = await _client.get(
        url,
        headers: await getHeaders(includeAuth: true),
      );
      return json.decode(response.body);
    } catch (error) {
      return {'success': false, 'message': _handleError(error)};
    }
  }

  Future<Map<String, dynamic>> updateAdminUserStatus(
      String userId, String status) async {
    try {
      final url = Uri.parse('$baseUrl/admin/user-status');
      final response = await _client.post(
        url,
        headers: await getHeaders(includeAuth: true),
        body: json.encode({'userId': userId, 'status': status}),
      );
      return json.decode(response.body);
    } catch (error) {
      return {'success': false, 'message': _handleError(error)};
    }
  }

  // ========== ADDITIONAL APIs ==========
  Future<Map<String, dynamic>> getAvailableDonations() async {
    try {
      final url = Uri.parse('$baseUrl/donations/available');
      final response = await _client.get(
        url,
        headers: await getHeaders(includeAuth: true),
      );
      return json.decode(response.body);
    } catch (error) {
      return {'success': false, 'message': _handleError(error)};
    }
  }

  Future<Map<String, dynamic>> createRequest(
      Map<String, dynamic> requestData) async {
    try {
      final url = Uri.parse('$baseUrl/food-requests');
      final response = await _client.post(
        url,
        headers: await getHeaders(includeAuth: true),
        body: json.encode(requestData),
      );
      return json.decode(response.body);
    } catch (error) {
      return {'success': false, 'message': _handleError(error)};
    }
  }

  Future<Map<String, dynamic>> getRecipientRequests(String recipientId) async {
    try {
      final url = Uri.parse('$baseUrl/food-requests/recipient/$recipientId');
      final response = await _client.get(
        url,
        headers: await getHeaders(includeAuth: true),
      );
      return json.decode(response.body);
    } catch (error) {
      return {'success': false, 'message': _handleError(error)};
    }
  }

  Future<Map<String, dynamic>> getAvailableRequests() async {
    try {
      final url = Uri.parse('$baseUrl/food-requests/available');
      final response = await _client.get(
        url,
        headers: await getHeaders(includeAuth: true),
      );
      return json.decode(response.body);
    } catch (error) {
      return {'success': false, 'message': _handleError(error)};
    }
  }

  Future<Map<String, dynamic>> updateRequestStatus({
    required String requestId,
    required String status,
    String? donorId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/food-requests/status');
      final response = await _client.patch(
        url,
        headers: await getHeaders(includeAuth: true),
        body: json.encode({
          'requestId': requestId,
          'status': status,
          'donorId': donorId,
        }),
      );
      return json.decode(response.body);
    } catch (error) {
      return {'success': false, 'message': _handleError(error)};
    }
  }

  // ========== CHAT APIs (DB BACKEND) ==========
  Future<String> apiCreateChat({
    required String user1Id,
    required String user2Id,
    required String user1Name,
    required String user2Name,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/chat/create');
      final response = await _client.post(
        url,
        headers: await getHeaders(includeAuth: true),
        body: json.encode({
          'user1Id': user1Id,
          'user2Id': user2Id,
          'user1Name': user1Name,
          'user2Name': user2Name,
        }),
      );

      final data = json.decode(response.body);
      return data['chatId']?.toString() ?? '';
    } catch (e) {
      print('apiCreateChat error: $e');
      return '';
    }
  }

  Future<Map<String, dynamic>> apiSendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/chat/send');
      final response = await _client.post(
        url,
        headers: await getHeaders(includeAuth: true),
        body: json.encode({
          'chatId': chatId,
          'senderId': senderId,
          'senderName': senderName,
          'text': text,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      print('apiSendMessage error: $e');
      return {'success': false};
    }
  }

  Future<List<Map<String, dynamic>>> apiGetMessages(String chatId) async {
    try {
      final url = Uri.parse('$baseUrl/chat/messages/$chatId');
      final response = await _client.get(
        url,
        headers: await getHeaders(includeAuth: true),
      );

      final data = json.decode(response.body);
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['messages']);
      }
      return [];
    } catch (e) {
      print('apiGetMessages error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> apiGetUserChats(String userId) async {
    try {
      final url = Uri.parse('$baseUrl/chat/user/$userId');
      final response = await _client.get(
        url,
        headers: await getHeaders(includeAuth: true),
      );

      final data = json.decode(response.body);
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['chats'] ?? []);
      }
      return [];
    } catch (e) {
      print('apiGetUserChats error: $e');
      return [];
    }
  }

  Future<void> apiMarkMessagesAsRead(String chatId, String userId) async {
    try {
      final url = Uri.parse('$baseUrl/chat/mark-read');
      await _client.post(
        url,
        headers: await getHeaders(includeAuth: true),
        body: json.encode({
          'chatId': chatId,
          'userId': userId,
        }),
      );
    } catch (e) {
      print('apiMarkMessagesAsRead error: $e');
    }
  }
}
