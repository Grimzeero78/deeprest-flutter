import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/crypto.dart';
import '../core/ui.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onSignedIn;
  const AuthScreen({super.key, required this.onSignedIn});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _name = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  final _hint = TextEditingController();
  bool _isRegister = false, _busy = false, _obscure = true;
  String? _error;

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final name = _name.text.trim();
      if (name.length >= 2 && _pass.text.length >= 8) {
        // E2EE identity is derived from these credentials BEFORE the request —
        // the private seed never leaves this device; only the public key does.
        await DeepKeys.initFromPassword(name, _pass.text);
      }
      if (_isRegister) {
        await Api.register(
            name, _pass.text, _pass2.text, _hint.text.trim(),
            publicKey: DeepKeys.publicKeyB64);
      } else {
        await Api.login(name, _pass.text, publicKey: DeepKeys.publicKeyB64);
      }
      if (!mounted) return;
      widget.onSignedIn();
    } on ApiError catch (e) {
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Something went wrong. Try again.';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: D.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          D.accent.withValues(alpha: .45),
                          D.teal.withValues(alpha: .15)
                        ]),
                  ),
                  child: const Icon(Icons.nightlight_round,
                      color: D.text, size: 40),
                ),
                const SizedBox(height: 14),
                const Text('DeepRest',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: D.text)),
                const Text('Rest deeply. Live fully.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: D.sub)),
                const SizedBox(height: 30),
                // Prominent mode switch — sign-in is never hidden.
                SegmentedButton<bool>(
                  style: SegmentedButton.styleFrom(
                    backgroundColor: D.panel,
                    foregroundColor: D.sub,
                    selectedForegroundColor: Colors.white,
                    selectedBackgroundColor: D.accent,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  segments: const [
                    ButtonSegment(
                        value: false,
                        label: Text('Sign in',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        icon: Icon(Icons.login, size: 18)),
                    ButtonSegment(
                        value: true,
                        label: Text('Create account',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        icon: Icon(Icons.person_add_alt, size: 18)),
                  ],
                  selected: {_isRegister},
                  onSelectionChanged: (s) =>
                      setState(() {
                        _isRegister = s.first;
                        _error = null;
                      }),
                ),
                const SizedBox(height: 20),
                TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                        hintText: _isRegister
                            ? 'Choose your name'
                            : 'Your name')),
                const SizedBox(height: 12),
                TextField(
                    controller: _pass,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                        hintText: 'Password',
                        suffixIcon: IconButton(
                            icon: Icon(
                                _obscure
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: D.sub),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure)))),
                if (_isRegister) ...[
                  const SizedBox(height: 12),
                  TextField(
                      controller: _pass2,
                      obscureText: true,
                      decoration: const InputDecoration(
                          hintText: 'Confirm password')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _hint,
                      decoration: const InputDecoration(
                          hintText: 'Password hint (optional)')),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!,
                      style: const TextStyle(color: D.sos),
                      textAlign: TextAlign.center),
                ],
                const SizedBox(height: 22),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: D.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: _busy ? null : _go,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(_isRegister ? 'Create account' : 'Sign in',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 14),
                Text(_isRegister
                        ? 'Your DMs are end-to-end encrypted with a key derived from your password.'
                        : 'Welcome back — your encrypted chats unlock with your password.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: D.sub)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
