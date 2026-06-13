// lib/services/course_diagram_service.dart
// [追加] コース平面図統合表示機能のためのアセット読込・キャッシュサービス (v.1.0)

import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'package:hetaumakeiba_v2/db/course_elevations.dart';
import 'package:hetaumakeiba_v2/models/course_diagram_model.dart';

/// コース平面図アセット（背景GIF画像＋座標JSON）の読み込み・キャッシュを担うサービス
class CourseDiagramService {
  CourseDiagramService._();
  static final CourseDiagramService instance = CourseDiagramService._();

  final Map<String, CourseEdgeCoordsData> _coordsCache = {};
  final Map<String, CourseImageInfo> _imageInfoCache = {};

  /// venueCode + raceDistance + trackTypeKey（_mapToTrackTypeKey()の戻り値と同一語彙）で
  /// コース平面図データを取得する。該当アセットが存在しない場合はnullを返す。
  ///
  /// 阪神・京都・新潟・中山のように内回り/外回りで芝コースが分かれる競馬場では、
  /// trackTypeKeyが'shiba'（内外回りの判定情報なし）のままだと
  /// '{venue}_shiba_base_coords.json'は存在しないため、CourseElevations.findRaceCourseと
  /// 同じ解決ロジックで実際のトラック種別（shiba_inner/shiba_outer）を特定する。
  Future<CourseDiagramData?> getCourseDiagram(
      String venueCode, int raceDistance, String trackTypeKey) async {
    final slug = CourseVenueNames.slugFor(venueCode);
    if (slug == null) return null;

    final resolvedTrackTypeKey =
        _resolveTrackTypeKey(venueCode, raceDistance, trackTypeKey);

    final coords = await _loadCoords(slug, resolvedTrackTypeKey);
    if (coords == null) return null;

    final imageInfo = await _loadImageInfo(slug);
    if (imageInfo == null) return null;

    return CourseDiagramData(
      imageAsset: 'assets/images/courses/$slug.gif',
      imageInfo: imageInfo,
      coords: coords,
    );
  }

  /// trackTypeKeyが'shiba'（内外回りの判定情報なし）で、かつ該当競馬場が
  /// 内回り/外回りでコースを分けている場合に、CourseElevations.findRaceCourseを用いて
  /// raceDistanceから実際のトラック種別（shiba_inner/shiba_outer）を解決する。
  String _resolveTrackTypeKey(
      String venueCode, int raceDistance, String trackTypeKey) {
    if (trackTypeKey != 'shiba') return trackTypeKey;

    if (CourseElevations.findRaceCourse(venueCode, raceDistance, 'shiba') !=
        null) {
      return 'shiba';
    }

    final inner =
        CourseElevations.findRaceCourse(venueCode, raceDistance, 'shiba_inner');
    if (inner != null) return 'shiba_inner';

    final outer =
        CourseElevations.findRaceCourse(venueCode, raceDistance, 'shiba_outer');
    if (outer != null) return 'shiba_outer';

    return trackTypeKey;
  }

  Future<CourseEdgeCoordsData?> _loadCoords(
      String slug, String trackTypeKey) async {
    final cacheKey = '${slug}_$trackTypeKey';
    final cached = _coordsCache[cacheKey];
    if (cached != null) return cached;

    try {
      final jsonStr = await rootBundle.loadString(
          'assets/data/course_diagrams/${cacheKey}_base_coords.json');
      final data = CourseEdgeCoordsData.fromJson(
          slug, trackTypeKey, jsonDecode(jsonStr) as Map<String, dynamic>);
      _coordsCache[cacheKey] = data;
      return data;
    } catch (_) {
      return null; // 該当JSON未整備
    }
  }

  Future<CourseImageInfo?> _loadImageInfo(String slug) async {
    final cached = _imageInfoCache[slug];
    if (cached != null) return cached;

    try {
      final byteData =
          await rootBundle.load('assets/images/courses/$slug.gif');
      final codec =
          await ui.instantiateImageCodec(byteData.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final info = CourseImageInfo(
          frame.image.width.toDouble(), frame.image.height.toDouble());
      _imageInfoCache[slug] = info;
      return info;
    } catch (_) {
      return null; // 該当GIF未配置
    }
  }
}
