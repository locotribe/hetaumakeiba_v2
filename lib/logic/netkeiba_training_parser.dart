// lib/logic/netkeiba_training_parser.dart

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:hetaumakeiba_v2/models/netkeiba_training_model.dart';

// [追加] 調教タブ改修Step2: netkeiba の調教ページ・厩舎コメント・競走馬調教ページの読み取り。
// HTML 文字列を受け取り結果を返すだけの純粋関数（通信・DB 保存はしない） (v.2026.9.22+26092211)

/// 調教ページ（oikiri.html）の読み取り結果。
class NetkeibaOikiriParseResult {
  final List<NetkeibaTrainingReview> reviews;
  final List<NetkeibaTrainingSession> sessions;
  const NetkeibaOikiriParseResult(this.reviews, this.sessions);
}

/// 競走馬調教ページの1レース分の見出し（caption）。
class NetkeibaTrainingRaceHeader {
  final String raceId;
  final String raceDate; // YYYYMMDD（取れなければ ''）
  final String venueRace; // 例: 阪神11R
  final String raceName; // 例: 道頓堀S(3勝)
  final String result; // 例: 8着（未確定は ''）

  const NetkeibaTrainingRaceHeader({
    required this.raceId,
    required this.raceDate,
    required this.venueRace,
    required this.raceName,
    required this.result,
  });
}

/// 競走馬調教ページ（db.netkeiba.com/horse/training.html）の読み取り結果。
class NetkeibaHorseTrainingParseResult {
  final List<NetkeibaTrainingRaceHeader> races;
  final List<NetkeibaTrainingReview> reviews; // 短評のみ
  final List<NetkeibaTrainingSession> sessions;
  const NetkeibaHorseTrainingParseResult(
      this.races, this.reviews, this.sessions);
}

class NetkeibaTrainingParser {
  NetkeibaTrainingParser._();

  static const String sourceOikiri = 'oikiri';
  static const String sourceHorsePage = 'horse_page';

  /// 調教ページ（type=2 最終追切 / type=1 中間含む）を読む。
  /// 各馬の review には短評と「その馬の1本目（=最終追切）」の評価文・評価を入れる。
  static NetkeibaOikiriParseResult parseOikiri(String htmlText, String raceId,
      {String? fetchedAt}) {
    final document = html_parser.parse(htmlText);
    final table = document.querySelector('#All_Oikiri_Table');
    if (table == null) return const NetkeibaOikiriParseResult([], []);

    final sessions = <NetkeibaTrainingSession>[];
    final seqCounter = <String, int>{};
    final horseOrder = <String>[];
    final shortReviews = <String, String?>{};
    final firstCritic = <String, String?>{};
    final firstRank = <String, String?>{};
    String? currentHorseId;

    for (final tr in table.querySelectorAll('tr.HorseList')) {
      if (tr.id.startsWith('tr_')) {
        currentHorseId = _horseIdFromHref(
            tr.querySelector('.Horse_Name a')?.attributes['href']);
        if (currentHorseId != null &&
            !shortReviews.containsKey(currentHorseId)) {
          horseOrder.add(currentHorseId);
          shortReviews[currentHorseId] =
              _clean(tr.querySelector('td.TrainingReview_Cell')?.text);
        }
        continue;
      }
      if (currentHorseId == null) continue;
      final session = _parseSessionRow(
        tr,
        currentHorseId,
        raceId: raceId,
        source: sourceOikiri,
        fetchedAt: fetchedAt,
        seqCounter: seqCounter,
      );
      if (session == null) continue;
      sessions.add(session);
      if (!firstCritic.containsKey(currentHorseId)) {
        firstCritic[currentHorseId] = session.critic;
        firstRank[currentHorseId] = session.rank;
      }
    }

    final reviews = horseOrder
        .map((horseId) => NetkeibaTrainingReview(
              raceId: raceId,
              horseId: horseId,
              shortReview: shortReviews[horseId],
              critic: firstCritic[horseId],
              rank: firstRank[horseId],
              oikiriFetchedAt: fetchedAt,
            ))
        .toList();
    return NetkeibaOikiriParseResult(reviews, sessions);
  }

  /// 厩舎コメントページ（comment.html）を読む。
  static List<NetkeibaTrainingReview> parseStableComment(
      String htmlText, String raceId,
      {String? fetchedAt}) {
    final document = html_parser.parse(htmlText);
    final table = document.querySelector('#All_Comment_Table');
    if (table == null) return [];

    final result = <NetkeibaTrainingReview>[];
    for (final tr in table.querySelectorAll('tr')) {
      final horseId = _horseIdFromHref(
          tr.querySelector('.Horse_Name a')?.attributes['href']);
      if (horseId == null) continue;

      String? comment;
      String? speaker;
      final dd = tr.querySelector('dl.Comment_Cell dd');
      if (dd != null) {
        final spanText = dd.querySelector('span')?.text ?? '';
        speaker = _clean(spanText.replaceAll(RegExp(r'[〈〉<>＜＞]'), ''));
        comment = _clean(
            spanText.isEmpty ? dd.text : dd.text.replaceFirst(spanText, ''));
      }
      final markClass = tr.querySelector('td.Hyoka span')?.className ?? '';
      final mark = RegExp(r'Icon_Mark_(\d+)').firstMatch(markClass)?.group(1);

      result.add(NetkeibaTrainingReview(
        raceId: raceId,
        horseId: horseId,
        stableComment: comment,
        stableSpeaker: speaker,
        stableMark: mark,
        commentFetchedAt: fetchedAt,
      ));
    }
    return result;
  }

  /// 競走馬調教ページ（1ページ目）を読む。文字コード変換（EUC-JP）は呼び出し側で行う。
  static NetkeibaHorseTrainingParseResult parseHorseTraining(
      String htmlText, String horseId,
      {String? fetchedAt}) {
    final document = html_parser.parse(htmlText);
    final races = <NetkeibaTrainingRaceHeader>[];
    final reviews = <NetkeibaTrainingReview>[];
    final sessions = <NetkeibaTrainingSession>[];
    final seqCounter = <String, int>{};

    for (final table
        in document.querySelectorAll('table[summary="調教タイム"]')) {
      final caption = table.querySelector('caption');
      final raceLink = caption?.querySelector('a[href*="/race/"]');
      final raceId = _raceIdFromHref(raceLink?.attributes['href']);
      final captionText = _clean(caption?.text) ?? '';

      if (raceId != null) {
        var result = RegExp(r'結果\s*[：:]\s*(\S*)')
                .firstMatch(captionText)
                ?.group(1) ??
            '';
        if (result == '着') result = '';
        races.add(NetkeibaTrainingRaceHeader(
          raceId: raceId,
          raceDate: _dateYmd(captionText) ?? '',
          venueRace: RegExp(r'\d{4}/\d{1,2}/\d{1,2}\s+(\S+?\d+R)')
                  .firstMatch(captionText)
                  ?.group(1) ??
              '',
          raceName: _clean(raceLink?.text) ?? '',
          result: result,
        ));
      }

      for (final tr in table.querySelectorAll('tr')) {
        if (tr.querySelector('th') != null) continue;
        final tds = tr.children.where((e) => e.localName == 'td').toList();
        if (tds.length == 1) {
          final text = _clean(tds.first.text);
          if (text != null && text.startsWith('[短評]') && raceId != null) {
            reviews.add(NetkeibaTrainingReview(
              raceId: raceId,
              horseId: horseId,
              shortReview: _clean(text.substring('[短評]'.length)),
            ));
          }
          continue;
        }
        final session = _parseSessionRow(
          tr,
          horseId,
          raceId: raceId,
          source: sourceHorsePage,
          fetchedAt: fetchedAt,
          seqCounter: seqCounter,
        );
        if (session != null) sessions.add(session);
      }
    }
    return NetkeibaHorseTrainingParseResult(races, reviews, sessions);
  }

  /// 調教1本の行を読む（調教ページ・競走馬ページ共通）。
  /// 列の位置は「時計セル（td.TrainingTimeData）」を基準に決める:
  /// 日付=-4, コース=-3, 馬場=-2, 乗り役=-1, 位置=+1, 脚色=+2, 評価文=+3, 評価=+4
  static NetkeibaTrainingSession? _parseSessionRow(
    Element tr,
    String horseId, {
    required String? raceId,
    required String source,
    String? fetchedAt,
    required Map<String, int> seqCounter,
  }) {
    final cells = tr.children.where((e) => e.localName == 'td').toList();
    final timeIndex =
        cells.indexWhere((c) => c.classes.contains('TrainingTimeData'));
    if (timeIndex < 4) return null;

    final dateText = _clean(cells[timeIndex - 4].text) ?? '';
    final ymd = _dateYmd(dateText);
    if (ymd == null) return null;
    final hhmm = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(dateText);
    final trainingTime = hhmm == null
        ? null
        : '${hhmm.group(1)!.padLeft(2, '0')}${hhmm.group(2)}';

    final courseCell = cells[timeIndex - 3];
    final isBest = courseCell.querySelector('.IconWeekBestTime') != null ||
        courseCell.text.contains('一番時計');
    final courseRaw = courseCell.text
        .replaceAll('一番時計', '')
        .replaceAll(RegExp(r'\s+'), '');
    if (courseRaw.isEmpty) return null;

    final seqKey = '$horseId|$ymd|$courseRaw';
    final seq = seqCounter[seqKey] ?? 0;
    seqCounter[seqKey] = seq + 1;

    final timeCell = cells[timeIndex];
    final slots = List<double?>.filled(NetkeibaTrainingSession.slotCount, null);
    final laps = List<double?>.filled(NetkeibaTrainingSession.slotCount, null);
    final colors = List<int?>.filled(NetkeibaTrainingSession.slotCount, null);
    final items = timeCell.querySelectorAll('ul.TrainingTimeDataList > li');
    for (int i = 0;
        i < items.length && i < NetkeibaTrainingSession.slotCount;
        i++) {
      final li = items[i];
      final lapText = li.querySelector('span.RapTime')?.text ?? '';
      final slotText =
          lapText.isEmpty ? li.text : li.text.replaceFirst(lapText, '');
      slots[i] = _parseSeconds(slotText);
      laps[i] = _parseSeconds(lapText.replaceAll(RegExp(r'[()（）]'), ''));
      colors[i] = li.classes.contains('TokeiColor01')
          ? 1
          : li.classes.contains('TokeiColor02')
              ? 2
              : 0;
    }

    final partners = _parsePartners(timeCell);

    String? cellText(int offset) {
      final index = timeIndex + offset;
      if (index < 0 || index >= cells.length) return null;
      return _clean(cells[index].text);
    }

    final positionText = cellText(1);
    final rankText = cellText(4);

    return NetkeibaTrainingSession(
      horseId: horseId,
      trainingDate: ymd,
      courseRaw: courseRaw,
      seq: seq,
      trainingTime: trainingTime,
      trackCondition: cellText(-2),
      rider: cellText(-1),
      isBestTime: isBest ? true : null,
      slots: slots,
      laps: laps,
      colors: colors,
      position: positionText == null ? null : int.tryParse(positionText),
      trainingLoad: cellText(2),
      critic: cellText(3),
      rank: (rankText != null && RegExp(r'^[A-E]$').hasMatch(rankText))
          ? rankText
          : null,
      partners: partners.isEmpty ? null : partners,
      raceId: raceId,
      source: source,
      fetchedAt: fetchedAt,
    );
  }

  /// 時計セル内の併せ馬を読む。p 要素が無い場合は、時計リスト以外の文字列を1件として扱う。
  static List<TrainingPartner> _parsePartners(Element timeCell) {
    var paragraphs = timeCell.querySelectorAll('.Comment_Cell p');
    if (paragraphs.isEmpty) paragraphs = timeCell.querySelectorAll('p');
    final result = <TrainingPartner>[];
    for (final p in paragraphs) {
      final partner = _partnerFromText(
          _clean(p.text), p.querySelector('a[href*="/horse/"]'));
      if (partner != null) result.add(partner);
    }
    if (result.isEmpty) {
      final ul = timeCell.querySelector('ul');
      final rest = _clean(
          ul == null ? timeCell.text : timeCell.text.replaceFirst(ul.text, ''));
      final partner =
          _partnerFromText(rest, timeCell.querySelector('a[href*="/horse/"]'));
      if (partner != null) result.add(partner);
    }
    return result;
  }

  static TrainingPartner? _partnerFromText(String? text, Element? link) {
    if (text == null) return null;
    final name = _clean(link?.text) ?? '';
    final index = name.isEmpty ? -1 : text.indexOf(name);
    if (index < 0) {
      return TrainingPartner(side: '', name: '', text: text);
    }
    return TrainingPartner(
      side: text.substring(0, index).trim(),
      horseId: _horseIdFromHref(link?.attributes['href']),
      name: name,
      text: text.substring(index + name.length).trim(),
    );
  }

  /// 空白をまとめて前後を削る。空・'-'・伏せ字は null。
  static String? _clean(String? value) {
    if (value == null) return null;
    final text = value
        .replaceAll(' ', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.isEmpty) return null;
    if (RegExp(r'^[-－]+$').hasMatch(text)) return null;
    if (text.contains('＊')) return null;
    return text;
  }

  static double? _parseSeconds(String text) {
    final value = double.tryParse(text.trim());
    if (value == null || value <= 0) return null;
    return value;
  }

  static String? _dateYmd(String text) {
    final match = RegExp(r'(\d{4})/(\d{1,2})/(\d{1,2})').firstMatch(text);
    if (match == null) return null;
    return '${match.group(1)}${match.group(2)!.padLeft(2, '0')}${match.group(3)!.padLeft(2, '0')}';
  }

  static String? _horseIdFromHref(String? href) {
    if (href == null) return null;
    return RegExp(r'/horse/(\d+)').firstMatch(href)?.group(1);
  }

  static String? _raceIdFromHref(String? href) {
    if (href == null) return null;
    return RegExp(r'/race/(\d{12})').firstMatch(href)?.group(1);
  }
}
