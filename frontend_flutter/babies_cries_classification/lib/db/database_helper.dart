import 'package:http/http.dart' as http;
import 'dart:convert';

class DatabaseHelper {
  static const String baseUrl = 'http://localhost:5000'; // Flask server URL

  // Method to register a baby (user registration)
  Future<Map<String, dynamic>> registerBaby(String fullName, String password, int age, String nationality) async {
    final url = Uri.parse('$baseUrl/register-baby');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'full_name': fullName,
        'password': password,
        'age': age,
        'nationality': nationality,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body); // Success response
    } else {
      throw Exception('Failed to register baby: ${response.body}');
    }
  }

  // Method to log in a user
  Future<Map<String, dynamic>> loginUser(String fullName, String password) async {
    final url = Uri.parse('$baseUrl/login-baby');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'full_name': fullName,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body); // Success response
    } else {
      throw Exception('Login failed: ${response.body}');
    }
  }

  // Method to fetch all baby info (if needed for frontend display)
  Future<List<Map<String, dynamic>>> getAllBabies() async {
    final url = Uri.parse('$baseUrl/get-babies'); // Assumes a new endpoint to fetch all babies
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to fetch baby information: ${response.body}');
    }
  }
}
