// lib/screens/home_settings_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/repositories/user_repository.dart';
import 'package:hetaumakeiba_v2/models/feed_model.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/main.dart';

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
    final userId = localUserId;
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

  void _showAddOrEditFeedDialog({Feed? existingFeed}) {
    final titleController = TextEditingController(text: existingFeed?.title);
    final urlController = TextEditingController(text: existingFeed?.url);
    String selectedType = existingFeed?.type ?? 'RSS';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                decoration: const InputDecoration(labelText: 'URL (RSS または Web)'),
              ),
              DropdownButtonFormField<String>(
                value: selectedType,
                items: const [
                  DropdownMenuItem(value: 'RSS', child: Text('RSS')),
                  DropdownMenuItem(value: 'Web', child: Text('Webページ')),
                ],
                onChanged: (val) => selectedType = val!,
                decoration: const InputDecoration(labelText: 'タイプ'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('キャンセル')),
          TextButton(
            onPressed: () async {
              final userId = localUserId;
              if (userId == null) return;

              if (existingFeed == null) {
                final newFeed = Feed(
                  userId: userId,
                  title: titleController.text,
                  url: urlController.text,
                  type: selectedType,
                  displayOrder: _feeds.length,
                );
                await _userRepository.insertFeed(newFeed);
              } else {
                final updatedFeed = Feed(
                  id: existingFeed.id,
                  userId: userId,
                  title: titleController.text,
                  url: urlController.text,
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