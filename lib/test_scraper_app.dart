// lib/test_scraper_app.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MaterialApp(
    home: TestScraperApp(),
  ));
}

// --- モデルクラス ---

class ScrapedWeekData {
  final List<DateTab> tabs;
  // この週の代表日（アクティブなタブの日付など）
  final String activeDateUrl;

  ScrapedWeekData({
    required this.tabs,
    required this.activeDateUrl,
  });
}

class DateTab {
  final String label; // 例: "2/16(日)"
  final String url;
  final bool isActive;

  DateTab({required this.label, required this.url, required this.isActive});
}

class SimpleRaceData {
  final String venue;
  final String raceNumber;
  final String raceName;
  final String time;

  SimpleRaceData({
    required this.venue,
    required this.raceNumber,
    required this.raceName,
    required this.time,
  });
}

// --- メイン画面 ---

class TestScraperApp extends StatefulWidget {
  const TestScraperApp({super.key});

  @override
  State<TestScraperApp> createState() => _TestScraperAppState();
}

class _TestScraperAppState extends State<TestScraperApp> {
  static const String _baseUrl = 'https://race.netkeiba.com/top/race_list.html';

  bool _isWeekLoading = false;
  bool _isBackgroundLoading = false;
  String _statusMessage = '';

  // 現在表示中の週の基準日
  // 初期値は暫定で今日を入れるが、ロード完了時にサイト側の実態に合わせて更新する
  DateTime _currentDate = DateTime.now();

  ScrapedWeekData? _weekStructure;

  // 週構成データのキャッシュ (Key: URL, Value: 週データ)
  final Map<String, ScrapedWeekData> _weekCache = {};

  // レース詳細データのキャッシュ (Key: 各日付タブのURL, Value: レースリスト)
  final Map<String, List<SimpleRaceData>> _loadedRacesMap = {};

  String? _currentTabUrl;
  HeadlessInAppWebView? _headlessWebView;

  @override
  void initState() {
    super.initState();
    // 初期ロード時は日付指定なしのURLへアクセス
    _startFetchSequence(_baseUrl);
  }

  @override
  void dispose() {
    _headlessWebView?.dispose();
    super.dispose();
  }

  /// 矢印ボタン：前の週へ
  void _goToPreviousWeek() {
    if (_isWeekLoading) return;
    // 現在の基準日から7日引く
    final prevDate = _currentDate.subtract(const Duration(days: 7));
    _loadWeekForDate(prevDate);
  }

  /// 矢印ボタン：次の週へ
  void _goToNextWeek() {
    if (_isWeekLoading) return;
    // 現在の基準日から7日足す
    final nextDate = _currentDate.add(const Duration(days: 7));
    _loadWeekForDate(nextDate);
  }

  /// 指定日をURLパラメータにしてロード
  Future<void> _loadWeekForDate(DateTime date) async {
    // UI上の日付を更新（ロード失敗してもユーザーの意図を反映するため）
    setState(() {
      _currentDate = date;
    });

    final dateStr = DateFormat('yyyyMMdd').format(date);
    final url = '$_baseUrl?kaisai_date=$dateStr';
    await _startFetchSequence(url);
  }

  String _normalizeUrl(String rawUrl) {
    if (rawUrl.isEmpty) return '';
    if (rawUrl.contains('race_list_sub.html')) {
      return rawUrl.replaceAll('race_list_sub.html', 'race_list.html');
    }
    return rawUrl;
  }

  /// URLから kaisai_date=YYYYMMDD を抽出して DateTimeにする
  DateTime? _parseDateFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final dateStr = uri.queryParameters['kaisai_date'];
      if (dateStr != null && dateStr.length == 8) {
        final y = int.parse(dateStr.substring(0, 4));
        final m = int.parse(dateStr.substring(4, 6));
        final d = int.parse(dateStr.substring(6, 8));
        return DateTime(y, m, d);
      }
    } catch (e) {
      // parse error
    }
    return null;
  }

  Future<void> _startFetchSequence(String targetUrl) async {
    if (_isWeekLoading) return;

    String fullUrl = targetUrl;
    if (!fullUrl.startsWith('http')) {
      fullUrl = 'https://race.netkeiba.com/top/$fullUrl';
    }
    fullUrl = _normalizeUrl(fullUrl);

    // --- キャッシュチェック ---
    if (_weekCache.containsKey(fullUrl)) {
      print("Week Cache Hit: $fullUrl");
      final cachedWeekData = _weekCache[fullUrl]!;

      _applyWeekData(cachedWeekData, fromCache: true);
      return;
    }

    // --- 新規取得 ---
    setState(() {
      _isWeekLoading = true;
      _statusMessage = '週データを取得中...';
    });

    final result = await _fetchPage(fullUrl);

    if (result != null) {
      final weekData = result['weekData'] as ScrapedWeekData;
      if (weekData.tabs.isEmpty) {
        if (mounted) {
          setState(() {
            // 「情報なし」状態にする
            _weekStructure = weekData; // tabsが空のデータが入る
            _loadedRacesMap.clear(); // または該当URL分をクリア
            _currentTabUrl = null;
            _isWeekLoading = false;
            _statusMessage = '開催情報がまだありません';
          });
        }
        return; // これ以上何もしない
      }
      final races = result['races'] as List<SimpleRaceData>;
      final fetchedUrl = result['fetchedUrl'] as String; // 実際にロードされたURL（タブのURL等）

      // レースデータを保存
      if (mounted) {
        setState(() {
          _loadedRacesMap[fetchedUrl] = races;
        });
      }

      // 週データを適用＆キャッシュ登録
      _applyWeekData(weekData, sourceUrl: fullUrl);

    } else {
      if (mounted) {
        setState(() {
          _isWeekLoading = false;
          _statusMessage = '取得失敗';
        });
      }
    }
  }

  /// 取得またはキャッシュした週データをUIに適用し、関連データの整合性を取る
  void _applyWeekData(ScrapedWeekData weekData, {String? sourceUrl, bool fromCache = false}) async {
    if (!mounted) return;

    // 1. アクティブなタブを探す
    String activeTabUrl = weekData.activeDateUrl;

    // 2. もしアクティブURLが空なら、最初のタブを使う等のフォールバック
    if ((activeTabUrl.isEmpty) && weekData.tabs.isNotEmpty) {
      activeTabUrl = weekData.tabs.first.url;
    }

    // 3. アプリの基準日(_currentDate)を、取得したデータのアクティブな日付に同期する
    final syncDate = _parseDateFromUrl(activeTabUrl);
    if (syncDate != null) {
      _currentDate = syncDate;
    }

    // 4. キャッシュへの登録（重要：エイリアス登録）
    if (sourceUrl != null) {
      // 要求されたURLで登録
      _weekCache[sourceUrl] = weekData;

      // さらに、アクティブなタブのURL（日付指定URL）でも同じデータを登録しておく
      // これにより、矢印で「戻ってきた」時に、日付指定URLでヒットするようになる
      if (activeTabUrl.isNotEmpty && activeTabUrl != sourceUrl) {
        _weekCache[activeTabUrl] = weekData;
      }
    }

    setState(() {
      _weekStructure = weekData;
      _currentTabUrl = activeTabUrl;
      _isWeekLoading = false;
      _statusMessage = fromCache ? 'キャッシュ表示' : '取得完了';
    });

    // 5. 残りのタブのデータを裏で取得
    await _fetchRemainingTabs(weekData.tabs);
  }

  Future<void> _fetchRemainingTabs(List<DateTab> tabs) async {
    if (!mounted) return;
    setState(() => _isBackgroundLoading = true);

    for (final tab in tabs) {
      // 既にレースデータがあるURLはスキップ
      if (_loadedRacesMap.containsKey(tab.url)) continue;

      if (mounted) {
        setState(() => _statusMessage = '${tab.label} を取得中...');
      }

      final result = await _fetchPage(tab.url);

      if (result != null && mounted) {
        final races = result['races'] as List<SimpleRaceData>;
        setState(() {
          _loadedRacesMap[tab.url] = races;
        });
      }

      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (mounted) {
      setState(() {
        _isBackgroundLoading = false;
        final dateLabel = DateFormat('M/d').format(_currentDate);
        _statusMessage = '準備完了 (基準: $dateLabel)';
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchPage(String url) async {
    print("Fetching: $url");

    if (_headlessWebView != null) {
      await _headlessWebView!.dispose();
      _headlessWebView = null;
    }

    final completer = Completer<Map<String, dynamic>?>();

    _headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36",
        javaScriptEnabled: true,
        loadsImagesAutomatically: false,
        blockNetworkImage: true,
      ),
      onLoadStop: (controller, loadedUrl) async {
        if (completer.isCompleted) return;
        try {
          await _waitForElement(controller, "#date_list_sub, .NoData_Comment, .RaceList_Body");
          final jsResult = await controller.evaluateJavascript(source: _scrapingScript);

          if (jsResult != null) {
            final Map<String, dynamic> data = json.decode(jsResult);
            // URLは正規化したものを渡す
            completer.complete(_parseData(data, url));
          } else {
            completer.complete(null);
          }
        } catch (e) {
          if (!completer.isCompleted) completer.complete(null);
        }
      },
      onReceivedError: (controller, request, error) {
        if (!completer.isCompleted) completer.complete(null);
      },
    );

    try {
      await _headlessWebView!.run();
      return await completer.future.timeout(const Duration(seconds: 20));
    } catch (e) {
      return null;
    }
  }

  Future<void> _waitForElement(InAppWebViewController controller, String selector) async {
    int retries = 0;
    while (retries < 20) {
      final bool exists = await controller.evaluateJavascript(source: """
        document.querySelector('$selector') !== null
      """) ?? false;
      if (exists) return;
      await Future.delayed(const Duration(milliseconds: 300));
      retries++;
    }
  }

  Map<String, dynamic> _parseData(Map<String, dynamic> data, String requestUrl) {
    final List<dynamic> rawTabs = data['tabs'] ?? [];
    final tabs = rawTabs.map((t) => DateTab(
      label: t['label'] ?? '',
      url: _normalizeUrl(t['url'] ?? ''),
      isActive: t['isActive'] ?? false,
    )).toList();

    // アクティブなタブのURLを特定
    String activeUrl = '';
    try {
      final activeTab = tabs.firstWhere((t) => t.isActive);
      activeUrl = activeTab.url;
    } catch (e) {
      // なければリクエストURLを正とする
      activeUrl = requestUrl;
    }

    final List<dynamic> rawRaces = data['races'] ?? [];
    final races = rawRaces.map((r) => SimpleRaceData(
      venue: r['venue'] ?? '',
      raceNumber: r['raceNumber'] ?? '',
      raceName: r['raceName'] ?? '',
      time: r['time'] ?? '',
    )).toList();

    return {
      'fetchedUrl': activeUrl, // ここでは実際にアクティブなタブのURLを返す
      'weekData': ScrapedWeekData(
        tabs: tabs,
        activeDateUrl: activeUrl,
      ),
      'races': races,
    };
  }

  final String _scrapingScript = """
    (function() {
      const tabEls = document.querySelectorAll('#date_list_sub li:not(.rev):not(.fwd)');
      if (tabEls.length === 0) {
        return JSON.stringify({
          tabs: [],
          races: []
        });
      }
      const tabs = [];
      tabEls.forEach(li => {
        const a = li.querySelector('a');
        if (a && a.href) {
          tabs.push({
            label: a.innerText.trim(),
            url: a.href,
            isActive: li.classList.contains('active') || li.classList.contains('ui-tabs-active')
          });
        }
      });

      const races = [];
      const raceBlocks = document.querySelectorAll('.RaceList_DataList');
      raceBlocks.forEach(block => {
        const venueTitleEl = block.querySelector('.RaceList_DataTitle');
        const venueName = venueTitleEl ? venueTitleEl.innerText.trim() : '';
        const items = block.querySelectorAll('.RaceList_DataItem');
        items.forEach(item => {
           const numEl = item.querySelector('.Race_Num');
           const nameEl = item.querySelector('.ItemTitle');
           const dataEl = item.querySelector('.RaceData');
           let detailText = '';
           if (dataEl) {
             detailText = dataEl.innerText.replace(/\\n/g, ' ').replace(/\\s+/g, ' ').trim();
           }
           races.push({
             venue: venueName,
             raceNumber: numEl ? numEl.innerText.trim() : '',
             raceName: nameEl ? nameEl.innerText.trim() : '',
             time: detailText 
           });
        });
      });

      return JSON.stringify({
        tabs: tabs,
        races: races
      });
    })();
  """;

  @override
  Widget build(BuildContext context) {
    // 現在のアクティブURLに紐づくレースデータを取得
    final currentRaces = _currentTabUrl != null
        ? _loadedRacesMap[_currentTabUrl]
        : [];

    final dateDisplay = DateFormat('yyyy/MM/dd').format(_currentDate);

    return Scaffold(
      appBar: AppBar(title: const Text('キャッシュ＆日付同期 完全版')),
      body: Column(
        children: [
          if (_isWeekLoading || _isBackgroundLoading)
            LinearProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                  _isWeekLoading ? Colors.blue : Colors.green
              ),
            ),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey[200],
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _statusMessage.isEmpty ? '完了' : _statusMessage,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('基準日: $dateDisplay', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          if (_weekStructure != null)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _isWeekLoading ? null : _goToPreviousWeek,
                  ),
                  const SizedBox(width: 10),

                  ..._weekStructure!.tabs.map((tab) {
                    final isLoaded = _loadedRacesMap.containsKey(tab.url);
                    final isSelected = tab.url == _currentTabUrl;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Row(
                          children: [
                            Text(tab.label),
                            if (!isLoaded) ...[
                              const SizedBox(width: 4),
                              const SizedBox(
                                  width: 8, height: 8,
                                  child: CircularProgressIndicator(strokeWidth: 2)
                              )
                            ]
                          ],
                        ),
                        selected: isSelected,
                        onSelected: (bool selected) {
                          if (selected && isLoaded) {
                            setState(() {
                              _currentTabUrl = tab.url;
                              // タブ切り替え時も基準日を更新しておくと、そこからの移動がスムーズになる
                              final d = _parseDateFromUrl(tab.url);
                              if (d != null) _currentDate = d;
                            });
                          }
                        },
                      ),
                    );
                  }),

                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _isWeekLoading ? null : _goToNextWeek,
                  ),
                ],
              ),
            ),

          const Divider(height: 1),

          Expanded(
            child: _weekStructure == null
                ? const Center(child: Text('データなし'))
                : (currentRaces == null || currentRaces.isEmpty)
                ? const Center(child: Text('この日のレース情報はありません'))
                : ListView.separated(
              itemCount: currentRaces.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final race = currentRaces[index];
                return ListTile(
                  leading: Container(
                    width: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      race.raceNumber,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    race.raceName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${race.venue} / ${race.time}'),
                  dense: true,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}