import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../widgets/async_body.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _schoolName = TextEditingController(text: 'My School');
  final _displayName = TextEditingController();
  var _busy = false;
  var _setup = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _schoolName.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool register}) async {
    setState(() => _busy = true);
    final auth = ref.read(authRepositoryProvider);
    try {
      if (register) {
        try {
          await auth.register(_email.text.trim(), _password.text);
        } on FirebaseAuthException catch (error) {
          if (error.code != 'email-already-in-use') rethrow;
          await auth.signIn(_email.text.trim(), _password.text);
        }
        await auth.bootstrapSchool(
          schoolName: _schoolName.text.trim(),
          displayName: _displayName.text.trim().isEmpty
              ? _email.text.trim()
              : _displayName.text.trim(),
        );
      } else {
        await auth.signIn(_email.text.trim(), _password.text);
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 32),
                Text('Student App', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Text(
                  'Attendance, homework, timetable, marks, announcements, and PTM.',
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                if (_setup) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _displayName,
                    decoration: const InputDecoration(labelText: 'Your name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _schoolName,
                    decoration: const InputDecoration(labelText: 'School name'),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : () => _submit(register: _setup),
                  child: Text(_setup ? 'Create school & admin' : 'Sign in'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _setup = !_setup),
                  child: Text(_setup ? 'Have an account? Sign in' : 'First-time setup'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
