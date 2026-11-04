import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api.dart';
import '../core/models.dart';
import '../core/permissions.dart';
import '../core/ui.dart';

class DashboardScreen extends StatefulWidget {
  final Me? me;
  final VoidCallback onChanged;
  const DashboardScreen({super.key, this.me, required this.onChanged});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  bool? _usageGranted; // null = still checking
  bool _syncing = false;
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDevice(askIfMissing: true);
    _reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // When the user returns from the Usage-access Settings screen, re-check
  // and (if now granted) immediately measure + sync today's usage.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _initDevice();
  }

  Future<void> _initDevice({bool askIfMissing = false}) async {
    final granted = await DevicePermissions.hasUsageAccess();
    if (!mounted) return;
    setState(() => _usageGranted = granted);
    if (granted) {
      final ok = await _syncFromDevice();
      if (ok && mounted) _reload();
    } else if (askIfMissing && !_dialogShown) {
      _dialogShown = true;
      _showUsagePermissionDialog();
    }
  }

  /// Android-style runtime permission dialog. Usage access is a "special"
  /// permission Android only grants from system Settings — every screen-time
  /// app works this way — so "Allow" deep-links there and we re-check on return.
  Future<void> _showUsagePermissionDialog() async {
    final sp = await SharedPreferences.getInstance();
    if (sp.getBool('deeprest_usage_declined') ?? false) return;
    if (!mounted) return;
    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: D.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Allow DeepRest to access app usage data?',
            style: TextStyle(fontSize: 19, height: 1.3)),
        content: const Text(
            'DeepRest will measure how long apps are used on this phone to build your screen-time dashboard, streak and rank. Nothing inside your apps is ever read or shared.',
            style: TextStyle(fontSize: 14, height: 1.4, color: D.sub)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Don\'t allow')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Allow',
                  style: TextStyle(color: D.accent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (allow == true) {
      await DevicePermissions.openUsageAccessSettings();
    } else {
      await sp.setBool('deeprest_usage_declined', true);
    }
  }

  /// Measure today's screen time on this phone and push it to the backend.
  Future<bool> _syncFromDevice() async {
    if (_syncing) return false;
    _syncing = true;
    try {
      final snap = await DevicePermissions.usageToday();
      if (snap == null || !snap.granted) return false;
      await Api.syncScreentime(
          snap.minutes,
          [for (final a in snap.topApps) {'name': a.name, 'minutes': a.minutes}]);
      return true;
    } catch (_) {
      return false;
    } finally {
      _syncing = false;
    }
  }

  Future<void> _reload() async {
    if (_usageGranted ?? false) await _syncFromDevice();
    try {
      await Api.me();
      if (mounted) setState(() { /* me is rebuilt by parent */ });
      widget.onChanged();
    } catch (_) {}
  }

  Future<void> _editTarget() async {
    final ctrl = TextEditingController(text: '${(widget.me?.dailyTargetMin ?? 360) ~/ 60}');
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: D.panel,
      title: const Text('Daily target (hours)'),
      content: TextField(controller: ctrl, keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'e.g. 6 (1–16)')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: D.sub))),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: D.accent), onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
      ],
    ));
    if (ok == true) {
      final hours = int.tryParse(ctrl.text.trim());
      if (hours != null && hours >= 1 && hours <= 16) {
        try {
          await Api.setTarget(hours * 60);
          widget.onChanged();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Target set: $hours h/day'), backgroundColor: D.accent));
          }
        } on ApiError catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: D.sos));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    if (me == null) return const Center(child: CircularProgressIndicator(color: D.accent));

    return Scaffold(
      backgroundColor: D.bg,
      body: RefreshIndicator(
        color: D.accent,
        onRefresh: _reload,
        child: ListView(padding: const EdgeInsets.all(18), physics: const AlwaysScrollableScrollPhysics(), children: [
          Center(child: Ring(percent: me.progressPercent.clamp(0, 100) / 100,
              label: '${me.rankName}\nLv.${me.rankLevel}')),
          const SizedBox(height: 10),
          Center(child: Text(me.nextRankName == null ? 'Top rank reached! 🏆' : '${me.nextRankName} at ${me.nextRankMinXp} XP',
              style: const TextStyle(color: D.sub, fontSize: 12))),
          const SizedBox(height: 22),

          // Usage card — phone-synced only
          Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: D.panel, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Today\'s usage', style: TextStyle(fontWeight: FontWeight.bold)),
                GestureDetector(onTap: _editTarget, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: D.panelHi, borderRadius: BorderRadius.circular(8)),
                    child: Text('target ${me.dailyTargetMin ~/ 60}h ⚙', style: const TextStyle(fontSize: 12, color: D.sub)))),
              ]),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _stat('${me.minutesUsed}', 'min used'),
                _stat('${me.dailyTargetMin}', 'min target'),
                _stat(me.metTarget ? '✅' : '⚠️', me.metTarget ? 'met target' : 'over target'),
              ]),
              const SizedBox(height: 14),
              if (_usageGranted == false)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [
                    const Icon(Icons.lock_outline, size: 13, color: D.sub),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text('Usage access is off — screen time isn’t being measured.',
                            style: const TextStyle(fontSize: 11, color: D.sub))),
                    GestureDetector(
                        onTap: () => _initDevice(askIfMissing: true),
                        child: const Text('Turn on',
                            style: TextStyle(
                                fontSize: 12,
                                color: D.accent,
                                fontWeight: FontWeight.bold))),
                  ]),
                ),
              if (me.topApps.isNotEmpty) ...[
                const Align(alignment: Alignment.centerLeft, child: Text('Top apps', style: TextStyle(color: D.sub, fontSize: 12))),
                const SizedBox(height: 6),
                ...me.topApps.take(5).map((a) => Padding(padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(child: Text(a.name, style: const TextStyle(fontSize: 13))),
                    SizedBox(width: 120, child: ClipRRect(borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: _frac(a.minutes, me.topApps), minHeight: 6, backgroundColor: D.panelHi, color: D.accent))),
                    SizedBox(width: 54, child: Text('${a.minutes}m', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: D.sub))),
                  ]))),
              ],
            ]),
          ),
          const SizedBox(height: 16),

          // Streak + XP
          Row(children: [
            Expanded(child: _miniCard('🔥', '${me.streak}', 'day streak')),
            const SizedBox(width: 12),
            Expanded(child: _miniCard('⭐', '${me.totalPoints}', 'XP total')),
          ]),
          const SizedBox(height: 16),

          // History (last 7 entries)
          if (me.history.isNotEmpty) ...[
            const Text('Last 7 days', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: D.panel, borderRadius: BorderRadius.circular(14)),
              child: Column(children: me.history.take(7).map((h) => Padding(padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(width: 64, child: Text(h.date.substring(5), style: const TextStyle(fontSize: 12, color: D.sub))),
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: (h.targetMin == 0 ? 0.0 : (h.minutesUsed / h.targetMin)).clamp(0.0, 1.0).toDouble(),
                          minHeight: 8, backgroundColor: D.panelHi, color: h.metTarget ? D.accent : D.sos))),
                  SizedBox(width: 58, child: Text('${h.minutesUsed}m', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: h.metTarget ? D.accent : D.sos))),
                ]))).toList()),
            ),
          ],
        ]),
      ),
    );
  }

  double _frac(int minutes, List<TopApp> apps) {
    final max = apps.map((a) => a.minutes).fold<int>(1, (a, b) => b > a ? b : a);
    return (minutes / max).clamp(0.05, 1.0);
  }

  Widget _stat(String v, String l) => Column(children: [
    Text(v, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: D.text)),
    Text(l, style: const TextStyle(fontSize: 11, color: D.sub)),
  ]);

  Widget _miniCard(String emoji, String v, String l) => Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: D.panel, borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(l, style: const TextStyle(fontSize: 11, color: D.sub)),
      ]));
}

class Ring extends StatelessWidget {
  final double percent;
  final String label;
  const Ring({super.key, required this.percent, required this.label});
  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 130, height: 130,
      child: CustomPaint(painter: _RingPainter(percent), child: Center(child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.3)))));
  }
}

class _RingPainter extends CustomPainter {
  final double percent;
  _RingPainter(this.percent);
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final bg = Paint()..style = PaintingStyle.stroke..strokeWidth = 9..color = D.panelHi;
    final fg = Paint()..style = PaintingStyle.stroke..strokeWidth = 9..strokeCap = StrokeCap.round..color = D.accent;
    canvas.drawCircle(c, radius, bg);
    canvas.drawArc(Rect.fromCircle(center: c, radius: radius), -3.14159 / 2, 6.28319 * percent, false, fg);
  }
  @override
  bool shouldRepaint(_RingPainter old) => old.percent != percent;
}
