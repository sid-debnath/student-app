import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../widgets/async_body.dart';

class AccountDetailsScreen extends ConsumerWidget {
  const AccountDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account Details')),
      body: AsyncBody(
        value: ref.watch(sessionProvider),
        builder: (user) {
          if (user == null) {
            return const Center(child: Text('Loading profile…'));
          }
          final theme = Theme.of(context);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  user.displayName.isEmpty ? user.email : user.displayName,
                ),
                subtitle: Text(user.email),
              ),
              const Divider(),
              Text('Phone numbers', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (user.fatherPhone.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.phone_outlined),
                  title: const Text('Father Phone'),
                  subtitle: Text(user.fatherPhone),
                ),
              if (user.motherPhone.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.phone_outlined),
                  title: const Text('Mother Phone'),
                  subtitle: Text(user.motherPhone),
                ),
              if (user.alternativePhone.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.phone_outlined),
                  title: const Text('Alternative Phone'),
                  subtitle: Text(user.alternativePhone),
                ),
              if (!user.hasParentPhones)
                Text(
                  'No phone numbers on this account.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
