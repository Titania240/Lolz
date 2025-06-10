import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final String baseUrl = 'http://localhost:3000/api';
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  Future<User> register(String email, String password, String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
        'name': name,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      await saveToken(data['token']);
      return User.fromJson(data['user']);
    } else {
      throw Exception('Registration failed');
    }
  }

  Future<User> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await saveToken(data['token']);
      return User.fromJson(data['user']);
    } else {
      throw Exception('Login failed');
    }
  }

  Future<User> googleSignIn() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw Exception('Google sign in cancelled');

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final response = await http.get(
        Uri.parse('$baseUrl/auth/google/callback?code=${googleAuth.idToken}'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveToken(data['token']);
        return User.fromJson(data['user']);
      } else {
        throw Exception('Google login failed');
      }
    } catch (e) {
      throw Exception('Google sign in failed: $e');
    }
  }

  Future<void> logout() async {
    await clearToken();
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  Future<User?> getCurrentUser() async {
    final token = await getToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/protected'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return User.fromJson(data['user']);
      }
    } catch (e) {
      await logout();
    }

    return null;
  }
}
