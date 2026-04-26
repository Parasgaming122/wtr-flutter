class HistoryItem {
  final String url;
  final String title;
  final int timestamp;

  HistoryItem({
    required this.url,
    required this.title,
    required this.timestamp,
  });

  factory HistoryItem.fromMap(Map<String, dynamic> map) {
    return HistoryItem(
      url: map['url'],
      title: map['title'],
      timestamp: map['timestamp'],
    );
  }

  Map<String, dynamic> toMap() {
    return {'url': url, 'title': title, 'timestamp': timestamp};
  }
}
