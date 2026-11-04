import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/api.dart';
import '../core/models.dart';
import '../core/ui.dart';
import 'chat_screen.dart';
import 'ai_screen.dart';

class ChatsScreen extends StatefulWidget {
  final VoidCallback onOpenSos;
  const ChatsScreen({super.key, required this.onOpenSos});
  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  List<Conversation> _convos = [];
  bool _loading = true;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final list = await Api.conversations();
      if (!mounted) return;
      setState(() {
        _convos = list.map((e) => Conversation.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!silent && mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Conversation c) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ChatScreen(
                convoId: c.id,
                title: c.name,
                peerAvatar: c.peer != null
                    ? {
                        'name': c.peer!.name,
                        'color': c.peer!.avatarColor,
                        'image': c.peer!.avatarImage,
                        'emoji': c.peer!.avatarEmoji,
                        'publicKey': c.peer!.publicKey,
                      }
                    : null,
                isGroup: c.kind == 'group')));
    _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: D.bg,
      body: RefreshIndicator(
        color: D.accent,
        onRefresh: () => _load(),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: D.accent))
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  // AI companions — pinned like "Meta AI" in WhatsApp
                  const _AiRow(),
                  const Divider(height: 1, color: D.panelHi),
                  if (_convos.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Column(children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: D.panelHi),
                        SizedBox(height: 12),
                        Text('No chats yet', style: TextStyle(color: D.sub, fontSize: 16)),
                        SizedBox(height: 6),
                        Text('Open Community and tap a member to start a conversation.', textAlign: TextAlign.center, style: TextStyle(color: D.sub, fontSize: 13)),
                      ]),
                    )
                  else
                    ..._convos.map((c) => _tile(c)),
                ],
              ),
      ),
    );
  }

  Widget _tile(Conversation c) {
    final lm = c.lastMessage;
    final raw = lm == null
        ? (c.kind == 'group' ? 'Group created' : 'Say hi 👋')
        : lm.body;
    // Encrypted previews show as a lock line until opened.
    final preview = raw.startsWith('{"v":1,')
        ? (lm?.senderId.isNotEmpty ?? false ? '🔒 Encrypted message' : '🔒 Encrypted')
        : (lm != null && lm.kind == 'system' ? raw : raw);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      tileColor: D.bg,
      leading: c.kind == 'group'
          ? CircleAvatar(radius: 26, backgroundColor: D.panelHi, child: Text(c.emoji ?? '🌙', style: const TextStyle(fontSize: 20)))
          : Avatar(name: c.name, color: c.peer?.avatarColor, image: c.peer?.avatarImage, emoji: c.peer?.avatarEmoji, radius: 26, online: c.online),
      title: Text(c.name, maxLines: 1, style: const TextStyle(fontWeight: FontWeight.bold, color: D.text)),
      subtitle: Row(children: [
        if (lm != null && lm.kind != 'system' && lm.senderId.isNotEmpty && c.kind == 'group')
          Text('${lm.senderName.split(' ').first}: ', style: const TextStyle(color: D.sub)),
        Expanded(child: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: D.sub))),
      ]),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (lm != null)
          Text(_clock(lm.createdAt), style: TextStyle(fontSize: 11, color: c.unreadCount > 0 ? D.accent : D.sub)),
        const SizedBox(height: 4),
        if (c.unreadCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: D.accent, borderRadius: BorderRadius.circular(12)),
            child: Text('${c.unreadCount}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
      ]),
      onTap: () => _open(c),
    );
  }

  String _clock(String iso) {
    final t = DateTime.tryParse(iso);
    if (t == null) return '';
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) return DateFormat('HH:mm').format(t);
    return DateFormat('dd/MM/yy').format(t);
  }
}

class _AiRow extends StatelessWidget {
  const _AiRow();
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: const CircleAvatar(radius: 26, backgroundColor: Color(0xFF1f2c34), child: Icon(Icons.auto_awesome, color: D.tick)),
      title: const Text('AI Companions', style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: const Text('Shepherd · Guide · Counselor', style: TextStyle(color: D.sub)),
      trailing: const Icon(Icons.keyboard_arrow_right, color: D.sub),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiScreen())),
    );
  }
}
