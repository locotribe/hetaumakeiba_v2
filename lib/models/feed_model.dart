// lib/models/feed_model.dart

class Feed {
  final int? id;
  final String title;
  final String url;
  final String type;
  final int displayOrder;

  Feed({
    this.id,
    required this.title,
    required this.url,
    required this.type,
    required this.displayOrder,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'type': type,
      'display_order': displayOrder,
    };
  }

  factory Feed.fromMap(Map<String, dynamic> map) {
    return Feed(
      id: map['id'] as int?,
      title: map['title'] as String,
      url: map['url'] as String,
      type: map['type'] as String,
      displayOrder: map['display_order'] as int,
    );
  }
}