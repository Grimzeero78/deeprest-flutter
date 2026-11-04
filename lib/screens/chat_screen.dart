import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/api.dart';
import '../core/crypto.dart';
import '../core/models.dart';
import '../core/ui.dart';

class ChatScreen extends StatefulWidget {
  final String convoId, title;
  final Map<String, dynamic>? peerAvatar;
  final bool isGroup;
  const ChatScreen(
      {super.key,
      required this.convoId,
      required this.title,
      this.peerAvatar,
      required this.isGroup});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<ChatMessage> _msgs = [];
  String? _peerLastReadAt;
  DateTime? _peerLastSeen;
  bool _online = false;
  bool _sending = false, _loading = true;
  Timer? _poll;
  String? _peerPub; // peer's E2EE public key (self-heals from convo refresh)
  final Map<String, String> _decrypted = {}; // msgId -> plaintext (cache)
  final Set<String> _encryptedIds = {}; // msgs that arrived as envelopes

  @override
  void initState() {
    super.initState();
    _peerPub = widget.peerAvatar?['publicKey'] as String?;
    _load();
    _poll = Timer.periodic(
        const Duration(seconds: 3), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      // Presence + read receipts + self-heal the peer's E2EE public key
      // (covers entry points that can't pass it, like the SOS ack flow).
      final convos = await Api.conversations();
      for (final c in convos) {
        if ((c as Map<String, dynamic>)['id'] == widget.convoId) {
          _peerLastReadAt = c['peerLastReadAt'] as String?;
          _online = (c['online'] ?? false) as bool;
          final ls = c['lastSeenAt'] as String?;
          _peerLastSeen = ls == null ? null : DateTime.tryParse(ls);
          final pk =
              (c['peer'] as Map<String, dynamic>?)?['publicKey'] as String?;
          if (pk != null && pk.isNotEmpty && pk != _peerPub) {
            _peerPub = pk;
            _decrypted.clear(); // re-decrypt under the new key
          }
        }
      }
      final msgs = await Api.messages(widget.convoId);
      await Api.markRead(widget.convoId);
      final list = <ChatMessage>[];
      for (final e in msgs) {
        final m = Map<String, dynamic>.from(e as Map<String, dynamic>);
        final raw = (m['body'] ?? '') as String;
        final id = (m['id'] ?? '') as String;
        if (raw.startsWith('{"v":1,')) {
          _encryptedIds.add(id);
          final cached = _decrypted[id];
          if (cached != null) {
            m['body'] = cached;
          } else {
            final plain =
                await DeepKeys.decryptDm(widget.convoId, _peerPub, raw);
            _decrypted[id] = plain;
            m['body'] = plain;
          }
        } else {
          m['body'] = raw;
        }
        list.add(ChatMessage.fromJson(m));
      }
      if (!mounted) return;
      setState(() {
        _msgs = list;
        _loading = false;
      });
      _jumpBottom(animate: !silent);
    } catch (e) {
      if (!silent && mounted) setState(() => _loading = false);
    }
  }

  void _jumpBottom({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final pos = _scroll.position.maxScrollExtent;
      if (animate) {
        _scroll.animateTo(pos,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      } else if (_scroll.offset < pos - 80) {
        _scroll.jumpTo(pos);
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    _ctrl.clear();
    // Optimistic bubble — appears instantly, replaced by the real one when
    // the server echoes it back.
    setState(() {
      _sending = true;
      _msgs = [
        ..._msgs,
        ChatMessage(
            id: '_local${DateTime.now().microsecondsSinceEpoch}',
            body: text,
            kind: 'text',
            senderId: 'me',
            senderName: 'me',
            createdAt: DateTime.now().toIso8601String(),
            mine: true),
      ];
    });
    _jumpBottom(animate: true);
    try {
      final encBody = await DeepKeys.encryptDm(widget.convoId, _peerPub, text);
      await Api.sendMessage(widget.convoId, encBody);
      await _load(silent: true);
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: D.sos));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Message failed to send'),
            backgroundColor: D.sos));
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: D.bg,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          if (widget.isGroup)
            const CircleAvatar(
                radius: 18,
                backgroundColor: D.panelHi,
                child: Icon(Icons.group, size: 18))
          else
            Avatar(
                name: widget.peerAvatar?['name'] ?? widget.title,
                color: widget.peerAvatar?['color'],
                image: widget.peerAvatar?['image'],
                emoji: widget.peerAvatar?['emoji'],
                radius: 18,
                online: _online),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            Text(widget.title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: D.text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(_subtitle(),
                style: TextStyle(
                    fontSize: 11, color: _online ? D.teal : D.sub),
                maxLines: 1),
          ])),
        ]),
        actions: [
          if (!widget.isGroup)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.lock, size: 14, color: D.sub),
            ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: D.accent))
              : ListView.builder(
                  controller: _scroll,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  itemCount: _msgs.length,
                  itemBuilder: (ctx, i) => _bubble(i),
                ),
        ),
        _composer(),
      ]),
    );
  }

  String _subtitle() {
    if (widget.isGroup) {
      return '${_msgs.map((m) => m.senderId).toSet().length} members';
    }
    if (_online) return 'online';
    if (_peerLastSeen != null) {
      return 'last seen ${timeAgo(_peerLastSeen!.toIso8601String())}';
    }
    return 'offline';
  }

  Widget _bubble(int i) {
    final m = _msgs[i];
    if (m.kind == 'system') {
      return Center(
        child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
                color: D.panelHi, borderRadius: BorderRadius.circular(10)),
            child: Text(m.body,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 12, color: D.sub))),
      );
    }
    final showDate =
        i == 0 || !_sameDay(_msgs[i - 1].createdAt, m.createdAt);
    final prev = i > 0 ? _msgs[i - 1] : null;
    final showName = widget.isGroup &&
        !m.mine &&
        (prev == null || prev.senderId != m.senderId || prev.kind == 'system');
    final read = _peerLastReadAt != null &&
        DateTime.tryParse(_peerLastReadAt!) != null &&
        DateTime.tryParse(m.createdAt)!
            .isBefore(DateTime.parse(_peerLastReadAt!));
    final isEncrypted =
        _encryptedIds.contains(m.id) && !widget.isGroup;

    return Column(children: [
      if (showDate) _datePill(m.createdAt),
      Align(
        alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78),
          padding:
              const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: m.mine ? D.mine : D.panelHi,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(m.mine ? 18 : 4),
              bottomRight: Radius.circular(m.mine ? 4 : 18),
            ),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showName)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(m.senderName,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: D.tick))),
                Text(m.body,
                    style: const TextStyle(
                        color: D.text, fontSize: 15.5, height: 1.3)),
                const SizedBox(height: 2),
                Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isEncrypted) ...[
                        const Icon(Icons.lock, size: 9, color: D.sub),
                        const SizedBox(width: 3),
                      ],
                      Text(
                          DateFormat('HH:mm')
                              .format(DateTime.parse(m.createdAt)),
                          style: const TextStyle(
                              fontSize: 10, color: D.sub)),
                      if (m.mine) ...[
                        const SizedBox(width: 4),
                        Icon(read ? Icons.done_all : Icons.done,
                            size: 13, color: read ? D.tick : D.sub),
                      ],
                    ]),
              ]),
        ),
      ),
    ]);
  }

  bool _sameDay(String a, String b) {
    final da = DateTime.tryParse(a), db = DateTime.tryParse(b);
    if (da == null || db == null) return false;
    return da.year == db.year && da.month == db.month && da.day == db.day;
  }

  Widget _datePill(String iso) {
    final t = DateTime.parse(iso);
    final now = DateTime.now();
    String label;
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      label = 'TODAY';
    } else if (now.difference(t).inDays < 1 && now.day != t.day) {
      label = 'YESTERDAY';
    } else {
      label = DateFormat('d MMMM yyyy').format(t).toUpperCase();
    }
    return Center(
        child: Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
                color: D.panelHi, borderRadius: BorderRadius.circular(10)),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: D.sub,
                    fontWeight: FontWeight.w600))));
  }

  Widget _composer() {
    return SafeArea(
      child: Container(
        color: D.panel,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(children: [
          Expanded(
              child: TextField(
            controller: _ctrl,
            minLines: 1,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            style: const TextStyle(color: D.text),
            decoration: const InputDecoration(
                hintText: 'Message', fillColor: D.panelHi),
          )),
          const SizedBox(width: 6),
          InkWell(
            onTap: _send,
            child: const CircleAvatar(
                radius: 22,
                backgroundColor: D.accent,
                child: Icon(Icons.send, color: Colors.white, size: 20)),
          ),
        ]),
      ),
    );
  }
}
