// lib/screens/home_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/screens/qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/gallery_qr_scanner_page.dart';

class HomePage extends StatefulWidget {
  final GlobalKey<SavedTicketsListPageState> savedListKey;

  const HomePage({super.key, required this.savedListKey});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  bool _isFabExpanded = false;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleFab() {
    setState(() {
      _isFabExpanded = !_isFabExpanded;
      if (_isFabExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomBackground(
            overallBackgroundColor: const Color.fromRGBO(231, 234, 234, 1.0),
            stripeColor: const Color.fromRGBO(219, 234, 234, 0.6),
            fillColor: const Color.fromRGBO(172, 234, 231, 1.0),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('へたうま競馬'),
            automaticallyImplyLeading: false,
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SavedTicketsListPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.list_alt, size: 28),
                  label: const Text(
                    '購入履歴',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    elevation: 3,
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isFabExpanded)
                ScaleTransition(
                  scale: _animation,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: FloatingActionButton(
                      heroTag: 'galleryFab',
                      onPressed: () {
                        _toggleFab();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GalleryQrScannerPage(savedListKey: widget.savedListKey),
                          ),
                        );
                      },
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      child: const Icon(Icons.image),
                    ),
                  ),
                ),
              if (_isFabExpanded)
                ScaleTransition(
                  scale: _animation,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: FloatingActionButton(
                      heroTag: 'cameraFab',
                      onPressed: () {
                        _toggleFab();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => QRScannerPage(savedListKey: widget.savedListKey),
                          ),
                        );
                      },
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      child: const Icon(Icons.camera_alt),
                    ),
                  ),
                ),
              FloatingActionButton(
                heroTag: 'mainFab',
                onPressed: _toggleFab,
                backgroundColor: _isFabExpanded ? Colors.grey : Colors.blueAccent,
                foregroundColor: Colors.white,
                child: AnimatedIcon(
                  icon: AnimatedIcons.menu_close,
                  progress: _animation,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}