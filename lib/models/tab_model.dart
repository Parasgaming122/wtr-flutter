
import 'package:myapp/core/utils/constants.dart';
import 'package:webview_flutter/webview_flutter.dart';

class Tab {
  final int id;
  String url;
  String title;
  WebViewController? controller;

  Tab({required this.id, this.url = homeUrl, this.title = 'New Tab', this.controller});

  factory Tab.fromMap(Map<String, dynamic> map) {
    return Tab(
      id: map['id'],
      url: map['url'],
      title: map['title'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'title': title,
    };
  }
}
