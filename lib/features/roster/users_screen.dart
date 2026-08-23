import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/app_user.dart';
import '../../widgets/async_body.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _linkIds = TextEditingController();
  var _role = UserRole.teacher;
  var _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _linkIds.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    final ids = _linkIds.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    try {
      await ref.read(authRepositoryProvider).createInstitutionUser(
        email: _email.text.trim(),
        password: _password.text,
        displayName: _name.text.trim(),
        role: _role,
        classIds: _role == UserRole.teacher ? ids : const [],
        studentIds: _role == UserRole.viewer ? ids : const [],
      );
      if (!mounted) return;
      _email.clear();
      _password.clear();
      _name.clear();
      _linkIds.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User created')),
      );
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roster = ref.watch(rosterRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Display name')),
          const SizedBox(height: 8),
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 8),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Temporary password'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<UserRole>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Role'),
            items: const [
              DropdownMenuItem(value: UserRole.teacher, child: Text('Teacher')),
              DropdownMenuItem(value: UserRole.viewer, child: Text('Parent / student')),
              DropdownMenuItem(value: UserRole.admin, child: Text('Admin')),
            ],
            onChanged: (value) => setState(() => _role = value ?? UserRole.teacher),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _linkIds,
            decoration: InputDecoration(
              labelText: _role == UserRole.teacher
                  ? 'Class IDs (comma-separated)'
                  : 'Student IDs (comma-separated)',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _create, child: const Text('Create account')),
          const SizedBox(height: 24),
          Text('Existing users', style: Theme.of(context).textTheme.titleMedium),
          if (roster == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )
          else
            StreamBuilder(
              stream: roster.watchUsers(),
              builder: (context, snapshot) {
                final users = snapshot.data ?? [];
                return Column(
                  children: [
                    for (final user in users)
                      ListTile(
                        title: Text(user.displayName.isEmpty ? user.email : user.displayName),
                        subtitle: Text('${user.role.name} · ${user.email}'),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
