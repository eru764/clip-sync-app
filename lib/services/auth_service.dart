import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService {
  static const String _apiKey = 'AIzaSyBbKI6LDUimJvKiBOFd2HFqs-sc7YQI_1w';
  static const String _signInUrl = 'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=';
  static const String _signUpUrl = 'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=';

  // Sign in with email and password
  Future<String> signInWithEmail(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_signInUrl$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'returnSecureToken': true,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final idToken = data['idToken'];
        final localId = data['localId'];

        // Save token and user ID to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', idToken);
        await prefs.setString('user_id', localId);

        return idToken;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error']['message'] ?? 'Sign in failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Sign up with email and password
  Future<String> signUpWithEmail(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_signUpUrl$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'returnSecureToken': true,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final idToken = data['idToken'];
        final localId = data['localId'];

        // Save token and user ID to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', idToken);
        await prefs.setString('user_id', localId);

        return idToken;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error']['message'] ?? 'Sign up failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get Firebase ID token from SharedPreferences
  Future<String> getIdToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null && token.isNotEmpty) {
        return token;
      }
      throw Exception('No token found');
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Clear token and user ID from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_id');
    } catch (e) {
      rethrow;
    }
  }
}
