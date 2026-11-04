import 'package:flutter/material.dart';

// ============================================================
// DeepRest Night — the app's own identity.
// Midnight-navy surfaces, moonlight-violet accents, aurora teal
// for presence. WhatsApp-inspired layout DNA, but its own look.
// ============================================================
class D {
  static const bg = Color(0xFF0A0E1A); // deep midnight canvas
  static const panel = Color(0xFF121930); // cards, bars
  static const panelHi = Color(0xFF1B2440); // inputs, their bubbles
  static const mine = Color(0xFF4C3D8F); // my bubbles — moonlit indigo
  static const accent = Color(0xFF8B7CF6); // moonlight violet
  static const teal = Color(0xFF2DD4A8); // online dots, success
  static const text = Color(0xFFEAECF5);
  static const sub = Color(0xFF8B93AB);
  static const tick = Color(0xFF7DD3FC); // read receipts
  static const sos = Color(0xFFEF4444);
  static const amber = Color(0xFFFBBF24);

  /// Curated name-hash gradients so every avatar is unique & vivid.
  static const avatarGradients = <List<Color>>[
    [Color(0xFF8B7CF6), Color(0xFF5B4BC4)], // violet
    [Color(0xFF2DD4A8), Color(0xFF16856B)], // aurora teal
    [Color(0xFFF472B6), Color(0xFFBE3F87)], // rose
    [Color(0xFF60A5FA), Color(0xFF2F6BC4)], // sky
    [Color(0xFFFBBF24), Color(0xFFC07F17)], // moon gold
    [Color(0xFFA78BFA), Color(0xFFEF6FAF)], // dusk
    [Color(0xFF34D399), Color(0xFF0E9488)], // mint
    [Color(0xFFFB923C), Color(0xFFD45B2A)], // ember
  ];
}

class Avatar extends StatelessWidget {
  final String? name, color, image, emoji;
  final double radius;
  final bool online;
  const Avatar(
      {super.key,
      this.name,
      this.color,
      this.image,
      this.emoji,
      this.radius = 24,
      this.online = false});

  String get initials {
    final n = (name ?? '?').trim();
    if (n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return n[0].toUpperCase();
  }

  /// Deterministic vivid gradient from the name — every user gets their
  /// own colour pair (fallback: server avatarColor for flat colours).
  List<Color> get gradient {
    final n = (name ?? '').trim().toLowerCase();
    var h = 0;
    for (final c in n.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return D.avatarGradients[h % D.avatarGradients.length];
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = image != null && image!.startsWith('data:image');
    final inner = CircleAvatar(
      radius: radius,
      backgroundImage: hasPhoto ? NetworkImage(image!) : null,
      child: hasPhoto
          ? null
          : Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
              ),
              alignment: Alignment.center,
              child: emoji != null && emoji!.isNotEmpty
                  ? Text(emoji!,
                      style: TextStyle(fontSize: radius * 0.9))
                  : Text(initials,
                      style: TextStyle(
                          fontSize: radius * 0.75,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
            ),
    );
    if (!online) return inner;
    return Stack(children: [
      inner,
      Positioned(
        right: 0,
        bottom: 0,
        child: Container(
          width: radius * 0.45,
          height: radius * 0.45,
          decoration: BoxDecoration(
              color: D.teal,
              shape: BoxShape.circle,
              border: Border.all(color: D.bg, width: 2)),
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
