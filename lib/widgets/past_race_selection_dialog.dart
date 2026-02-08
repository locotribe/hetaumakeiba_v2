// lib/widgets/past_race_selection_dialog.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:charset_converter/charset_converter.dart';
import 'package:hetaumakeiba_v2/services/past_race_id_fetcher_service.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';

class PastRaceSelectionDialog extends StatefulWidget {
  final PastRaceIdResult initialResult;
  final String defaultSearchText;

  const PastRaceSelectionDialog({
    Key? key,
    required this.initialResult,
    required this.defaultSearchText,
  }) : super(key: key);

  @override
  State<PastRaceSelectionDialog> createState() => _PastRaceSelectionDialogState();
}

class _PastRaceSelectionDialogState extends State<PastRaceSelectionDialog> {
  // 取得したレース一覧
  List<PastRaceItem> _items = [];
  // 選択されたレースIDのセット
  final Set<String> _selectedIds = {};

  // ページネーション用
  String? _currentBaseListUrl;
  int _nextPage = 2;
  bool _isLoadingMore = false;

  // 検索用
  late TextEditingController _searchController;
  bool _isSearching = false;

  // UI状態: false=選択画面, true=確認画面
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.defaultSearchText);

    // 初期データのロード
    if (widget.initialResult.pastRaceItems.isNotEmpty) {
      _items = List.from(widget.initialResult.pastRaceItems);
      _currentBaseListUrl = widget.initialResult.baseListUrl;

      // デフォルトで上位10件を選択状態にする
      for (var i = 0; i < _items.length && i < 10; i++) {
        _selectedIds.add(_items[i].raceId);
      }
    } else {
      // 初期データがない場合は自動で検索を試みるか、空の状態で開始
      // ここではユーザーの操作を待つ
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 手動検索の実行
  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _items.clear();
      _selectedIds.clear();
      _currentBaseListUrl = null;
      _nextPage = 2;
    });

    try {
      // 検索URL生成
      final searchUrl = await generateNetkeibaRaceSearchUrl(raceName: query);
      // front=1 を追加して一覧表示形式にする
      final listUrl = "$searchUrl&front=1";

      // HTTPリクエスト (Cookie等はScraperServiceのヘッダー依存だが、GET検索なら通常アクセスで可)
      // ※簡易的な取得のためhttp直接利用。ScraperServiceに委譲しても良いが今回はここで完結させる
      final response = await http.get(
          Uri.parse(listUrl),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36',
          }
      );

      if (response.statusCode == 200) {
        // EUC-JPデコード
        final decodedBody = await CharsetConverter.decode('EUC-JP', response.bodyBytes);
        // パース
        final newItems = ScraperService.scrapeRaceIdListFromDbPage(decodedBody);

        // モデル変換
        final mappedItems = newItems.map((e) => PastRaceItem(
          raceId: e['raceId']!,
          date: e['date']!,
          venue: e['venue']!,
          raceName: e['raceName']!,
          distance: e['distance']!,
        )).toList();

        setState(() {
          _items = mappedItems;
          _currentBaseListUrl = listUrl;

          // 検索結果の上位10件を自動選択
          for (var i = 0; i < _items.length && i < 10; i++) {
            _selectedIds.add(_items[i].raceId);
          }
        });
      }
    } catch (e) {
      debugPrint("Search error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('検索中にエラーが発生しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  // さらに読み込む
  Future<void> _loadMore() async {
    if (_currentBaseListUrl == null || _isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final fetcher = PastRaceIdFetcherService();
      final moreItems = await fetcher.fetchMorePastRaces(_currentBaseListUrl!, _nextPage);

      if (moreItems.isNotEmpty) {
        setState(() {
          _items.addAll(moreItems);
          _nextPage++;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('これ以上のデータは見つかりませんでした')),
          );
        }
      }
    } catch (e) {
      debugPrint("Load more error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 画面サイズに応じたダイアログの大きさ設定
    final size = MediaQuery.of(context).size;

    return AlertDialog(
      title: Text(_isConfirming ? '最終確認' : '過去データの選択'),
      content: SizedBox(
        width: size.width * 0.9,
        height: size.height * 0.7,
        child: _isConfirming ? _buildConfirmationView() : _buildSelectionView(),
      ),
      actions: _isConfirming ? _buildConfirmationActions() : _buildSelectionActions(),
    );
  }

  // --- 選択画面 (フェーズ1) ---

  Widget _buildSelectionView() {
    return Column(
      children: [
        // 検索エリア
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'レース名で検索',
                  hintText: '例: 有馬記念',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onSubmitted: (_) => _performSearch(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isSearching ? null : _performSearch,
              child: _isSearching
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('再検索'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // ヘッダー情報
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${_items.length}件ヒット / ${_selectedIds.length}件選択中'),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedIds.clear();
                });
              },
              child: const Text("全解除"),
            ),
          ],
        ),
        const Divider(),
        // リストエリア
        Expanded(
          child: _items.isEmpty && !_isSearching
              ? const Center(child: Text('データがありません。\n検索して候補を表示してください。'))
              : ListView.builder(
            itemCount: _items.length + 1, // +1 for Load More button
            itemBuilder: (context, index) {
              if (index == _items.length) {
                // さらに読み込むボタン
                return _currentBaseListUrl != null
                    ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: TextButton(
                    onPressed: _isLoadingMore ? null : _loadMore,
                    child: _isLoadingMore
                        ? const CircularProgressIndicator()
                        : const Text('さらに過去のレースを表示 (+20件)'),
                  ),
                )
                    : const SizedBox.shrink();
              }

              final item = _items[index];
              final isSelected = _selectedIds.contains(item.raceId);

              return CheckboxListTile(
                value: isSelected,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedIds.add(item.raceId);
                    } else {
                      _selectedIds.remove(item.raceId);
                    }
                  });
                },
                title: Text('${item.date} \n${item.raceName}'),
                subtitle: Text('${item.venue} / ${item.distance}'),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSelectionActions() {
    return [
      TextButton(
        onPressed: () => Navigator.of(context).pop(null),
        child: const Text('キャンセル'),
      ),
      ElevatedButton(
        onPressed: _selectedIds.isEmpty
            ? null
            : () {
          setState(() {
            _isConfirming = true;
          });
        },
        child: const Text('確認へ進む'),
      ),
    ];
  }

  // --- 確認画面 (フェーズ2) ---

  Widget _buildConfirmationView() {
    final selectedItems = _items.where((e) => _selectedIds.contains(e.raceId)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '以下の${selectedItems.length}件のレースデータを取得します。\nよろしいですか？',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: selectedItems.length,
            itemBuilder: (context, index) {
              final item = selectedItems[index];
              return ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text('${item.date} \n${item.raceName}'),
                subtitle: Text('${item.venue} / ${item.distance}'),
                dense: true,
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _buildConfirmationActions() {
    final selectedItems = _items.where((e) => _selectedIds.contains(e.raceId)).toList();

    return [
      TextButton(
        onPressed: () {
          setState(() {
            _isConfirming = false;
          });
        },
        child: const Text('戻って修正'),
      ),
      ElevatedButton(
        onPressed: () => Navigator.of(context).pop(selectedItems),
        child: const Text('取得開始'),
      ),
    ];
  }
}