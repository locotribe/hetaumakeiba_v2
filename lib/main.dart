
// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hetaumakeiba_v2/screens/auth_gate.dart';
import 'package:hetaumakeiba_v2/widgets/scraping_banner_route_observer.dart';
import 'package:hetaumakeiba_v2/widgets/scraping_progress_banner.dart';
import 'package:responsive_framework/responsive_framework.dart';

// [修正] localUserIdグローバル変数を廃止しUserSessionサービスへ移行 (v.13.40.4)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'へたうま競馬',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green[900]!,
          primary: Colors.green[900]!,
        ),
        primarySwatch: Colors.green,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.green[900],
          foregroundColor: Colors.white,
          elevation: 2,
          titleTextStyle: const TextStyle(
            color: Colors.white,      // 文字色を白に指定
            fontSize: 20,             // フォントサイズを指定
            fontWeight: FontWeight.bold, // 文字の太さを指定
          ),
        ),

        tabBarTheme: TabBarThemeData( // 'TabBarTheme' -> 'TabBarThemeData' に修正
          labelColor: Colors.white, // 選択中のタブの文字色
          unselectedLabelColor: Colors.grey[300], // 未選択のタブの文字色
          indicatorColor: Colors.white, // 下線の色
        ),

        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.green[900],
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.grey,
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', ''),
      ],
      // [修正] Phase 3: スクレイピング進捗バナーをアプリ全体の最前面に重ねるため、
      // ResponsiveBreakpoints.builder()をStackで包む (v.2026.9.4+26090406)
      builder: (context, child) => Stack(
        children: [
          ResponsiveBreakpoints.builder(
            child: child!,
            breakpoints: [
              const Breakpoint(start: 0, end: 450, name: MOBILE),
              const Breakpoint(start: 451, end: 800, name: TABLET),
              const Breakpoint(start: 801, end: 1920, name: DESKTOP),
            ],
          ),
          // [修正] Phase 4-F: RacePageのヘッダー/タブバーと重なり取得中にタブを
          // 操作できなかったため、バナーを画面上部から下部へ移動した (v.2026.9.5+26090505)
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Material(
              type: MaterialType.transparency,
              child: IgnorePointer(
                child: ScrapingProgressBanner(),
              ),
            ),
          ),
        ],
      ),
      // [追加] Phase 4-F: 進捗バナーがボトムナビゲーションバーを避けるかどうかの
      // 判定に、ナビゲーションスタックの深さを使う (v.2026.9.5+26090505)
      navigatorObservers: [ScrapingBannerRouteObserver()],
      // アプリの開始点をMainScaffoldに変更
      home: const AuthGate(),
    );
  }
}
