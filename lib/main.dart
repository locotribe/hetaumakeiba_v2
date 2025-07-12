// lib/main.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hetaumakeiba_v2/screens/qr_scanner_page.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const MyHomePage(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale("ja", "JP")],
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.green,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.white)),
        colorScheme: const ColorScheme.dark(primary: Colors.green),
      ),
      themeMode: ThemeMode.system,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Map<String, dynamic>? parsedResult;

  void _openQRScanner() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const QRScannerPage()),
    );
    if (result != null) {
      setState(() {
        parsedResult = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final prettyJson = parsedResult != null
        ? JsonEncoder.withIndent('  ').convert(parsedResult)
        : 'QRコードを読み取ってください';

    return Scaffold(
      appBar: AppBar(title: const Text("馬券QRリーダー")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _openQRScanner,
              child: const Text("QRコード読み取り"),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText.rich(
                  TextSpan(children: _buildTextSpans(parsedResult, prettyJson)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<InlineSpan> _buildTextSpans(
      Map<String, dynamic>? data,
      String fallbackText,
      ) {
    if (data == null) {
      return [TextSpan(text: fallbackText)];
    }

    final List<InlineSpan> spans = [];
    final json = JsonEncoder.withIndent('  ').convert(data);
    final lines = json.split('\n');

    for (final line in lines) {
      final urlMatch = RegExp(r'"URL"\s*:\s*"([^"]+)"').firstMatch(line);
      if (urlMatch != null) {
        final url = urlMatch.group(1)!;
        spans.add(
          TextSpan(
            text: '$line\n',
            style: const TextStyle(color: Colors.blue),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                launchUrl(Uri.parse(url));
              },
          ),
        );
      } else {
        spans.add(TextSpan(text: '$line\n'));
      }
    }

    return spans;
  }
}