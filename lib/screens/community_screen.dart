import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/models.dart';
import '../core/ui.dart';
import 'chat_screen.dart';

class CommunityScreen extends StatefulWidget {
  final Me? me;
  const CommunityScreen({super.key, this.me});
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  List<User> _users = [];
  String _q = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await Api.users(q: _q);
      if (!mounted) return;
      setState(() {
        _users = list.map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openProfile(User u) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: D.panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => _profileSheet(u),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: D.bg,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: TextField(
            decoration: const InputDecoration(hintText: 'Search members…', prefixIcon: Icon(Icons.search, color: D.sub)),
            onChanged: (v) { _q = v; _load(); },
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: D.accent))
              : RefreshIndicator(
                  color: D.accent,
                  onRefresh: _load,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: D.panelHi, indent: 70),
                    itemBuilder: (_, i) => _row(_users[i]),
                  ),
                ),
        ),
      ]),
    );
  }

  Widget _row(User u) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      leading: Avatar(name: u.name, color: u.avatarColor, image: u.avatarImage, emoji: u.avatarEmoji, radius: 25, online: u.online),
      title: Row(children: [
        Flexible(child: Text(u.name + (u.isMe ? '  (you)' : ''), overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold))),
      ]),
      subtitle: Row(children: [
        Text('${u.totalPoints} XP · 🔥 ${u.streak}', style: const TextStyle(fontSize: 12, color: D.sub)),
        if (u.online) ...[
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: D.accent.withValues(alpha: .15), borderRadius: BorderRadius.circular(8)),
            child: const Text('online', style: TextStyle(fontSize: 10, color: D.accent))),
        ],
      ]),
      trailing: const Icon(Icons.chat_bubble_outline, size: 18, color: D.sub),
      onTap: () => _openProfile(u),
    );
  }

  Widget _profileSheet(User u) {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Avatar(name: u.name, color: u.avatarColor, image: u.avatarImage, emoji: u.avatarEmoji, radius: 44, online: u.online),
        const SizedBox(height: 12),
        Text(u.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text('@${u.username}', style: const TextStyle(color: D.sub)),
        const SizedBox(height: 6),
        Text(u.bio ?? '', textAlign: TextAlign.center, style: const TextStyle(color: D.sub)),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _stat('${u.totalPoints}', 'XP'),
          const SizedBox(width: 24),
          _stat('🔥 ${u.streak}', 'streak'),
        ]),
        const SizedBox(height: 20),
        if (!u.isMe)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: D.accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
              icon: const Icon(Icons.chat_bubble),
              label: const Text('Message'),
              onPressed: () async {
                try {
                  final convoId = await Api.startDm(u.id);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(convoId: convoId, title: u.name, peerAvatar: {'name': u.name, 'color': u.avatarColor, 'image': u.avatarImage, 'emoji': u.avatarEmoji}, isGroup: false)));
                } on ApiError catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: D.sos));
                  }
                }
              },
            ),
          ),
      ]),
    );
  }

  Widget _stat(String v, String label) {
    return Column(children: [
      Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: D.text)),
      Text(label, style: const TextStyle(fontSize: 11, color: D.sub)),
    ]);
  }
}
