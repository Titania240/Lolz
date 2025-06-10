import 'package:json_annotation/json_annotation.dart';

part 'meme.g.dart';

@JsonSerializable()
class Meme {
  final String id;
  final String title;
  final String url;
  final String category;
  final List<String> hashtags;
  final User user;
  final int views;
  final int likes;
  final DateTime createdAt;

  Meme({
    required this.id,
    required this.title,
    required this.url,
    required this.category,
    required this.hashtags,
    required this.user,
    required this.views,
    required this.likes,
    required this.createdAt,
  });

  factory Meme.fromJson(Map<String, dynamic> json) => _$MemeFromJson(json);
  Map<String, dynamic> toJson() => _$MemeToJson(this);
}

@JsonSerializable()
class User {
  final String id;
  final String name;
  final String? profilePicture;

  User({
    required this.id,
    required this.name,
    this.profilePicture,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}
