/// AnimePlatform model representing streaming platform information.
class AnimePlatform {
  const AnimePlatform({required this.platform, required this.url, this.region});

  factory AnimePlatform.fromJson(Map<String, dynamic> json) {
    return AnimePlatform(
      platform: json['platform'] as String,
      url: json['url'] as String,
      region: json['region'] as String?,
    );
  }
  final String platform;
  final String url;
  final String? region;

  Map<String, dynamic> toJson() {
    return {'platform': platform, 'url': url, 'region': region};
  }

  AnimePlatform copyWith({String? platform, String? url, String? region}) {
    return AnimePlatform(
      platform: platform ?? this.platform,
      url: url ?? this.url,
      region: region ?? this.region,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AnimePlatform) return false;
    return platform == other.platform &&
        url == other.url &&
        region == other.region;
  }

  @override
  int get hashCode => Object.hash(platform, url, region);
}
