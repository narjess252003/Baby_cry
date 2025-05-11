import 'package:http/http.dart' as http;
import 'dart:convert';

class DatabaseHelper {
  static const String baseUrl = 'http://192.168.1.10:5000'; // Base URL of your Flask server

  /// Registers a baby and mother account
  Future<Map<String, dynamic>> registerUser({
    required String email,
    required String password,
    required String phone,
    required DateTime birthDate,
    required String nationality,
    required String profession,
    required String durationOutside,
    required String additionalInfo,
  }) async {
    final url = Uri.parse('$baseUrl/register-baby');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'phone_number': phone,
        'birth_date': birthDate.toIso8601String(),
        'nationality': nationality,
        'profession': profession,
        'duration_outside': durationOutside,
        'additional_info': additionalInfo,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to register user: ${response.body}');
    }
  }


  /// Verifies the OTP sent to the user
  Future<bool> verifyOTP(String email, String code) async {
    final url = Uri.parse('$baseUrl/verifyOTP');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'otp': code,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'success';
      } else {
        throw Exception('OTP verification failed: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      throw Exception('Error during OTP verification: $e');
    }
  }

  /// Logs in a mother
  Future<Map<String, dynamic>> loginUser(String email, String password) async {
    final url = Uri.parse('$baseUrl/login-baby');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data != null && data.containsKey('user') && data['user'] != null) {
          return {'user': data['user']};
        } else {
          return {'error': 'User not found in response'};
        }
      } else {
        final data = json.decode(response.body);
        throw Exception('Login failed: ${data['message'] ?? data['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('Error logging in: $e');
      throw Exception('An error occurred during login');
    }
  }

  /// Fetch baby and mother data by ID
  Future<Map<String, dynamic>> getBabyById(int id) async {
    final url = Uri.parse('$baseUrl/get-baby/$id');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to fetch baby data: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      throw Exception('Error while fetching baby data: $e');
    }
  }

  /// Fetches all baby profiles
  Future<List<Map<String, dynamic>>> getAllBabies() async {
    final url = Uri.parse('$baseUrl/get-babies');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      } else {
        throw Exception('Failed to fetch baby profiles: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      throw Exception('Error while fetching baby profiles: $e');
    }
  }
}
