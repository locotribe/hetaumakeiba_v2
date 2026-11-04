// lib/widgets/scraping_progress_banner.dart

// [追加] Phase 3: shutuba_table_page.dartの_buildScrapingProgressIndicator()を
// アプリ全体で共有するグローバルバナーとして独立させたもの。ScrapingManagerはシングルトンで
// アプリ全体を通じてキューを処理し続けるため、出馬表タブを離れても進捗が見え続けるようにする
// (v.2026.9.4+26090406)
// [修正] Phase 4-F: 画面上部(ステータスバー)にあるとRacePageのヘッダー/タブバーと
// 重なり取得中にタブを操作できなかったため、画面下部へ移動した (v.2026.9.5+26090505)
// [追加] 過去走の取得状況ポップアップ: 表示の下に、積まれた取得全体の進み具合を示す棒状のバーを追加した (v.2026.11.5+26110501)

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/services/scraping_manager.dart';
import 'package:hetaumakeiba_v2/widgets/scraping_banner_route_observer.dart';

/// スクレイピングの進捗状況をアプリ全体の最前面に表示するバナー。
/// main.dartのMaterialApp.builder経由で全ルートの上に重ねて配置する。
// [修正] 過去走の取得状況ポップアップ: 棒状のバーが途中で戻らないよう、バッチ内の最大の進み具合を覚えるため StatefulWidget にした (v.2026.11.5+26110501)
class ScrapingProgressBanner extends StatefulWidget {
  const ScrapingProgressBanner({super.key});

  @override
  State<ScrapingProgressBanner> createState() => _ScrapingProgressBannerState();
}

class _ScrapingProgressBannerState extends State<ScrapingProgressBanner> {
  // [追加] 過去走の取得状況ポップアップ: 今のバッチで表示した進み具合の最大値。次の段のタスクが追加されて分母が増えても、バーを戻さない。取得が終わって非表示になったら 0 に戻す (v.2026.11.5+26110501)
  double _maxRatio = 0;

  // [追加] 過去走の取得状況ポップアップ: 全体の進み具合の棒状のバー。Container を使わず ColoredBox で描く (v.2026.11.5+26110501)
  Widget _buildProgressBar(double ratio) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: SizedBox(
          height: 4,
          child: Stack(
            children: [
              const Positioned.fill(child: ColoredBox(color: Colors.white24)),
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: ratio),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, value, _) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value,
                    child: const ColoredBox(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ScrapingBannerRouteObserver.stackDepth,
      builder: (context, stackDepth, _) {
        return StreamBuilder<ScrapingStatus>(
          stream: ScrapingManager().statusStream,
          initialData: ScrapingStatus.idle(),
          builder: (context, snapshot) {
            final status = snapshot.data!;

            if (!status.isRunning) {
              // [追加] 過去走の取得状況ポップアップ: 取得が終わったら進み具合を 0 に戻す (v.2026.11.5+26110501)
              _maxRatio = 0;
              return const SizedBox.shrink();
            }

            // [追加] 過去走の取得状況ポップアップ: 全体の進み具合（完了数÷総数）。分母が増えても戻らないよう最大値を保つ (v.2026.11.5+26110501)
            final ratio = status.totalCount > 0
                ? (status.doneCount / status.totalCount).clamp(0.0, 1.0).toDouble()
                : 0.0;
            if (ratio > _maxRatio) {
              _maxRatio = ratio;
            }

            // [修正] Phase 4-F: 下端にMediaQueryのシステム余白＋（ボトムナビゲーションバー
            // 表示時のみ）kBottomNavigationBarHeightを加算する。このWidgetは
            // ResponsiveBreakpoints.builder()の兄弟としてStackに置かれ、その
            // InheritedWidgetがスコープに無いためResponsiveBreakpoints.of(context)は
            // 実行時例外になる。そのためmain.dartのBreakpoint(start:0, end:450,
            // name: MOBILE)と同じ境界をMediaQueryの幅で直接判定する (v.2026.9.5+26090505)
            final isMobileWidth = MediaQuery.of(context).size.width <= 450;
            final hasBottomNavigationBar = stackDepth == 1 && isMobileWidth;
            final bottomPadding = MediaQuery.of(context).padding.bottom +
                (hasBottomNavigationBar ? kBottomNavigationBarHeight : 0);

            return Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + bottomPadding),
              color: Colors.blueGrey.shade800,
              // [修正] 過去走の取得状況ポップアップ: 今までの表示（Row）の下に棒状のバーを足すため Column で包んだ (v.2026.11.5+26110501)
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          // [修正] Phase 2で追加されたdoneCount/totalCountがある場合はそちらを表示する (v.2026.9.4+26090406)
                          status.totalCount > 0
                              ? '${status.currentTaskName} (${status.doneCount}/${status.totalCount})'
                              : '${status.currentTaskName} (残り: ${status.queueLength}件)',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  _buildProgressBar(_maxRatio),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
