import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api.dart';
import 'core/crypto.dart';
import 'core/heartbeat.dart';
import 'core/ui.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.init();
  await DeepKeys.restore();
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
        colorScheme: const ColorScheme.dark(
            primary: D.accent, secondary: D.teal, surface: D.panel),
        appBarTheme: const AppBarTheme(
            backgroundColor: D.bg, foregroundColor: D.text, elevation: 0),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: D.panelHi,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
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
  // Instant paint: if we have a token AND a cached profile, show the app
  // shell straight away and refresh in the background — no waiting spinner.
  bool _checking = true;
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    if (Api.token != null) {
      final cached = await Api.cachedMe();
      if (cached != null) {
        // Paint immediately from the device cache…
        _signedIn = true;
        Heartbeat.start();
        if (mounted) {
          setState(() => _checking = false);
          _refreshInBackground();
        }
        return;
      }
      // …otherwise verify the token (first launch after sign-in).
      try {
        await Api.me();
        _signedIn = true;
        Heartbeat.start();
      } on ApiError catch (e) {
        if (e.status == 401) await Api.clearSession();
      } catch (_) {}
    }
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _refreshInBackground() async {
    try {
      await Api.me();
      // Re-register our E2EE public key if the server lost it (e.g. this
      // session predates the feature) — idempotent.
      if (DeepKeys.ready && DeepKeys.publicKeyB64 != null) {
        await Api.patch('/api/profile', {'publicKey': DeepKeys.publicKeyB64});
      }
    } catch (_) {}
  }

  void _onSignedIn() {
    Heartbeat.start();
    setState(() => _signedIn = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(
        backgroundColor: D.bg,
        body: const Center(child: CircularProgressIndicator(color: D.accent)),
      );
    }
    return _signedIn
        ? _HomeWithOnboarding(onLogout: _onLogout)
        : AuthScreen(onSignedIn: _onSignedIn);
  }

  Future<void> _onLogout() async {
    Heartbeat.stop();
    await Api.logout();
    await DeepKeys.clear();
    if (mounted) setState(() => _signedIn = false);
  }
}

/// Shows the first-run walkthrough once, then hands over to the app.
class _HomeWithOnboarding extends StatefulWidget {
  final VoidCallback onLogout;
  const _HomeWithOnboarding({required this.onLogout});
  @override
  State<_HomeWithOnboarding> createState() => _HomeWithOnboardingState();
}

class _HomeWithOnboardingState extends State<_HomeWithOnboarding> {
  bool _loading = true;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final sp = await SharedPreferences.getInstance();
    final done = sp.getBool('deeprest_onboarded') ?? false;
    if (mounted) {
      setState(() {
        _showOnboarding = !done;
        _loading = false;
      });
    }
  }

  Future<void> _finishOnboarding() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('deeprest_onboarded', true);
    if (mounted) setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          backgroundColor: D.bg,
          body: Center(child: CircularProgressIndicator(color: D.accent)));
    }
    return Stack(children: [
      HomeShell(onLogout: widget.onLogout),
      if (_showOnboarding) OnboardingScreen(onDone: _finishOnboarding),
    ]);
  }
}
