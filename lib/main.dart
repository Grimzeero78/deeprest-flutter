import 'package:flutter/material.dart';
import 'core/api.dart';
import 'core/heartbeat.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'core/ui.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.init();
  runApp(const DeepRestApp());
}

class DeepRestApp extends StatelessWidget {
  const DeepRestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeepRest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: D.bg,
        colorScheme: const ColorScheme.dark(primary: D.accent, secondary: D.tick, surface: D.panel),
        appBarTheme: const AppBarTheme(backgroundColor: D.panel, foregroundColor: D.text, elevation: 0),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: D.panelHi,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          hintStyle: const TextStyle(color: D.sub),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    if (Api.token != null) {
      try {
        await Api.me();
        _signedIn = true;
        Heartbeat.start();
      } on ApiError catch (e) {
        if (e.status == 401) await Api.clearSession();
      } catch (_) {}
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: D.accent)));
    }
    return _signedIn
        ? HomeShell(onLogout: _onLogout)
        : AuthScreen(onSignedIn: () {
            Heartbeat.start();
            setState(() => _signedIn = true);
          });
  }

  Future<void> _onLogout() async {
    Heartbeat.stop();
    await Api.logout();
    if (mounted) setState(() => _signedIn = false);
  }
}
