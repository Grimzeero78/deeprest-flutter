import 'package:flutter/material.dart';
import '../core/api.dart';
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
    setState(() { _busy = true; _error = null; });
    try {
      if (_isRegister) {
        await Api.register(_name.text.trim(), _pass.text, _pass2.text, _hint.text.trim());
      } else {
        await Api.login(_name.text.trim(), _pass.text);
      }
      if (!mounted) return;
      widget.onSignedIn();
    } on ApiError catch (e) {
      setState(() { _error = e.message; _busy = false; });
    } catch (e) {
      setState(() { _error = 'Something went wrong. Try again.'; _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.nightlight_round, color: D.accent, size: 64),
                const SizedBox(height: 12),
                const Text('DeepRest', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: D.text)),
                const Text('Rest deeply. Live fully.', textAlign: TextAlign.center,
                    style: TextStyle(color: D.sub)),
                const SizedBox(height: 36),
                TextField(controller: _name,
                    decoration: const InputDecoration(hintText: 'Your name')),
                const SizedBox(height: 12),
                TextField(controller: _pass, obscureText: _obscure,
                    decoration: InputDecoration(
                        hintText: 'Password',
                        suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: D.sub),
                            onPressed: () => setState(() => _obscure = !_obscure)))),
                if (_isRegister) ...[
                  const SizedBox(height: 12),
                  TextField(controller: _pass2, obscureText: true,
                      decoration: const InputDecoration(hintText: 'Confirm password')),
                  const SizedBox(height: 12),
                  TextField(controller: _hint,
                      decoration: const InputDecoration(hintText: 'Password hint (optional)')),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: const TextStyle(color: D.sos), textAlign: TextAlign.center),
                ],
                const SizedBox(height: 22),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: D.accent, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _busy ? null : _go,
                  child: _busy
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_isRegister ? 'Create account' : 'Sign in',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() { _isRegister = !_isRegister; _error = null; }),
                  child: Text(_isRegister ? 'Already have an account? Sign in' : 'New here? Create an account',
                      style: const TextStyle(color: D.accent)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
