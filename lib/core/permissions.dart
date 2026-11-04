// ============================================================
// Device permissions bridge — talks to MainActivity over the
// "deeprest/device" MethodChannel:
//  • Usage access (PACKAGE_USAGE_STATS): needed for screen-time
//    tracking. It's a special permission granted in system
//    Settings, so we deep-link the user there and re-check when
//    they come back (dashboard listens to lifecycle resume).
//  • Notifications (POST_NOTIFICATIONS, Android 13+): asked once
//    on first launch, then never nagged again.
//  • usageToday(): today's screen time measured by UsageStatsManager.
// ============================================================
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TopAppEntry {
  final String name;
  final int minutes;
  TopAppEntry({required this.name, required this.minutes});
}

class UsageSnapshot {
  final bool granted;
  final int minutes;
  final List<TopAppEntry> topApps;
  UsageSnapshot({
    required this.granted,
    required this.minutes,
    required this.topApps,
  });
}

class DevicePermissions {
  static const _ch = MethodChannel('deeprest/device');
  static const _askedNotifKey = 'deeprest_notif_asked';

  static Future<bool> hasUsageAccess() async {
    try {
      return await _ch.invokeMethod<bool>('hasUsageAccess') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openUsageAccessSettings() async {
    try {
      await _ch.invokeMethod('openUsageAccessSettings');
    } catch (_) {}
  }

  /// Ask for POST_NOTIFICATIONS once (Android 13+). Returns granted status.
  static Future<bool> requestNotificationsOnce() async {
    final sp = await SharedPreferences.getInstance();
    try {
      if (sp.getBool(_askedNotifKey) ?? false) {
        return await _ch.invokeMethod<bool>('hasNotificationPermission') ??
            false;
      }
      final granted =
          await _ch.invokeMethod<bool>('requestNotifications') ?? false;
      await sp.setBool(_askedNotifKey, true);
      return granted;
    } on MissingPluginException {
      return true;
    }
  }

  static Future<UsageSnapshot?> usageToday() async {
    try {
      final m = await _ch.invokeMethod<Map<dynamic, dynamic>>('usageToday');
      if (m == null) return null;
      return UsageSnapshot(
        granted: m['granted'] == true,
        minutes: (m['minutes'] as num?)?.toInt() ?? 0,
        topApps: [
          for (final e in (m['topApps'] as List?) ?? [])
            if (e is Map)
              TopAppEntry(
                name: (e['name'] ?? 'App').toString(),
                minutes: (e['minutes'] as num?)?.toInt() ?? 0,
              ),
        ],
      );
    } catch (_) {
      return null;
    }
  }
}
