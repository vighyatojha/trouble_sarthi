import 'package:flutter/material.dart';
import '../models/service_model.dart';
import '../screens/helper_list_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE CARD  — drop-in replacement for widgets/service_card.dart
// ─────────────────────────────────────────────────────────────────────────────

class ServiceCard extends StatefulWidget {
  final HelperModel service;
  const ServiceCard({super.key, required this.service});

  @override
  State<ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<ServiceCard> {
  bool _pressed = false;

  void _navigate() {
    Navigator.push(context, _smoothRoute(
      HelperListScreen(
        serviceName: widget.service.name,
        categoryName: widget.service.name,
        subServices: [SubServiceItem(widget.service.name, widget.service.icon)],
        serviceColor: widget.service.color,
        serviceBgColor: widget.service.color.withOpacity(0.12),
        categoryEmoji: _emojiFor(widget.service.name),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.service;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); _navigate(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(_pressed ? 0.96 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: s.color.withOpacity(_pressed ? 0.14 : 0.06),
              blurRadius: _pressed ? 6 : 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Icon banner ───────────────────────────────────────────────
            Container(
              height: 110,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [s.color.withOpacity(0.15), s.color.withOpacity(0.05)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Center(child: Icon(s.icon, size: 48, color: s.color)),
            ),
            // ── Content ───────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: s.color),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text('30 Min', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: s.color.withOpacity(0.10),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.arrow_forward_rounded, size: 13, color: s.color),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _emojiFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('plumb') || n.contains('water')) return '🔧';
    if (n.contains('electric')) return '⚡';
    if (n.contains('clean')) return '🧹';
    if (n.contains('ac') || n.contains('air')) return '❄️';
    if (n.contains('carpen')) return '🪚';
    if (n.contains('paint')) return '🎨';
    if (n.contains('pest')) return '🐛';
    if (n.contains('vehicle') || n.contains('car')) return '🚗';
    if (n.contains('house') || n.contains('home')) return '🏠';
    return '🛠️';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared smooth route helper (local to this file)
// ─────────────────────────────────────────────────────────────────────────────

PageRouteBuilder<T> _smoothRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 260),
  );
}