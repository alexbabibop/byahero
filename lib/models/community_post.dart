class CommunityPost {
  final String id;
  final String userId;
  final String text;
  final double lat;
  final double lng;
  final DateTime createdAt;
  int upvotes;
  int downvotes;
  String? liveStreamUrl;

  CommunityPost({
    required this.id,
    required this.userId,
    required this.text,
    required this.lat,
    required this.lng,
    required this.createdAt,
    this.upvotes = 0,
    this.downvotes = 0,
    this.liveStreamUrl,
  });

  int get score => upvotes - downvotes;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'text': text,
        'lat': lat,
        'lng': lng,
        'createdAt': createdAt.toIso8601String(),
        'upvotes': upvotes,
        'downvotes': downvotes,
        'liveStreamUrl': liveStreamUrl,
      };
}
