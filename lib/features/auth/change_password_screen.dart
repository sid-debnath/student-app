import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/auth_repository.dart';
import '../../widgets/async_body.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _temporaryPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  var _busy = false;
  var _alertShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending =
          ref.read(authRepositoryProvider).pendingTemporaryPassword;
      if (pending != null && pending.isNotEmpty) {
        _temporaryPassword.text = pending;
      }
      _showSecurityAlert();
    });
  }

  @override
  void dispose() {
    _temporaryPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _showSecurityAlert() async {
    if (!mounted || _alertShown) return;
    _alertShown = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.lock_outline),
        title: const Text('Change your password'),
        content: const Text(
          'For security, you must replace the temporary password given by '
          'your admin before you can use the app. The new password must be '
          'different from the temporary one.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final temporary = _temporaryPassword.text;
    final next = _newPassword.text;
    final confirm = _confirmPassword.text;
    final auth = ref.read(authRepositoryProvider);
    if (temporary.isEmpty || next.isEmpty || confirm.isEmpty) {
      showError(context, 'Fill in all password fields.');
      return;
    }
    if (next.length < 6) {
      showError(context, 'New password must be at least 6 characters.');
      return;
    }
    if (next != confirm) {
      showError(context, 'New password and confirmation do not match.');
      return;
    }
    try {
      AuthRepository.validateFirstLoginNewPassword(
        newPassword: next,
        temporaryPassword: temporary,
      );
    } catch (error) {
      showError(context, error);
      return;
    }

    setState(() => _busy = true);
    try {
      await auth.changePassword(
        newPassword: next,
        currentPassword: temporary,
      );
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Change password'),
          automaticallyImplyLeading: false,
          actions: [
            TextButton(
              onPressed: _busy
                  ? null
                  : () => ref.read(authRepositoryProvider).signOut(),
              child: const Text('Sign out'),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AutofillGroup(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Icon(Icons.security, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Set a private password',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter the temporary password from your admin, then choose '
                    'a different new password.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _temporaryPassword,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(
                      labelText: 'Temporary password',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newPassword,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: const InputDecoration(
                      labelText: 'New password',
                      helperText:
                          'Must be different from the temporary password.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmPassword,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    onSubmitted: (_) => _busy ? null : _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Confirm new password',
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: const Text('Save new password'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
