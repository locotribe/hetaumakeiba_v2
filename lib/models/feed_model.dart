// lib/models/feed_model.dart

class Feed {
  final int? id;
  // ★★★ ここからが修正箇所 ★★★
  final String userId; // 所有者を示すユーザーID
  // ★★★ ここまでが修正箇所 ★★★
  final String title;
  final String url;
  final String type;
  final int displayOrder;

  Feed({
    this.id,
    // ★★★ ここからが修正箇所 ★★★
    required this.userId,
    // ★★★ ここまでが修正箇所 ★★★
    required this.title,
    required this.url,
    required this.type,
    required this.displayOrder,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      // ★★★ ここからが修正箇所 ★★★
      'userId': userId,
      // ★★★ ここまでが修正箇所 ★★★
      'title': title,
      'url': url,
      'type': type,
      'display_order': displayOrder,
    };
  }

  factory Feed.fromMap(Map<String, dynamic> map) {
    return Feed(
      id: map['id'] as int?,
      // ★★★ ここからが修正箇所 ★★★
      userId: map['userId'] as String? ?? '', // 古いデータにはuserIdがないため、nullの場合は空文字を返す
      // ★★★ ここまでが修正箇所 ★★★
      title: map['title'] as String,
      url: map['url'] as String,
      type: map['type'] as String,
      displayOrder: map['display_order'] as int,
    );
  }
}