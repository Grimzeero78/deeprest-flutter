import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/models.dart';
import '../core/ui.dart';
import 'chat_screen.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});
  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  List<SosAlert> _sent = [];
  List<SosAlert> _received = [];
  bool _loading = true, _busy = false;
  final _msgCtrl = TextEditingController();
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
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final r = await Api.sosAll();
      if (!mounted) return;
      setState(() {
        _sent = ((r['sent'] as List?) ?? []).map((e) => SosAlert.fromJson(e as Map<String, dynamic>)).toList();
        _received = ((r['received'] as List?) ?? []).map((e) => SosAlert.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (_) {
      if (!silent && mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendSos() async {
    setState(() => _busy = true);
    try {
      await Api.sosSend(_msgCtrl.text.trim());
      _msgCtrl.clear();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SOS sent to your Duo partner'), backgroundColor: D.accent));
      }
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: D.sos));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _confirmSend() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: D.panel,
      title: const Text('Send distress call?'),
      content: const Text('Your Duo partner will be alerted immediately.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: D.sub))),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: D.sos), onPressed: () => Navigator.pop(context, true), child: const Text('Send SOS')),
      ],
    ));
    if (ok == true) await _sendSos();
  }

  Future<void> _ack(SosAlert a) async {
    setState(() => _busy = true);
    try {
      final r = await Api.sosAck(a.id);
      await _load();
      if (!mounted) return;
      final convoId = r['conversationId'] as String?;
      final reply = (r['reply'] ?? "I'm here for you. You're not alone.") as String;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sent: "$reply"'), backgroundColor: D.accent));
      if (convoId != null) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(convoId: convoId, title: 'Duo partner', isGroup: false)));
      }
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: D.sos));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: D.bg,
      appBar: AppBar(title: const Text('SOS', style: TextStyle(color: D.sos, fontWeight: FontWeight.bold))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: D.accent))
          : RefreshIndicator(
              color: D.accent,
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(18), physics: const AlwaysScrollableScrollPhysics(), children: [
                // Received — most urgent, on top
                if (_received.isNotEmpty) ...[
                  const Text('From your partner', style: TextStyle(color: D.sub, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._received.map(_receivedCard),
                  const SizedBox(height: 20),
                ],
                const Center(child: Text('NEED SUPPORT RIGHT NOW?', style: TextStyle(color: D.sub, fontSize: 12, letterSpacing: 1.5))),
                const SizedBox(height: 14),
                Center(child: InkResponse(
                  onTap: _busy ? null : _confirmSend,
                  child: Container(
                    width: 150, height: 150,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: D.sos, boxShadow: [BoxShadow(color: D.sos.withValues(alpha: .4), blurRadius: 30, spreadRadius: 4)]),
                    child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.sos, color: Colors.white, size: 46),
                      Text('SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    ]),
                  ),
                )),
                const SizedBox(height: 18),
                TextField(controller: _msgCtrl, maxLines: 2,
                    decoration: const InputDecoration(hintText: 'Optional message (e.g. "TikTok is pulling me back in")')),
                const SizedBox(height: 20),
                if (_sent.isNotEmpty) ...[
                  const Text('Your SOS history', style: TextStyle(color: D.sub, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._sent.map(_sentCard),
                ],
              ]),
            ),
    );
  }

  Widget _receivedCard(SosAlert a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: D.sos.withValues(alpha: .12), borderRadius: BorderRadius.circular(12), border: Border.all(color: D.sos.withValues(alpha: .5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('🚨 ${timeAgo(a.createdAt)}', style: const TextStyle(color: D.sos, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(a.message, style: const TextStyle(color: D.text)),
        const SizedBox(height: 10),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: D.accent, foregroundColor: Colors.white),
          icon: const Icon(Icons.volunteer_activism, size: 18),
          label: const Text("I'm here"),
          onPressed: _busy ? null : () => _ack(a),
        ),
      ]),
    );
  }

  Widget _sentCard(SosAlert a) {
    final acknowledged = a.reply != null && a.reply!.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: D.panel, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(acknowledged ? '✅ Answered' : '⏳ Sent ${timeAgo(a.createdAt)}', style: TextStyle(fontSize: 12, color: acknowledged ? D.accent : D.sub)),
        ]),
        const SizedBox(height: 4),
        Text(a.message, style: const TextStyle(color: D.text, fontSize: 13)),
        if (acknowledged) ...[
          const SizedBox(height: 6),
          Text('Partner: "${a.reply}"', style: const TextStyle(color: D.accent, fontSize: 13, fontStyle: FontStyle.italic)),
        ],
      ]),
    );
  }
}
