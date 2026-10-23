// lib/logic/horse_condition_post_parser.dart

// [追加] 出走の意味 調教の行 Step1: netkeiba の近況（db.netkeiba.com/social/horse_info_state.html。未ログインで読める・EUC-JP）を読む。
// 1件は dl.state_disp_dl の中の dt（見出し）・p.comment（本文）・span.time_data_01（日時「2026/06/19 14:24:26」）。文字コードの変換は呼び出し側で行う (v.2026.10.24+26102401)

import 'package:html/parser.dart' as html_parser;
import 'package:hetaumakeiba_v2/models/horse_condition_post_model.dart';

class HorseConditionPostParser {
  const HorseConditionPostParser._();

  /// 近況のページ（UTF-8 に直した文字列）から投稿を読む。ページの上から順に返す。
  /// 見出しか日時が読めない投稿は捨てる。
  static List<HorseConditionPost> parse(String htmlText, String horseId,
      {required String fetchedAt}) {
    final document = html_parser.parse(htmlText);
    final posts = <HorseConditionPost>[];
    final seqCounter = <String, int>{};
    for (final dl in document.querySelectorAll('dl.state_disp_dl')) {
      final title = _clean(dl.querySelector('dt')?.text);
      final postedAt =
          postedAtOf(dl.querySelector('span.time_data_01')?.text ?? '');
      if (title == null || postedAt == null) continue;
      final body = _clean(dl.querySelector('p.comment')?.text) ?? '';
      final seq = seqCounter[postedAt] ?? 0;
      seqCounter[postedAt] = seq + 1;
      posts.add(HorseConditionPost(
        horseId: horseId,
        postedAt: postedAt,
        seq: seq,
        title: title,
        body: body,
        fetchedAt: fetchedAt,
      ));
    }
    return posts;
  }

  /// 「2026/06/19 14:24:26」「2026/6/19 9:05」を「20260619142426」「20260619090500」にする。読めなければ null。
  static String? postedAtOf(String text) {
    final match = RegExp(
            r'(\d{4})/(\d{1,2})/(\d{1,2})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?')
        .firstMatch(text);
    if (match == null) return null;
    String two(String? value) => (value ?? '0').padLeft(2, '0');
    return '${match.group(1)}${two(match.group(2))}${two(match.group(3))}'
        '${two(match.group(4))}${two(match.group(5))}${two(match.group(6))}';
  }

  static String? _clean(String? value) {
    if (value == null) return null;
    final text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.isEmpty ? null : text;
  }
}
