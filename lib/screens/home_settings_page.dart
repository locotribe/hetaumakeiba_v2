// lib/screens/home_settings_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/feed_model.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/main.dart'; // この行を追加

class HomeSettingsPage extends StatefulWidget {
  const HomeSettingsPage({super.key});

  @override
  State<HomeSettingsPage> createState() => _HomeSettingsPageState();
}

class _HomeSettingsPageState extends State<HomeSettingsPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Feed> _feeds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFeeds();
  }

  Future<void> _loadFeeds() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    // ★★★ ここからが修正箇所 ★★★
    final userId = localUserId; // FirebaseAuthからlocalUserIdに変更
    if (userId == null) {
      if (mounted) {
        setState(() {
          _feeds = [];
          _isLoading = false;
        });
      }
      return;
    }
    final feeds = await _dbHelper.getAllFeeds(userId);
    // ★★★ ここまでが修正箇所 ★★★
    if (mounted) {
      setState(() {
        _feeds = feeds;
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddOrEditFeedDialog({Feed? existingFeed}) async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: existingFeed?.title);
    final urlController = TextEditingController(text: existingFeed?.url);
    String selectedType = existingFeed?.type ?? 'news'; // デフォルトは 'news'

    // ★★★ 修正箇所：URLがYouTubeのRSS形式の場合、チャンネルIDのみを編集欄に表示する ★★★
    if (selectedType == 'youtube' && urlController.text.contains('channel_id=')) {
      urlController.text = Uri.parse(urlController.text).queryParameters['channel_id'] ?? urlController.text;
    }

    final result = await showDialog<Feed?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existingFeed == null ? '新しいフィードを追加' : 'フィードを編集'),
          content: Form(
            key: formKey,
            // ★★★ 修正箇所：StatefulBuilderでフォーム全体を囲み、UIを動的に変更 ★★★
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                final String urlLabel = selectedType == 'youtube' ? 'YouTubeチャンネルID' : 'RSSフィードのURL';
                final String urlHint = selectedType == 'youtube' ? '例: UCxxxxxxxxxxxx' : '例: https://...';

                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'タイトル'),
                        validator: (value) =>
                        value == null || value.isEmpty ? 'タイトルを入力してください' : null,
                      ),
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: const InputDecoration(labelText: '種類'),
                        items: const [
                          DropdownMenuItem(value: 'news', child: Text('ニュース')),
                          DropdownMenuItem(value: 'youtube', child: Text('YouTube')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => selectedType = value);
                          }
                        },
                      ),
                      TextFormField(
                        controller: urlController,
                        decoration: InputDecoration(
                          labelText: urlLabel,
                          hintText: urlHint,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return selectedType == 'youtube' ? 'チャンネルIDを入力してください' : 'URLを入力してください';
                          }
                          // ニュースの場合はURL形式をチェック
                          if (selectedType == 'news') {
                            final uri = Uri.tryParse(value);
                            if (uri == null || !uri.isAbsolute) {
                              return '有効なURLを入力してください';
                            }
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  // ★★★ ここからが修正箇所 ★★★
                  final userId = localUserId; // FirebaseAuthからlocalUserIdに変更
                  if (userId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ユーザー情報の取得に失敗しました。')),
                    );
                    return;
                  }
                  // ★★★ ここまでが修正箇所 ★★★

                  // ★★★ 修正箇所：保存時にURLを自動生成するロジックを追加 ★★★
                  String finalUrl = urlController.text.trim();
                  if (selectedType == 'youtube' && !finalUrl.contains('youtube.com')) {
                    finalUrl = 'https://www.youtube.com/feeds/videos.xml?channel_id=$finalUrl';
                  }

                  final newFeed = Feed(
                    id: existingFeed?.id,
                    // ★★★ ここからが修正箇所 ★★★
                    userId: userId,
                    // ★★★ ここまでが修正箇所 ★★★
                    title: titleController.text,
                    url: finalUrl, // 加工したURLを保存
                    type: selectedType,
                    displayOrder: existingFeed?.displayOrder ?? _feeds.length,
                  );
                  Navigator.of(context).pop(newFeed);
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      if (existingFeed == null) {
        await _dbHelper.insertFeed(result);
      } else {
        await _dbHelper.updateFeed(result);
      }
      _loadFeeds();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ニュースフィード設定'),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomBackground(
              overallBackgroundColor: Color.fromRGBO(231, 234, 234, 1.0),
              stripeColor: Color.fromRGBO(219, 234, 234, 0.6),
              fillColor: Color.fromRGBO(172, 234, 231, 1.0),
            ),
          ),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : (_feeds.isEmpty
              ? _buildEmptyState()
              : _buildFeedList()
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOrEditFeedDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        '登録済みのフィードはありません。\n右下のボタンから追加してください。',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, color: Colors.black54),
      ),
    );
  }

  Widget _buildFeedList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _feeds.length,
      itemBuilder: (context, index) {
        final feed = _feeds[index];
        return Card(
          key: ValueKey(feed.id),
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: ListTile(
            leading: const Icon(Icons.rss_feed),
            title: Text(feed.title),
            subtitle: Text(feed.type == 'youtube' ? 'YouTubeチャンネル' : 'ニュースフィード', style: const TextStyle(fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showAddOrEditFeedDialog(existingFeed: feed),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('削除の確認'),
                        content: Text('「${feed.title}」を本当に削除しますか？'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('キャンセル')),
                          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('削除', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _dbHelper.deleteFeed(feed.id!);
                      _loadFeeds();
                    }
                  },
                ),
                const Icon(Icons.drag_handle),
              ],
            ),
          ),
        );
      },
      onReorder: (oldIndex, newIndex) async {
        if (oldIndex < newIndex) {
          newIndex -= 1;
        }
        final Feed item = _feeds.removeAt(oldIndex);
        _feeds.insert(newIndex, item);
        setState(() {}); // UI上の並び順を即時反映

        await _dbHelper.updateFeedOrder(_feeds);
      },
    );
  }
}