// lib/screens/home_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/feed_model.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/widgets/feed_card_widget.dart';
import 'package:hetaumakeiba_v2/screens/home_settings_page.dart';
import 'package:hetaumakeiba_v2/main.dart'; // この行を追加

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<List<Feed>> _feedsFuture;

  @override
  void initState() {
    super.initState();
    _refreshFeeds();
  }

  void _refreshFeeds() {
    if (mounted) {
      setState(() {
        // ★★★ ここからが修正箇所 ★★★
        final userId = localUserId; // FirebaseAuthからlocalUserIdに変更
        if (userId == null) {
          // ユーザーIDが取得できない場合、空のリストを返すFutureを設定
          _feedsFuture = Future.value([]);
        } else {
          _feedsFuture = _dbHelper.getAllFeeds(userId);
        }
        // ★★★ ここまでが修正箇所 ★★★
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: CustomBackground(
            overallBackgroundColor: Color.fromRGBO(231, 234, 234, 1.0),
            stripeColor: Color.fromRGBO(219, 234, 234, 0.6),
            fillColor: Color.fromRGBO(172, 234, 231, 1.0),
          ),
        ),
        FutureBuilder<List<Feed>>(
          future: _feedsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('データの読み込みに失敗しました。'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyState();
            }

            final feeds = snapshot.data!;
            return RefreshIndicator(
              onRefresh: () async => _refreshFeeds(),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                itemCount: feeds.length,
                itemBuilder: (context, index) {
                  return FeedCard(feed: feeds[index]);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_link, size: 60, color: Colors.black38),
          const SizedBox(height: 16),
          const Text(
            'ホームページに表示する\nフィードが登録されていません。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.settings),
            label: const Text('設定画面から追加する'),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const HomeSettingsPage(),
                ),
              );
              _refreshFeeds();
            },
          ),
        ],
      ),
    );
  }
}