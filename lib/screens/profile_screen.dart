import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/models.dart';
import '../core/ui.dart';

const _colors = ['#8b5cf6', '#00a884', '#f59e0b', '#ef4444', '#3b82f6', '#ec4899', '#14b8a6', '#eab308'];

class ProfileScreen extends StatefulWidget {
  final Me? me;
  final VoidCallback onChanged;
  const ProfileScreen({super.key, this.me, required this.onChanged});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _name, _bio, _emoji;
  String _color = '#8b5cf6';
  bool _busy = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.me?.name ?? '');
    _bio = TextEditingController();
    _emoji = TextEditingController();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final r = await Api.get('/api/auth/me');
      final user = (r['user'] ?? {}) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _name.text = (user['name'] ?? _name.text) as String;
        _bio.text = (user['bio'] ?? '') as String;
        _emoji.text = (user['avatarEmoji'] ?? '') as String;
        _color = (user['avatarColor'] ?? _color) as String;
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    setState(() { _busy = true; _msg = null; });
    try {
      final data = <String, dynamic>{
        'name': _name.text.trim(),
        'bio': _bio.text.trim(),
        'avatarColor': _color,
        'avatarEmoji': _emoji.text.trim(),
      };
      await Api.updateProfile(data);
      widget.onChanged();
      setState(() => _msg = 'Profile saved ✅');
    } on ApiError catch (e) {
      setState(() => _msg = e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _changePassword() async {
    final cur = TextEditingController(), next = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: D.panel,
      title: const Text('Change password'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: cur, obscureText: true, decoration: const InputDecoration(hintText: 'Current password')),
        const SizedBox(height: 10),
        TextField(controller: next, obscureText: true, decoration: const InputDecoration(hintText: 'New password (8–200 chars)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: D.sub))),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: D.accent), onPressed: () => Navigator.pop(context, true), child: const Text('Change')),
      ],
    ));
    if (ok == true) {
      try {
        await Api.changePassword(cur.text, next.text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed ✅'), backgroundColor: D.accent));
        }
      } on ApiError catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: D.sos));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    return Scaffold(
      backgroundColor: D.bg,
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Center(child: Avatar(name: _name.text.isEmpty ? '?' : _name.text, color: _color, emoji: _emoji.text.isEmpty ? null : _emoji.text, radius: 44)),
        const SizedBox(height: 18),
        TextField(controller: _name, decoration: const InputDecoration(hintText: 'Display name')),
        const SizedBox(height: 10),
        TextField(controller: _bio, maxLines: 2, decoration: const InputDecoration(hintText: 'About (status line)')),
        const SizedBox(height: 10),
        TextField(controller: _emoji, maxLength: 2, decoration: const InputDecoration(hintText: 'Avatar emoji (e.g. 🌙)', counterText: '')),
        const SizedBox(height: 14),
        const Text('Avatar colour', style: TextStyle(color: D.sub, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(spacing: 10, children: _colors.map((c) => GestureDetector(
          onTap: () => setState(() => _color = c),
          child: CircleAvatar(radius: 16, backgroundColor: Color(0xFF000000 | int.parse(c.substring(1), radix: 16)),
            child: _color == c ? const Icon(Icons.check, size: 16, color: Colors.white) : null),
        )).toList()),
        const SizedBox(height: 20),
        if (_msg != null) Center(child: Text(_msg!, style: const TextStyle(color: D.accent))),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: D.accent, padding: const EdgeInsets.symmetric(vertical: 13)),
            onPressed: _busy ? null : _save, child: const Text('Save profile')),
        const SizedBox(height: 10),
        OutlinedButton.icon(icon: const Icon(Icons.lock_outline, size: 18), label: const Text('Change password'), onPressed: _changePassword),
        const SizedBox(height: 10),
        OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: D.sos, side: const BorderSide(color: D.sos)),
            icon: const Icon(Icons.logout, size: 18), label: const Text('Log out'),
            onPressed: () async {
              await Api.logout();
              if (context.mounted) {
                Navigator.of(context).popUntil((r) => r.isFirst);
                widget.onChanged();
              }
            }),
        const SizedBox(height: 24),
        Center(child: Text('DeepRest mobile 1.0 · ${me?.username ?? ''} @ ${me?.rankName ?? ''} Lv.${me?.rankLevel ?? 1}',
            style: const TextStyle(fontSize: 11, color: D.sub))),
      ]),
    );
  }
}
