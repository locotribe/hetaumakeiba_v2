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
  // 取得したレース一覧（UI表示用リスト）
  List<PastRaceItem> _items = [];
  // 選択されたレースIDのセット
  final Set<String> _selectedIds = {};
  // 検索ワードを跨いで選択されたオブジェクトを累積保持するマップ
  final Map<String, PastRaceItem> _accumulatedSelectedItems = {};

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
        final item = _items[i];
        _selectedIds.add(item.raceId);
        _accumulatedSelectedItems[item.raceId] = item;
      }
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
      _currentBaseListUrl = null;
      _nextPage = 2;
    });

    try {
      // 検索URL生成
      final searchUrl = await generateNetkeibaRaceSearchUrl(raceName: query);
      final listUrl = "$searchUrl&front=1";

      final response = await http.get(
          Uri.parse(listUrl),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36',
          }
      );

      if (response.statusCode == 200) {
        final decodedBody = await CharsetConverter.decode('EUC-JP', response.bodyBytes);
        final newItemsRaw = ScraperService.scrapeRaceIdListFromDbPage(decodedBody);

        final mappedItems = newItemsRaw.map((e) => PastRaceItem(
          raceId: e['raceId']!,
          date: e['date']!,
          venue: e['venue']!,
          raceName: e['raceName']!,
          distance: e['distance']!,
        )).toList();

        setState(() {
          // ★修正: 選択済みアイテムを先頭に固定し、新しい検索結果を結合する
          final List<PastRaceItem> combinedList = _accumulatedSelectedItems.values.toList();
          // 選択済みエリア内を日付降順でソート
          combinedList.sort((a, b) => b.date.compareTo(a.date));

          // 新しい検索結果の中で、まだ選択済みに入っていないものだけを追加
          for (var newItem in mappedItems) {
            if (!_accumulatedSelectedItems.containsKey(newItem.raceId)) {
              combinedList.add(newItem);
            }
          }

          _items = combinedList;
          _currentBaseListUrl = listUrl;

          // 検索結果からの自動選択（既存ロジックを維持しつつ累積マップを更新）
          int autoSelectedCount = 0;
          for (var i = 0; i < mappedItems.length && autoSelectedCount < 10; i++) {
            final item = mappedItems[i];
            if (!_selectedIds.contains(item.raceId)) {
              _selectedIds.add(item.raceId);
              _accumulatedSelectedItems[item.raceId] = item;
              autoSelectedCount++;
            }
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
          // さらに読み込む場合も、重複を避けて追加
          for (var item in moreItems) {
            if (!_selectedIds.contains(item.raceId)) {
              _items.add(item);
            }
          }
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
    final size = MediaQuery.of(context).size;

    return AlertDialog(
      title: Text(
          _isConfirming ? '最終確認' : '過去データの選択',
          style: const TextStyle(fontSize: 18) // タイトルを少し小さく
      ),
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
                style: const TextStyle(fontSize: 13), // 入力文字を小さく
                decoration: const InputDecoration(
                  labelText: 'レース名で検索',
                  labelStyle: TextStyle(fontSize: 12),
                  hintText: '例: 有馬記念',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onSubmitted: (_) => _performSearch(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isSearching ? null : _performSearch,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
              child: _isSearching
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('再検索', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // ヘッダー情報
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
                '${_items.length}件表示 / ${_accumulatedSelectedItems.length}件選択中',
                style: const TextStyle(fontSize: 11, color: Colors.black87)
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedIds.clear();
                  _accumulatedSelectedItems.clear();
                });
              },
              child: const Text("全解除", style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
        const Divider(height: 8),
        // リストエリア
        Expanded(
          child: _items.isEmpty && !_isSearching
              ? const Center(child: Text('データがありません。', style: TextStyle(fontSize: 13)))
              : ListView.builder(
            itemCount: _items.length + 1,
            itemBuilder: (context, index) {
              if (index == _items.length) {
                return _currentBaseListUrl != null
                    ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: TextButton(
                    onPressed: _isLoadingMore ? null : _loadMore,
                    child: _isLoadingMore
                        ? const CircularProgressIndicator()
                        : const Text('さらに過去を表示', style: TextStyle(fontSize: 11)),
                  ),
                )
                    : const SizedBox.shrink();
              }

              final item = _items[index];
              final isSelected = _selectedIds.contains(item.raceId);

              return CheckboxListTile(
                value: isSelected,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0), // パディングを詰める
                dense: true,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedIds.add(item.raceId);
                      _accumulatedSelectedItems[item.raceId] = item;
                    } else {
                      _selectedIds.remove(item.raceId);
                      _accumulatedSelectedItems.remove(item.raceId);
                    }
                  });
                },
                title: Text(
                    '${item.date} ${item.raceName}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold) // 文字サイズを小さく
                ),
                subtitle: Text(
                    '${item.venue} / ${item.distance}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey) // サブタイトルも小さく
                ),
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
        child: const Text('キャンセル', style: TextStyle(fontSize: 12)),
      ),
      ElevatedButton(
        onPressed: _selectedIds.isEmpty
            ? null
            : () {
          setState(() {
            _isConfirming = true;
          });
        },
        child: const Text('確認へ進む', style: TextStyle(fontSize: 12)),
      ),
    ];
  }

  // --- 確認画面 (フェーズ2) ---

  Widget _buildConfirmationView() {
    final selectedItems = _accumulatedSelectedItems.values.toList();
    selectedItems.sort((a, b) => b.date.compareTo(a.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '以下の${selectedItems.length}件を取得します。',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: selectedItems.length,
            itemBuilder: (context, index) {
              final item = selectedItems[index];
              return ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green, size: 16),
                title: Text('${item.date} ${item.raceName}', style: const TextStyle(fontSize: 11)),
                subtitle: Text('${item.venue} / ${item.distance}', style: const TextStyle(fontSize: 9)),
                dense: true,
                visualDensity: VisualDensity.compact,
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _buildConfirmationActions() {
    final selectedItems = _accumulatedSelectedItems.values.toList();

    return [
      TextButton(
        onPressed: () {
          setState(() {
            _isConfirming = false;
          });
        },
        child: const Text('戻る', style: TextStyle(fontSize: 12)),
      ),
      ElevatedButton(
        onPressed: () => Navigator.of(context).pop(selectedItems),
        child: const Text('取得開始', style: TextStyle(fontSize: 12)),
      ),
    ];
  }
}