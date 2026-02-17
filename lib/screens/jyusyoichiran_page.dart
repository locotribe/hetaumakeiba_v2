import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:charset_converter/charset_converter.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/models/jyusyoichiran_page_data_model.dart';
import 'package:hetaumakeiba_v2/screens/race_page.dart';
import 'package:hetaumakeiba_v2/repositories/race_data_repository.dart';

class JyusyoIchiranPage extends StatefulWidget {
  const JyusyoIchiranPage({super.key});

  @override
  State<JyusyoIchiranPage> createState() => _JyusyoIchiranPageState();
}

class _JyusyoIchiranPageState extends State<JyusyoIchiranPage> {
  final RaceDataRepository _repository = RaceDataRepository();

  late PageController _pageController;
  static const int _initialPage = 10000;
  int _baseYear = DateTime.now().year;

  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  bool _isLoading = false;

  List<JyusyoRace> _yearlyRaceData = [];
  List<JyusyoRace> _monthlyRaceData = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: _initialPage,
      viewportFraction: 0.33,
    );
    _loadDataForYear(_selectedYear);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onYearChanged(int year) {
    if (year == _selectedYear) return;
    setState(() {
      _selectedYear = year;
      _yearlyRaceData = [];
      _monthlyRaceData = [];
    });
    _loadDataForYear(year);
  }

  void _onMonthChanged(int month) {
    setState(() {
      _selectedMonth = month;
      _filterRacesByMonth();
    });
  }

  /// データをロードするメインフロー
  Future<void> _loadDataForYear(int year) async {
    setState(() => _isLoading = true);

    // Repository経由で取得
    List<JyusyoRace> dbRaces = await _repository.getJyusyoRaces(year);

    // データがない場合はスクレイピングして保存
    if (dbRaces.isEmpty) {
      await _fetchAndSaveScheduleData(year);
    } else {
      _yearlyRaceData = dbRaces;
      _filterRacesByMonth();
      setState(() => _isLoading = false);
    }
  }

  /// DBのデータから現在の月でフィルタリング
  void _filterRacesByMonth() {
    setState(() {
      _monthlyRaceData = _yearlyRaceData.where((race) {
        if (race.date.isEmpty) return false;
        try {
          final match = RegExp(r'^(\d{1,2})').firstMatch(race.date);
          if (match != null) {
            int month = int.parse(match.group(1)!);
            return month == _selectedMonth;
          }
          return false;
        } catch (e) {
          return false;
        }
      }).toList();
    });
  }

  /// プルダウン更新処理
  Future<void> _onRefresh() async {
    if (_selectedYear >= DateTime.now().year) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('今年のデータは自動更新されるため、再取得は不要です')),
      );
      return;
    }

    bool hasMissingId = _yearlyRaceData.any((race) => race.raceId == null || race.raceId!.isEmpty);

    if (!hasMissingId && _yearlyRaceData.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('全てのレースIDが取得済みのため、更新は不要です')),
      );
      return;
    }

    await _fetchAndSaveScheduleData(_selectedYear);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('データを更新しました')),
    );
  }

  /// スクレイピングしてDBに保存
  Future<void> _fetchAndSaveScheduleData(int year) async {
    if (!mounted) return;
    if (_yearlyRaceData.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final url = Uri.parse('https://race.netkeiba.com/top/schedule.html?year=$year');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        String htmlBody;
        try {
          htmlBody = await CharsetConverter.decode('EUC-JP', response.bodyBytes);
        } catch (e) {
          htmlBody = response.body;
        }

        var document = parser.parse(htmlBody);
        List<JyusyoRace> fetchedRaces = [];

        var rows = document.querySelectorAll('.race_table_01 tr');

        for (var row in rows) {
          var cells = row.querySelectorAll('td');
          if (cells.length >= 7) {
            String getText(int index) => cells[index].text.trim().replaceAll(RegExp(r'\s+'), ' ');

            String date = getText(0);
            if (date.isEmpty || !date.contains(RegExp(r'\d'))) continue;

            String? raceId;
            String? sourceUrl;

            var anchor = cells[1].querySelector('a');
            if (anchor != null) {
              String href = anchor.attributes['href'] ?? '';

              if (href.contains('/race/')) {
                final idMatch = RegExp(r'race\/(\d+)').firstMatch(href);
                if (idMatch != null) {
                  raceId = idMatch.group(1);
                }
              }

              if (href.startsWith('..')) {
                href = href.replaceFirst('..', 'https://race.netkeiba.com');
              } else if (href.startsWith('/')) {
                href = 'https://race.netkeiba.com$href';
              }
              sourceUrl = href;
            }

            fetchedRaces.add(JyusyoRace(
              year: year,
              date: date,
              raceName: getText(1),
              grade: getText(2),
              venue: getText(3),
              distance: getText(4),
              conditions: getText(5),
              weight: getText(6),
              raceId: raceId,
              sourceUrl: sourceUrl,
            ));
          }
        }

        await _repository.saveJyusyoRaces(fetchedRaces);

        if (mounted) {
          List<JyusyoRace> updatedRaces = await _repository.getJyusyoRaces(year);
          setState(() {
            _yearlyRaceData = updatedRaces;
            _filterRacesByMonth();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// カードタップ時の処理
  Future<void> _onRaceTap(JyusyoRace race) async {
    // 1. IDがある場合は画面遷移
    if (race.raceId != null && race.raceId!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RacePage(
            raceId: race.raceId!,
            raceDate: race.date,
          ),
        ),
      );
      return;
    }

    // 2. IDがない場合は取得処理
    if (race.sourceUrl != null && race.sourceUrl!.isNotEmpty) {
      _showLoadingDialog();

      String? foundId = await _fetchRaceIdFromUrl(race.sourceUrl!, _selectedYear);

      if (!mounted) return;
      Navigator.of(context).pop(); // ダイアログを閉じる

      if (foundId != null && race.id != null) {
        // ★修正ポイント: 全更新せず、DB更新とメモリ上のデータ更新のみ行う

        // A. DBを更新
        await _repository.updateJyusyoRaceId(race.id!, foundId);

        // B. メモリ上のリスト(_yearlyRaceData)の該当データを書き換える
        // これによりListView全体のリロード(スクロールリセット)を防ぎます
        setState(() {
          final index = _yearlyRaceData.indexWhere((r) => r.id == race.id);
          if (index != -1) {
            // JyusyoRaceは不変(final)なので、新しいインスタンスを作成して差し替え
            _yearlyRaceData[index] = JyusyoRace(
              id: race.id,
              year: race.year,
              date: race.date,
              raceName: race.raceName,
              grade: race.grade,
              venue: race.venue,
              distance: race.distance,
              conditions: race.conditions,
              weight: race.weight,
              sourceUrl: race.sourceUrl,
              raceId: foundId, // ここだけ更新されたIDを入れる
            );
            // 表示用リストも再フィルタリングして画面更新
            _filterRacesByMonth();
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('IDを取得しました。もう一度タップして詳細を開いてください。'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('レースIDが見つかりませんでした'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('詳細情報のURLがありません')),
      );
    }
  }

  Future<String?> _fetchRaceIdFromUrl(String url, int year) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        String htmlBody;
        try {
          htmlBody = await CharsetConverter.decode('EUC-JP', response.bodyBytes);
        } catch (e) {
          htmlBody = response.body;
        }
        var document = parser.parse(htmlBody);

        final links = document.querySelectorAll('a');
        for (var link in links) {
          final href = link.attributes['href'];
          if (href != null && href.contains('race_id=')) {
            final match = RegExp(r'race_id=(\d{12})').firstMatch(href);
            if (match != null) {
              String foundId = match.group(1)!;
              if (foundId.startsWith(year.toString())) {
                return foundId;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching detailed ID: $e');
    }
    return null;
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
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

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            children: [
              _buildYearSelector(),
              const SizedBox(height: 16),
              _buildMonthSelector(),
              const SizedBox(height: 16),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _monthlyRaceData.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('データがありません', style: TextStyle(color: Colors.black54)),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _fetchAndSaveScheduleData(_selectedYear),
                        child: const Text('再取得'),
                      )
                    ],
                  ),
                )
                    : RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: _buildRaceList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildYearSelector() {
    const activeColor = Color(0xFF1A4314);
    return SizedBox(
      height: 50,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (int page) {
          final newYear = _baseYear + (page - _initialPage);
          if (newYear != _selectedYear) {
            _onYearChanged(newYear);
          }
        },
        itemBuilder: (context, index) {
          final year = _baseYear + (index - _initialPage);
          final isSelected = (year == _selectedYear);
          return GestureDetector(
            onTap: () {
              _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected ? [BoxShadow(color: activeColor.withOpacity(0.5), blurRadius: 4, offset: const Offset(0, 2))] : [],
              ),
              child: Center(
                child: Text('$year年', style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonthSelector() {
    return GridView.count(
      crossAxisCount: 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.0,
      children: List.generate(12, (index) {
        final month = index + 1;
        final isSelected = month == _selectedMonth;
        return GestureDetector(
          onTap: () => _onMonthChanged(month),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? Colors.grey.shade700 : Colors.white,
              border: Border.all(color: Colors.grey.shade300, width: 0.5),
            ),
            child: Center(
              child: Text('$month月', style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ),
          ),
        );
      }),
    );
  }

  // レース一覧リスト（UIレイアウト修正版）
  Widget _buildRaceList() {
    // PageStorageKeyを追加してスクロール位置を記憶させる
    final Key listKey = PageStorageKey('race_list_${_selectedYear}_$_selectedMonth');

    return ListView.builder(
      key: listKey,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _monthlyRaceData.length,
      itemBuilder: (context, index) {
        final item = _monthlyRaceData[index];
        final bool hasId = (item.raceId != null && item.raceId!.isNotEmpty);

        // 曜日判定による背景色と文字色の設定
        Color dateBgColor = Colors.grey.shade100; // 平日・その他
        Color dateTextColor = Colors.black87;

        if (item.date.contains('日')) {
          dateBgColor = const Color(0xFFFFEBEE); // 薄い赤 (日曜日)
          dateTextColor = Colors.red.shade900;
        } else if (item.date.contains('土')) {
          dateBgColor = const Color(0xFFE3F2FD); // 薄い青 (土曜日)
          dateTextColor = Colors.blue.shade900;
        }

        return GestureDetector(
          onTap: () => _onRaceTap(item),
          child: Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 4),
            color: hasId ? Colors.green.shade50 : Colors.white,
            clipBehavior: Clip.antiAlias, // 左端の背景色をカードの角丸に合わせる
            child: IntrinsicHeight( // 子要素の高さを揃える
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch, // 縦方向に引き伸ばす
                children: [
                  // 1. 一番左: 開催場所と日時 (縦並び・曜日別背景色)
                  Container(
                    width: 60, // 幅を固定
                    color: dateBgColor,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 開催場所
                        Text(
                          item.venue,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: dateTextColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        // 日付
                        Text(
                          item.date,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: dateTextColor,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),

                  // 2. その右: グレード表示 (開催場所があった位置)
                  SizedBox(
                    width: 45,
                    child: Center(
                      child: item.grade.isNotEmpty
                          ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: _getGradeColor(item.grade),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.grade,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                          : const SizedBox.shrink(), // グレードがない場合は空白
                    ),
                  ),

                  // 3. レース名と詳細 (ここからグレード表示を削除)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.raceName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.distance} / ${item.conditions} / ${item.weight}',
                            style: const TextStyle(fontSize: 11, color: Colors.black54),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 4. ステータスアイコン (変更なし)
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: hasId
                        ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        Text("取得済", style: TextStyle(fontSize: 8, color: Colors.green)),
                      ],
                    )
                        : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.download_for_offline, color: Colors.grey, size: 24),
                        Text("ID取得", style: TextStyle(fontSize: 8, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getGradeColor(String grade) {
    if (grade.contains('G1')) return Colors.red;
    if (grade.contains('G2')) return Colors.blue;
    if (grade.contains('G3')) return Colors.green;
    return Colors.grey;
  }
}