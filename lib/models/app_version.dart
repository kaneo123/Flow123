class AppVersion {
  final String id;
  final String platform;
  final String latestVersion;
  final String minimumVersion;
  final String releaseNotes;
  final DateTime updatedAt;

  AppVersion({
    required this.id,
    required this.platform,
    required this.latestVersion,
    required this.minimumVersion,
    required this.releaseNotes,
    required this.updatedAt,
  });

  factory AppVersion.fromJson(Map<String, dynamic> json) => AppVersion(
        id: json['id'] as String,
        platform: json['platform'] as String,
        latestVersion: json['latest_version'] as String,
        minimumVersion: json['minimum_version'] as String,
        releaseNotes: json['release_notes'] as String? ?? '',
        updatedAt: json['updated_at'] != null 
            ? DateTime.parse(json['updated_at'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'platform': platform,
        'latest_version': latestVersion,
        'minimum_version': minimumVersion,
        'release_notes': releaseNotes,
        'updated_at': updatedAt.toIso8601String(),
      };
}

class VersionCheckResult {
  final bool isUpToDate;
  final bool requiresUpdate;
  final String? latestVersion;
  final String? releaseNotes;

  VersionCheckResult({
    required this.isUpToDate,
    required this.requiresUpdate,
    this.latestVersion,
    this.releaseNotes,
  });
}
