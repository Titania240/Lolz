import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum ImageType { free, premium }
enum ImageCategory {
  animals,
  school,
  sports,
  food,
  travel,
  funny,
  dark,
  wholesome,
  other
}

enum TextPosition { top, bottom }

class ImageModel {
  final String id;
  final String url;
  final String title;
  final String description;
  final ImageCategory category;
  final ImageType type;
  final int priceLolcoins;
  final bool approved;
  final bool nsfw;

  ImageModel({
    required this.id,
    required this.url,
    required this.title,
    this.description = '',
    required this.category,
    required this.type,
    this.priceLolcoins = 0,
    this.approved = false,
    this.nsfw = false,
  });

  factory ImageModel.fromJson(Map<String, dynamic> json) {
    return ImageModel(
      id: json['id'],
      url: json['url'],
      title: json['title'],
      description: json['description'] ?? '',
      category: ImageCategory.values.firstWhere(
        (e) => e.toString() == 'ImageCategory.${json['category']}',
        orElse: () => ImageCategory.other,
      ),
      type: ImageType.values.firstWhere(
        (e) => e.toString() == 'ImageType.${json['type']}',
        orElse: () => ImageType.free,
      ),
      priceLolcoins: json['price_lolcoins'] ?? 0,
      approved: json['approved'] ?? false,
      nsfw: json['nsfw'] ?? false,
    );
  }
}

class MemeText {
  final String text;
  final TextPosition position;
  final String? fontFamily;
  final Color color;
  final double size;
  final double x;
  final double y;

  MemeText({
    required this.text,
    required this.position,
    this.fontFamily,
    this.color = Colors.white,
    this.size = 16.0,
    this.x = 0,
    this.y = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'position': position.toString().split('.').last,
      'fontFamily': fontFamily,
      'color': color.value,
      'size': size,
      'x': x,
      'y': y,
    };
  }
}

class MemeEditorState {
  final String? imageId;
  final String? imageUrl;
  final List<MemeText> texts;
  final String description;
  final List<String> hashtags;
  final bool isPremium;
  final int priceLolcoins;

  MemeEditorState({
    this.imageId,
    this.imageUrl,
    this.texts = const [],
    this.description = '',
    this.hashtags = const [],
    this.isPremium = false,
    this.priceLolcoins = 0,
  });

  MemeEditorState copyWith({
    String? imageId,
    String? imageUrl,
    List<MemeText>? texts,
    String? description,
    List<String>? hashtags,
    bool? isPremium,
    int? priceLolcoins,
  }) {
    return MemeEditorState(
      imageId: imageId ?? this.imageId,
      imageUrl: imageUrl ?? this.imageUrl,
      texts: texts ?? this.texts,
      description: description ?? this.description,
      hashtags: hashtags ?? this.hashtags,
      isPremium: isPremium ?? this.isPremium,
      priceLolcoins: priceLolcoins ?? this.priceLolcoins,
    );
  }
}
