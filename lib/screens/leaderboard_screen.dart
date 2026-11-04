import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/models.dart';
import '../core/ui.dart';

class LeaderboardScreen extends StatefulWidget {
  final Me? me;
  const LeaderboardScreen({super.key, this.me});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<User> _leaders = [];
  int _myPos = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.leaderboard();
      if (!mounted) return;
      setState(() {
        _leaders = ((r['leaders'] as List?) ?? []).map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
        final meRow = r['me'] as Map<String, dynamic>?;
        _myPos = (meRow?['position'] ?? 0) as int;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _medal(int pos) => switch (pos) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => '$pos' };

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: D.accent));
    return Scaffold(
      backgroundColor: D.bg,
      body: RefreshIndicator(
        color: D.accent,
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(14), physics: const AlwaysScrollableScrollPhysics(), children: [
          if (_myPos > 0)
            Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: D.accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(12), border: Border.all(color: D.accent.withValues(alpha: .4))),
              child: Row(children: [
                Text('$_myPos', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: D.accent)),
                const SizedBox(width: 12),
                const Expanded(child: Text('Your position', style: TextStyle(color: D.sub))),
                Text('${widget.me?.totalPoints ?? 0} XP', style: const TextStyle(fontWeight: FontWeight.bold)),
              ])),
          ..._leaders.asMap().entries.map((e) {
            final i = e.key; final u = e.value;
            return ListTile(
              leading: SizedBox(width: 34, child: Center(child: Text(_medal(i + 1), style: const TextStyle(fontWeight: FontWeight.bold)))),
              title: Text(u.name + (u.isMe ? '  (you)' : ''), style: TextStyle(fontWeight: u.isMe ? FontWeight.bold : FontWeight.normal, color: u.isMe ? D.accent : D.text)),
              subtitle: Text('🔥 ${u.streak} streak', style: const TextStyle(fontSize: 11, color: D.sub)),
              trailing: Text('${u.totalPoints} XP', style: const TextStyle(fontWeight: FontWeight.bold, color: D.text)),
            );
          }),
        ]),
      ),
    );
  }
}
