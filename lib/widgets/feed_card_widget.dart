// lib/widgets/feed_card_widget.dart
import 'dart:convert';
import 'package:charset_converter/charset_converter.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/feed_model.dart';
import 'package:http/http.dart' as http;
import 'package:rss_dart/dart_rss.dart';
import 'package:url_launcher/url_launcher.dart';

class FeedCard extends StatefulWidget {
  final Feed feed;

  const FeedCard({super.key, required this.feed});

  @override
  State<FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<FeedCard> {
  late Future<dynamic> _feedFuture; // RssFeed or AtomFeed

  @override
  void initState() {
    super.initState();
    _feedFuture = _fetchFeed();
  }

  Future<dynamic> _fetchFeed() async {
    try {
      final response = await http.get(Uri.parse(widget.feed.url));
      if (response.statusCode == 200) {
        String decodedBody;
        try {
          // まずUTF-8としてデコードを試みる
          decodedBody = utf8.decode(response.bodyBytes);
        } catch (e) {
          // UTF-8で失敗した場合、EUC-JPとしてデコードを試みる
          print('Failed to decode as UTF-8, trying EUC-JP...');
          decodedBody = await CharsetConverter.decode('EUC-JP', response.bodyBytes);
        }

        // まずRSSとして解析を試みる
        try {
          return RssFeed.parse(decodedBody);
        } catch (e) {
          // RSSで失敗した場合、Atomとして解析を試みる
          return AtomFeed.parse(decodedBody);
        }
      } else {
        throw Exception('Failed to load feed');
      }
    } catch (e) {
      print('Error fetching or parsing feed for ${widget.feed.title}: $e');
      rethrow;
    }
  }

  Future<void> _launchURL(String? urlString) async {
    if (urlString == null) return;
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      print('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
            child: Text(
              widget.feed.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          FutureBuilder<dynamic>(
            future: _feedFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ));
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return const ListTile(
                  leading: Icon(Icons.error_outline, color: Colors.red),
                  title: Text('フィードの読み込みに失敗しました。'),
                );
              }

              List<dynamic> items = [];
              if (snapshot.data is RssFeed) {
                items = (snapshot.data as RssFeed).items.take(5).toList();
              } else if (snapshot.data is AtomFeed) {
                items = (snapshot.data as AtomFeed).items.take(5).toList();
              }

              if (items.isEmpty) {
                return const ListTile(title: Text('表示できる記事がありません。'));
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (context, index) {
                  final item = items[index];
                  String title = 'タイトルなし';
                  String? link;
                  DateTime? pubDate;

                  if (item is RssItem) {
                    title = item.title ?? 'タイトルなし';
                    link = item.link;
                    if (item.pubDate != null) {
                      pubDate = DateTime.tryParse(item.pubDate!);
                    }
                  } else if (item is AtomItem) {
                    title = item.title ?? 'タイトルなし';
                    link = item.links.isNotEmpty ? item.links.first.href : null;
                    if (item.updated != null) {
                      pubDate = DateTime.tryParse(item.updated!);
                    }
                  }

                  return ListTile(
                    title: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14.0),
                    ),
                    subtitle: pubDate != null
                        ? Text(
                      pubDate.toLocal().toString().substring(0, 16),
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    )
                        : null,
                    onTap: () => _launchURL(link),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}