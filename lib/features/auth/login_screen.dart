import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/branding.dart';
import '../../core/providers.dart';
import '../../widgets/async_body.dart';
import '../../widgets/brand_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _institutionName = TextEditingController();
  final _displayName = TextEditingController();
  var _busy = false;
  var _setup = false;

  @override
  void initState() {
    super.initState();
    _institutionName.text = BrandConfig.current.displayName;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _institutionName.dispose();
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
        await auth.bootstrapInstitution(
          institutionName: _institutionName.text.trim(),
          displayName: _displayName.text.trim().isEmpty
              ? _email.text.trim()
              : _displayName.text.trim(),
        );
      } else {
        final password = _password.text;
        final user = await auth.signIn(_email.text.trim(), password);
        final profile = await auth.watchProfile(user).first.timeout(
          const Duration(seconds: 8),
          onTimeout: () => null,
        );
        if (profile == null) {
          await auth.signOut();
          throw StateError(
            'This account is not enrolled in the institution. '
            'Ask your admin to create your user from Users.',
          );
        }
        if (!profile.requiresFirstLoginPasswordChange) {
          auth.clearTemporaryPasswordMemory();
        }
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = ref.watch(brandConfigProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: brand.backgroundProvider,
                fit: BoxFit.cover,
                onError: (error, stackTrace) {},
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.surface.withValues(alpha: 0.55),
                  scheme.surface.withValues(alpha: 0.92),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 24),
                    BrandLogo(height: 88, brand: brand),
                    const SizedBox(height: 16),
                    Text(
                      brand.displayName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      brand.tagline,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
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
                                controller: _institutionName,
                                decoration: const InputDecoration(labelText: 'Institution name'),
                              ),
                            ],
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: _busy ? null : () => _submit(register: _setup),
                              child: Text(_setup ? 'Create institution & admin' : 'Sign in'),
                            ),
                            TextButton(
                              onPressed: _busy ? null : () => setState(() => _setup = !_setup),
                              child: Text(_setup ? 'Have an account? Sign in' : 'First-time setup'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
