import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
// [追加] 騎手名を騎手IDからDB内の長い表記（フルネーム）に置き換えるため (v.2026.9.22+26092207)
import 'package:hetaumakeiba_v2/services/jockey_name_resolver.dart';

// 3列目: 騎手・斤量・馬主セル
class JockeyProfileCell extends StatelessWidget {
  final PredictionHorseDetail horse;
  final String owner;

  const JockeyProfileCell({
    Key? key,
    required this.horse,
    required this.owner,
  }) : super(key: key);

  // [追加] 乗り替わり判定。騎手名は出馬表ページ(race.netkeiba)と馬成績ページ(db.netkeiba)で
  // 表記が揺れる(「Ｍデムーロ」⇔「M.デム」等)ため、騎手IDが両方そろっているときはIDで比較する。
  // IDが欠けている場合(旧キャッシュ・ID取得失敗)のみ従来の名前比較にフォールバックする
  // (v.2026.9.21+26092102)
  static bool isJockeyChanged({
    required String currentJockeyId,
    required String currentJockeyName,
    String? previousJockeyId,
    String? previousJockeyName,
  }) {
    if (currentJockeyId.isNotEmpty &&
        previousJockeyId != null &&
        previousJockeyId.isNotEmpty) {
      return currentJockeyId != previousJockeyId;
    }
    if (previousJockeyName == null || previousJockeyName.isEmpty) {
      return false;
    }
    return currentJockeyName != previousJockeyName;
  }

  @override
  Widget build(BuildContext context) {
    // [修正] 乗り替わり判定を騎手名の文字列比較から騎手IDの比較へ変更 (v.2026.9.21+26092102)
    final bool jockeyChanged = isJockeyChanged(
      currentJockeyId: horse.jockeyId,
      currentJockeyName: horse.jockey,
      previousJockeyId: horse.previousJockeyId,
      previousJockeyName: horse.previousJockey,
    );
    // [修正] 勝負服を22→32に拡大。「替」「初」を騎手名の上の行に印で表示し、騎手名はDB内のフルネーム（最大4文字）を大きく表示。
    // 斤量も拡大。いずれも収まらない場合のみ縮小する (v.2026.9.22+26092207)
    final bool isFirstRide = horse.jockeyComboStats?.isFirstRide == true;
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (horse.ownerImageLocalPath != null && horse.ownerImageLocalPath!.isNotEmpty)
            Image.file(File(horse.ownerImageLocalPath!), width: 32, height: 32, errorBuilder: (c, e, s) => const SizedBox(height: 32))
          else
            const SizedBox(height: 32),
          const SizedBox(height: 2),
          Text(
            owner,
            style: const TextStyle(fontSize: 6, color: Colors.black54),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 2),
          // 「替」「初」の印（無いときも高さを確保して各馬の位置をそろえる）
          SizedBox(
            height: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (jockeyChanged) _buildBadge('替', Colors.orange.shade800),
                if (isFirstRide) _buildBadge('初', Colors.blue.shade700),
              ],
            ),
          ),
          const SizedBox(height: 2),
          FutureBuilder<String?>(
            future: JockeyNameResolver.resolve(horse.jockeyId),
            builder: (context, snapshot) {
              final resolved = snapshot.data;
              final name = (resolved != null && resolved.length > horse.jockey.length) ? resolved : horse.jockey;
              return FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  name,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    color: jockeyChanged ? Colors.orange.shade800 : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              horse.jockeyComboStats?.recordString ?? '--',
              style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${horse.carriedWeight}kg',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // [追加] 「替」「初」の小さな印 (v.2026.9.22+26092207)
  static Widget _buildBadge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold, height: 1.3),
      ),
    );
  }
}

// 4列目: 所属・調教師セル
class TrainerCell extends StatelessWidget {
  final PredictionHorseDetail horse;
  final Color backgroundColor;

  const TrainerCell({
    Key? key,
    required this.horse,
    required this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      // [修正] 背景色が行の区切り線を覆って見えなくなっていたため、下端を1px空ける (v.2026.9.22+26092207)
      margin: const EdgeInsets.only(bottom: 1),
      color: backgroundColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            horse.trainerAffiliation,
            style: const TextStyle(fontSize: 10, color: Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            horse.trainerName,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}