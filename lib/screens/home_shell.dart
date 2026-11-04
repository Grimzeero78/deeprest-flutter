import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/models.dart';
import '../core/permissions.dart';
import '../core/ui.dart';
import 'chats_screen.dart';
import 'community_screen.dart';
import 'duo_screen.dart';
import 'leaderboard_screen.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'sos_screen.dart';

class HomeShell extends StatefulWidget {
  final VoidCallback onLogout;
  const HomeShell({super.key, required this.onLogout});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  Me? _me;
  Timer? _poll;
  Map<String, dynamic>? _incomingCall; // ringing call for me
  Map<String, dynamic>? _activeCall; // my outgoing/ongoing call

  @override
  void initState() {
    super.initState();
    _loadMe();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _pollCall());
    // Android 13+: ask for the notification permission once, on first launch.
    unawaited(
      DevicePermissions.requestNotificationsOnce().catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        debugPrint('Notification permission request failed: $error');
        return false;
      }),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _loadMe() async {
    try {
      final r = await Api.me();
      if (mounted) setState(() => _me = Me.fromJson(r));
    } catch (_) {}
  }

  Future<void> _pollCall() async {
    try {
      final r = await Api.callState();
      final call = r['call'] as Map<String, dynamic>?;
      if (!mounted) return;
      final meId = _me?.id;
      if (call == null) {
        if (_incomingCall != null || _activeCall != null) {
          setState(() {
            _incomingCall = null;
            _activeCall = null;
          });
        }
        return;
      }
      final status = (call['status'] ?? '') as String;
      final calleeId = (call['calleeId'] ?? '') as String;
      final callerId = (call['callerId'] ?? '') as String;
      if (status == 'RINGING' && meId != null && calleeId == meId) {
        setState(() {
          _incomingCall = call;
          _activeCall = null;
        });
      } else if ((status == 'RINGING' || status == 'ACTIVE') &&
          meId != null &&
          callerId == meId) {
        setState(() {
          _activeCall = call;
          _incomingCall = null;
        });
      } else {
        setState(() {
          _incomingCall = null;
          _activeCall = null;
        });
      }
    } catch (_) {}
  }

  void _refreshMe() => _loadMe();

  @override
  Widget build(BuildContext context) {
    final pages = [
      ChatsScreen(onOpenSos: () => _openSos()),
      CommunityScreen(me: _me),
      DuoScreen(me: _me),
      LeaderboardScreen(me: _me),
      DashboardScreen(me: _me, onChanged: _refreshMe),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titleFor(_tab),
          style: const TextStyle(fontWeight: FontWeight.bold, color: D.text),
        ),
        actions: [
          IconButton(
            tooltip: 'SOS',
            icon: const Icon(Icons.sos, color: D.sos),
            onPressed: _openSos,
          ),
          IconButton(
            tooltip: 'Profile',
            icon: Avatar(name: _me?.name ?? '', color: null, radius: 15),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(me: _me, onChanged: _refreshMe),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(index: _tab, children: pages),
          if (_incomingCall != null) _callOverlay(incoming: true),
          if (_activeCall != null) _callOverlay(incoming: false),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: D.panel,
        indicatorColor: D.panelHi,
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline, color: D.sub),
            selectedIcon: Icon(Icons.chat_bubble, color: D.accent),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined, color: D.sub),
            selectedIcon: Icon(Icons.group, color: D.accent),
            label: 'Community',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline, color: D.sub),
            selectedIcon: Icon(Icons.favorite, color: D.accent),
            label: 'Duo',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined, color: D.sub),
            selectedIcon: Icon(Icons.emoji_events, color: D.accent),
            label: 'Ranks',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined, color: D.sub),
            selectedIcon: Icon(Icons.insights, color: D.accent),
            label: 'Dashboard',
          ),
        ],
      ),
    );
  }

  String _titleFor(int t) => const [
    'DeepRest',
    'Community',
    'Dynamic Duo',
    'Rankings',
    'Dashboard',
  ][t];

  Future<void> _openSos() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SosScreen()),
    );
  }

  Widget _callOverlay({required bool incoming}) {
    final call = incoming ? _incomingCall! : _activeCall!;
    final name =
        (call['callerName'] ?? call['calleeName'] ?? 'Partner') as String;
    final status = (call['status'] ?? '') as String;
    final callId = (call['id'] ?? '') as String;
    return Container(
      color: Colors.black87,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Avatar(name: name, radius: 44),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            incoming
                ? 'Incoming call…'
                : (status == 'ACTIVE' ? 'Connected' : 'Ringing…'),
            style: const TextStyle(color: D.sub),
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (incoming) ...[
                _callBtn(Icons.call_end, D.sos, 'Decline', () async {
                  await Api.callAction(callId, 'decline');
                  setState(() => _incomingCall = null);
                }),
                const SizedBox(width: 40),
                _callBtn(Icons.call, D.accent, 'Answer', () async {
                  await Api.callAction(callId, 'answer');
                }),
              ] else ...[
                _callBtn(Icons.call_end, D.sos, 'End', () async {
                  await Api.callAction(callId, 'end');
                  setState(() => _activeCall = null);
                }),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _callBtn(
    IconData icon,
    Color color,
    String label,
    VoidCallback onTap,
  ) {
    return Column(
      children: [
        InkResponse(
          onTap: onTap,
          child: CircleAvatar(
            radius: 30,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: D.sub, fontSize: 12)),
      ],
    );
  }
}
