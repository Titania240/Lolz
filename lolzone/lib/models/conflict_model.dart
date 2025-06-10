class Conflict {
  final String id;
  final MemeEditorState localVersion;
  final MemeEditorState cloudVersion;
  final DateTime detectedAt;
  ConflictResolution resolution;
  final String deviceId;

  Conflict({
    required this.id,
    required this.localVersion,
    required this.cloudVersion,
    required this.detectedAt,
    required this.resolution,
    required this.deviceId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'localVersion': localVersion.toJson(),
      'cloudVersion': cloudVersion.toJson(),
      'detectedAt': detectedAt.toIso8601String(),
      'resolution': resolution.toString(),
      'deviceId': deviceId,
    };
  }

  factory Conflict.fromJson(Map<String, dynamic> json) {
    return Conflict(
      id: json['id'],
      localVersion: MemeEditorState.fromJson(json['localVersion']),
      cloudVersion: MemeEditorState.fromJson(json['cloudVersion']),
      detectedAt: DateTime.parse(json['detectedAt']),
      resolution: ConflictResolution.values.firstWhere(
        (e) => e.toString() == json['resolution'],
        orElse: () => ConflictResolution.pending,
      ),
      deviceId: json['deviceId'],
    );
  }
}

enum ConflictResolution {
  pending,
  localWins,
  cloudWins,
  merged
}
