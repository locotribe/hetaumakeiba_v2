// lib/screens/home_settings_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/repositories/user_repository.dart';
import 'package:hetaumakeiba_v2/models/feed_model.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
// [修正] main.dartのlocalUserIdグローバル変数からUserSessionサービスへ移行 (v.13.40.4)
import 'package:hetaumakeiba_v2/services/user_session.dart';

class HomeSettingsPage extends StatefulWidget {
  const HomeSettingsPage({super.key});

  @override
  State<HomeSettingsPage> createState() => _HomeSettingsPageState();
}

class _HomeSettingsPageState extends State<HomeSettingsPage> {
  final UserRepository _userRepository = UserRepository();
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
    // [修正] UserSession経由でlocalUserIdを参照 (v.13.40.4)
    final userId = UserSession().localUserId;
    if (userId == null) {
      if (mounted) {
        setState(() {
          _feeds = [];
          _isLoading = false;
        });
      }
      return;
    }
    final feeds = await _userRepository.getAllFeeds(userId);
    if (mounted) {
      setState(() {
        _feeds = feeds;
        _isLoading = false;
      });
    }
  }

  // [追加] 保存済みフィードの種類を、ドロップダウンの選択肢（'RSS' / 'Web' / 'youtube'）に合わせる (v.2026.9.24+26092404)
  // v.13.0.0 以前に保存された 'news'、および 'YouTube'（大文字）で保存されたデータでも編集ダイアログを開けるようにする
  String _normalizeFeedType(String? type) {
    switch (type) {
      case 'RSS':
        return 'RSS';
      case 'Web':
        return 'Web';
      case 'youtube':
      case 'YouTube':
        return 'youtube';
      default:
        return 'RSS';
    }
  }

  void _showAddOrEditFeedDialog({Feed? existingFeed}) {
    final titleController = TextEditingController(text: existingFeed?.title);
    final urlController = TextEditingController(text: existingFeed?.url);
    // [修正] 保存済みの種類を正規化してから選択状態にする (v.2026.9.24+26092404)
    String selectedType = _normalizeFeedType(existingFeed?.type);
    // [追加] YouTubeチャンネルID未入力時のエラー表示用 (v.2026.9.24+26092404)
    String? urlErrorText;

    // [追加] YouTubeフィードの編集時は、保存済みURLからチャンネルIDのみを取り出して入力欄に表示する (v.2026.9.24+26092404)
    if (selectedType == 'youtube' && urlController.text.contains('channel_id=')) {
      urlController.text = Uri.tryParse(urlController.text)?.queryParameters['channel_id'] ?? urlController.text;
    }

    showDialog(
      context: context,
      // [修正] 種類の切り替えに応じて入力欄の表示を変えるため、StatefulBuilder で囲む (v.2026.9.24+26092404)
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final bool isYouTube = selectedType == 'youtube';
          return AlertDialog(
            title: Text(existingFeed == null ? 'フィードの追加' : 'フィードの編集'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'サイト名'),
                  ),
                  TextField(
                    controller: urlController,
                    // [修正] YouTube選択時はラベル・ヒントを「チャンネルID」用に切り替える (v.2026.9.24+26092404)
                    decoration: InputDecoration(
                      labelText: isYouTube ? 'YouTubeチャンネルID' : 'URL (RSS または Web)',
                      hintText: isYouTube ? '例: UCxxxxxxxxxxxx' : null,
                      errorText: urlErrorText,
                    ),
                    // [追加] 入力し直したらエラー表示を消す (v.2026.9.24+26092404)
                    onChanged: (_) {
                      if (urlErrorText != null) {
                        setDialogState(() => urlErrorText = null);
                      }
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    items: const [
                      DropdownMenuItem(value: 'RSS', child: Text('RSS')),
                      DropdownMenuItem(value: 'Web', child: Text('Webページ')),
                      // [修正] 保存値は feed_card_widget.dart の判定に合わせて小文字 'youtube' とする (v.2026.9.24+26092404)
                      DropdownMenuItem(value: 'youtube', child: Text('YouTube')),
                    ],
                    // [修正] 選択に応じて入力欄の表示を切り替えるため setDialogState で再描画する (v.2026.9.24+26092404)
                    onChanged: (val) {
                      if (val == null) return;
                      setDialogState(() {
                        selectedType = val;
                        urlErrorText = null;
                      });
                    },
                    decoration: const InputDecoration(labelText: 'タイプ'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('キャンセル')),
              TextButton(
                onPressed: () async {
                  // [修正] UserSession経由でlocalUserIdを参照 (v.13.40.4)
                  final userId = UserSession().localUserId;
                  if (userId == null) return;

                  // [追加] YouTubeの場合はチャンネルIDからRSSフィードURLを組み立てる。RSS/Webは従来どおり入力値をそのまま保存 (v.2026.9.24+26092404)
                  String finalUrl = urlController.text;
                  if (selectedType == 'youtube') {
                    final String channelInput = urlController.text.trim();
                    if (channelInput.isEmpty) {
                      setDialogState(() => urlErrorText = 'チャンネルIDを入力してください');
                      return;
                    }
                    finalUrl = channelInput.contains('youtube.com')
                        ? channelInput
                        : 'https://www.youtube.com/feeds/videos.xml?channel_id=$channelInput';
                  }

                  if (existingFeed == null) {
                    final newFeed = Feed(
                      userId: userId,
                      title: titleController.text,
                      url: finalUrl,
                      type: selectedType,
                      displayOrder: _feeds.length,
                    );
                    await _userRepository.insertFeed(newFeed);
                  } else {
                    final updatedFeed = Feed(
                      id: existingFeed.id,
                      userId: userId,
                      title: titleController.text,
                      url: finalUrl,
                      type: selectedType,
                      displayOrder: existingFeed.displayOrder,
                    );
                    await _userRepository.updateFeed(updatedFeed);
                  }
                  if (context.mounted) Navigator.of(context).pop();
                  _loadFeeds();
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム設定'),
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
              : Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('ニュースフィードの管理', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Expanded(child: _buildFeedList()),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('新しいフィードを追加'),
                  onPressed: () => _showAddOrEditFeedDialog(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeedList() {
    if (_feeds.isEmpty) {
      return const Center(child: Text('登録されたフィードはありません'));
    }

    return ReorderableListView.builder(
      itemCount: _feeds.length,
      itemBuilder: (context, index) {
        final feed = _feeds[index];
        return Card(
          key: ValueKey(feed.id),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            title: Text(feed.title),
            subtitle: Text(feed.url, maxLines: 1, overflow: TextOverflow.ellipsis),
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
                      await _userRepository.deleteFeed(feed.id!);
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
        setState(() {});

        await _userRepository.updateFeedOrder(_feeds);
      },
    );
  }
}