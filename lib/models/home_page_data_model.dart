// lib/models/home_page_data_model.dart

import 'package:hetaumakeiba_v2/models/featured_race_model.dart';

/// ホームページに表示する全てのデータを保持するためのコンテナクラス
class HomePageData {
  // 上部に表示する重賞レースのリスト
  final List<FeaturedRace> gradedRaces;
  // 下部に表示する開催場ごとのレースリスト
  final List<VenueRaces> racesByVenue;

  HomePageData({
    required this.gradedRaces,
    required this.racesByVenue,
  });
}

/// 開催場ごとのレース情報を保持するクラス
class VenueRaces {
  final String venueName; // 競馬場名 (例: "新潟")
  final String date;      // 開催日 (例: "8/3(日)")
  final List<SimpleRaceInfo> races; // その競馬場で開催されるレースのリスト

  VenueRaces({
    required this.venueName,
    required this.date,
    required this.races,
  });
}

/// 開催場別レース一覧で表示するための、簡略化されたレース情報クラス
class SimpleRaceInfo {
  final String raceId;       // ネット競馬のレースID
  final String raceNumber;   // レース番号 (例: "11R")
  final String raceName;     // レース名 (例: "テレビユー福島賞")
  final String conditions;   // 条件 (例: "3歳上2勝クラス")
  final String distance;     // 距離 (例: "芝1200m")

  SimpleRaceInfo({
    required this.raceId,
    required this.raceNumber,
    required this.raceName,
    required this.conditions,
    required this.distance,
  });
}
