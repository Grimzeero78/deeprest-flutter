import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api.dart';
import '../core/models.dart';
import '../core/ui.dart';

class DuoScreen extends StatefulWidget {
  final Me? me;
  const DuoScreen({super.key, this.me});
  @override
  State<DuoScreen> createState() => _DuoScreenState();
}

class _DuoScreenState extends State<DuoScreen> {
  Map<String, dynamic>? _state;
  final _codeCtrl = TextEditingController();
  bool _loading = true, _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
    Timer.periodic(const Duration(seconds: 10), (_) => _load(silent: true));
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final r = await Api.duo();
      if (!mounted) return;
      setState(() { _state = r; _loading = false; });
    } catch (_) {
      if (!silent && mounted) setState(() => _loading = false);
    }
  }

  Future<void> _invite() async {
    setState(() => _busy = true);
    try {
      await Api.duoInvite();
      await _load();
    } on ApiError catch (e) {
      _snack(e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _accept() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _busy = true);
    try {
      await Api.duoAccept(code);
      _codeCtrl.clear();
      await _load();
      _snack('Duo formed! 🤝');
    } on ApiError catch (e) {
      _snack(e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _unbind() async {
    try {
      await Api.duoUnbind();
      await _load();
    } on ApiError catch (e) {
      _snack(e.message);
    }
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: D.panelHi));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: D.accent));
    final s = _state ?? {};
    final partnership = s['partnership'] as Map<String, dynamic>?;
    final pending = s['pendingInvite'] as Map<String, dynamic>?;
    final partner = s['partner'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: D.bg,
      body: RefreshIndicator(
        color: D.accent,
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(18), children: [
          const Icon(Icons.favorite, color: D.accent, size: 44),
          const SizedBox(height: 8),
          const Text('Dynamic Duo', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text('One partner. Shared accountability.', textAlign: TextAlign.center, style: TextStyle(color: D.sub)),
          const SizedBox(height: 22),

          if (partner != null) ...[
            _partnerCard(partner),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: D.sos, side: const BorderSide(color: D.sos)),
              icon: const Icon(Icons.link_off),
              label: const Text('End partnership'),
              onPressed: _unbind,
            ),
          ] else if (pending != null) ...[
            _card('⏳ Waiting for your partner', [
              const Text('Share this invite code:', style: TextStyle(color: D.sub)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${pending['inviteCode'] ?? ''}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 3, color: D.accent)),
                IconButton(icon: const Icon(Icons.copy, color: D.sub), onPressed: () {
                  Clipboard.setData(ClipboardData(text: '${pending['inviteCode'] ?? ''}'));
                  _snack('Code copied');
                }),
              ]),
            ]),
            const SizedBox(height: 14),
            _card('Got a code instead?', [
              TextField(controller: _codeCtrl, textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(letterSpacing: 3),
                  decoration: const InputDecoration(hintText: 'PASTE CODE')),
              const SizedBox(height: 10),
              FilledButton(style: FilledButton.styleFrom(backgroundColor: D.accent), onPressed: _busy ? null : _accept, child: const Text('Accept Duo invite')),
            ]),
          ] else ...[
            _card('Start your Duo', [
              const Text('Send an invite code to the person who keeps you accountable — or accept theirs.', textAlign: TextAlign.center, style: TextStyle(color: D.sub)),
              const SizedBox(height: 14),
              FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: D.accent), icon: const Icon(Icons.person_add), label: const Text('Create invite code'), onPressed: _busy ? null : _invite),
              const SizedBox(height: 16),
              TextField(controller: _codeCtrl, textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(letterSpacing: 3),
                  decoration: const InputDecoration(hintText: 'Enter a code you received')),
              const SizedBox(height: 10),
              FilledButton.tonal(style: FilledButton.styleFrom(backgroundColor: D.panelHi), onPressed: _busy ? null : _accept, child: const Text('Accept invite')),
            ]),
          ],
          const SizedBox(height: 14),
          const Text('When one of you sends an SOS, the other sees it instantly and can respond "I\'m here" — it lands straight in your chat.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: D.sub)),
        ]),
      ),
    );
  }

  Widget _partnerCard(Map<String, dynamic> partner) {
    final today = (partner['today'] ?? {}) as Map<String, dynamic>;
    final minutes = (today['minutesUsed'] ?? 0) as int;
    final target = (today['targetMin'] ?? 360) as int;
    final met = (today['metTarget'] ?? true) as bool;
    return _card('🤝 Your Duo partner', [
      Row(children: [
        Avatar(name: partner['name'] as String?, color: partner['avatarColor'] as String?, radius: 28),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${partner['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text('🔥 ${partner['streak'] ?? 0} streak · ${partner['totalPoints'] ?? 0} XP', style: const TextStyle(fontSize: 12, color: D.sub)),
        ])),
      ]),
      const Divider(height: 24, color: D.panelHi),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _stat('$minutes', 'min today'),
        _stat('$target', 'their target'),
        _stat(met ? '✅' : '⚠️', met ? 'on track' : 'over target'),
      ]),
    ]);
  }

  Widget _card(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: D.panel, borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }

  Widget _stat(String v, String l) => Column(children: [
    Text(v, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
    Text(l, style: const TextStyle(fontSize: 11, color: D.sub)),
  ]);
}
