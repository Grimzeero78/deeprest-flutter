import 'dart:async';
import 'api.dart';

/// WhatsApp-style presence: while signed in, ping /api/presence every 60s
/// so other users see a green dot. Server marks "online" within a 2-min window.
class Heartbeat {
  static Timer? _timer;

  static void start() {
    stop();
    Api.heartbeat();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => Api.heartbeat());
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
