import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/meme.dart';

class FeedService {
  final String baseUrl = 'http://localhost:3000/api';
  final String _token;

  FeedService(this._token);

  Future<List<Meme>> getFeed({
    String sort = 'recent',
    String? category,
    String? hashtag,
    int offset = 0,
    int limit = 20,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/feed?sort=$sort&category=$category&hashtag=$hashtag&offset=$offset&limit=$limit'),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
    );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Meme.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else if (response.statusCode == 404) {
        throw Exception('No memes found');
      } else {
        throw Exception('Failed to load memes: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Connection timeout');
    } on SocketException {
      throw Exception('No internet connection');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<Meme> getMemeDetails(String memeId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/feed/$memeId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Meme.fromJson(data['meme']);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else if (response.statusCode == 404) {
        throw Exception('Meme not found');
      } else {
        throw Exception('Failed to load meme details: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Connection timeout');
    } on SocketException {
      throw Exception('No internet connection');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<void> likeMeme(String memeId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/memes/$memeId/like'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to like meme: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Connection timeout');
    } on SocketException {
      throw Exception('No internet connection');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
