import 'package:flutter/material.dart';

// WhatsApp-dark palette used across the app.
class D {
  static const bg = Color(0xFF0b141a);
  static const panel = Color(0xFF111b21);
  static const panelHi = Color(0xFF202c33);
  static const mine = Color(0xFF005c4b);
  static const accent = Color(0xFF00a884);
  static const text = Color(0xFFe9edef);
  static const sub = Color(0xFF8696a0);
  static const tick = Color(0xFF53bdeb);
  static const sos = Color(0xFFef4444);
  static const amber = Color(0xFFf59e0b);
}

class Avatar extends StatelessWidget {
  final String? name, color, image, emoji;
  final double radius;
  final bool online;
  const Avatar({super.key, this.name, this.color, this.image, this.emoji, this.radius = 24, this.online = false});

  String get initials {
    final n = (name ?? '?').trim();
    if (n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return n[0].toUpperCase();
  }

  Color get bg {
    final c = color;
    if (c != null && c.length >= 7 && c.startsWith('#')) {
      final v = int.tryParse(c.substring(1), radix: 16);
      if (v != null) return Color(0xFF000000 | v);
    }
    return const Color(0xFF8b5cf6);
  }

  @override
  Widget build(BuildContext context) {
    final inner = CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      backgroundImage: (image != null && image!.startsWith('data:image')) ? NetworkImage(image!) : null,
      child: (image == null || !image!.startsWith('data:image'))
          ? (emoji != null && emoji!.isNotEmpty
              ? Text(emoji!, style: TextStyle(fontSize: radius * 0.9))
              : Text(initials, style: TextStyle(fontSize: radius * 0.75, fontWeight: FontWeight.bold, color: Colors.white)))
          : null,
    );
    if (!online) return inner;
    return Stack(children: [
      inner,
      Positioned(
        right: 0, bottom: 0,
        child: Container(
          width: radius * 0.45, height: radius * 0.45,
          decoration: BoxDecoration(color: D.accent, shape: BoxShape.circle, border: Border.all(color: D.bg, width: 2)),
        ),
      ),
    ]);
  }
}

String timeAgo(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final t = DateTime.tryParse(iso);
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return '${t.day}/${t.month}/${t.year}';
}
