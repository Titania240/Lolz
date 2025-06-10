import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/meme_editor_models.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

class MemeEditorService {
  final String _baseUrl = 'http://localhost:3000/api/meme-editor';
  final Dio _dio = Dio();

  Future<ImageModel> uploadImage(File image, String title, String description, ImageCategory category) async {
    try {
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(image.path),
        'title': title,
        'description': description,
        'category': category.toString().split('.').last,
      });

      final response = await _dio.post('$_baseUrl/upload', data: formData);
      
      if (response.statusCode == 200) {
        return ImageModel.fromJson(response.data);
      } else {
        throw Exception('Failed to upload image: ${response.data['message']}');
      }
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  Future<List<ImageModel>> getGalleryImages({
    ImageCategory? category,
    ImageType? type,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get('$_baseUrl/gallery', queryParameters: {
        'category': category?.toString().split('.').last,
        'type': type?.toString().split('.').last,
        'limit': limit,
      });

      if (response.statusCode == 200) {
        return (response.data as List)
            .map((json) => ImageModel.fromJson(json))
            .toList();
      } else {
        throw Exception('Failed to fetch gallery images: ${response.data['message']}');
      }
    } catch (e) {
      throw Exception('Failed to fetch gallery images: $e');
    }
  }

  Future<ImageModel> purchasePremiumImage(String imageId) async {
    try {
      final response = await _dio.post('$_baseUrl/premium/$imageId/purchase');
      
      if (response.statusCode == 200) {
        return ImageModel.fromJson(response.data['image']);
      } else {
        throw Exception('Purchase failed: ${response.data['message']}');
      }
    } catch (e) {
      throw Exception('Purchase failed: $e');
    }
  }

  Future<Map<String, dynamic>> createMeme({
    required String imageId,
    required String description,
    required List<MemeText> texts,
    List<String> hashtags = const [],
  }) async {
    try {
      final response = await _dio.post('$_baseUrl/create', data: {
        'image_id': imageId,
        'description': description,
        'texts': texts.map((text) => text.toJson()).toList(),
        'hashtags': hashtags,
      });

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to create meme: ${response.data['message']}');
      }
    } catch (e) {
      throw Exception('Failed to create meme: $e');
    }
  }
}
