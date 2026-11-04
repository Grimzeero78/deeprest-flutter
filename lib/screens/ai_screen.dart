import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/ui.dart';

const _personas = [
  {'id': 'SHEPHERD', 'name': 'Shepherd', 'emoji': '🛡️', 'desc': 'Discipline & structure'},
  {'id': 'GUIDE', 'name': 'Guide', 'emoji': '🧭', 'desc': 'Practical steps & plans'},
  {'id': 'COUNSELOR', 'name': 'Counselor', 'emoji': '💛', 'desc': 'Gentle, listens deeply'},
];

class AiScreen extends StatelessWidget {
  const AiScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: D.bg,
      appBar: AppBar(title: const Text('AI Companions')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        const Text('Three companions trained to help you rest deeply. Everything you tell them is private.',
            style: TextStyle(color: D.sub)),
        const SizedBox(height: 16),
        ..._personas.map((p) => Card(
          color: D.panel,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(radius: 26, backgroundColor: D.panelHi, child: Text('${p['emoji']}', style: const TextStyle(fontSize: 22))),
            title: Text('${p['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${p['desc']}', style: const TextStyle(color: D.sub, fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: D.sub),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AiChat(persona: p))),
          ),
        )),
      ]),
    );
  }
}

class AiChat extends StatefulWidget {
  final Map<String, dynamic> persona;
  const AiChat({super.key, required this.persona});
  @override
  State<AiChat> createState() => _AiChatState();
}

class _AiChatState extends State<AiChat> {
  final _ctrl = TextEditingController();
  final List<_Msg> _msgs = [];
  bool _busy = false, _loaded = false;

  String get _id => widget.persona['id'] as String;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.aiGet(_id);
      if (!mounted) return;
      setState(() {
        final greeting = (r['greeting'] ?? '') as String;
        if (greeting.isNotEmpty) _msgs.add(_Msg(greeting, false, system: true));
        for (final m in ((r['messages'] as List?) ?? [])) {
          final mm = m as Map<String, dynamic>;
          _msgs.add(_Msg((mm['content'] ?? '') as String, (mm['role'] ?? '') == 'user'));
        }
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _busy) return;
    _ctrl.clear();
    setState(() { _msgs.add(_Msg(text, true)); _busy = true; });
    try {
      final reply = await Api.aiSend(_id, text);
      if (mounted) setState(() => _msgs.add(_Msg(reply, false)));
    } on ApiError catch (e) {
      if (mounted) setState(() => _msgs.add(_Msg('⚠️ ${e.message}', false, system: true)));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _clear() async {
    try {
      await Api.aiClear(_id);
      if (mounted) setState(() => _msgs.clear());
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.persona;
    return Scaffold(
      backgroundColor: D.bg,
      appBar: AppBar(title: Row(children: [
        Text('${p['emoji']}', style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Text('${p['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
      actions: [IconButton(icon: const Icon(Icons.delete_outline, color: D.sub), onPressed: _clear, tooltip: 'Clear history')],
      ),
      body: Column(children: [
        Expanded(child: !_loaded
            ? const Center(child: CircularProgressIndicator(color: D.accent))
            : ListView.builder(padding: const EdgeInsets.all(14), itemCount: _msgs.length,
                itemBuilder: (_, i) {
                  final m = _msgs[i];
                  if (m.system) {
                    return Center(child: Container(margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: D.panelHi, borderRadius: BorderRadius.circular(10)),
                        child: Text(m.text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: D.sub, fontStyle: FontStyle.italic))));
                  }
                  return Align(alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                        decoration: BoxDecoration(color: m.mine ? D.mine : D.panelHi, borderRadius: BorderRadius.circular(12)),
                        child: Text(m.text, style: const TextStyle(color: D.text, fontSize: 15, height: 1.35))));
                })),
        if (_busy) const Padding(padding: EdgeInsets.all(6), child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: D.accent))),
        SafeArea(child: Container(color: D.panel, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(children: [
            Expanded(child: TextField(controller: _ctrl, minLines: 1, maxLines: 4, style: const TextStyle(color: D.text),
                decoration: const InputDecoration(hintText: 'Tell your companion…', fillColor: D.panelHi))),
            const SizedBox(width: 6),
            InkWell(onTap: _send, child: const CircleAvatar(radius: 22, backgroundColor: D.accent, child: Icon(Icons.send, color: Colors.white, size: 20))),
          ]))),
      ]),
    );
  }
}

class _Msg {
  final String text;
  final bool mine;
  final bool system;
  _Msg(this.text, this.mine, {this.system = false});
}
