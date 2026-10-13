import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import 'users_repository.dart';

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final users = ref.watch(usersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.users)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/users/new'),
        icon: const Icon(Icons.person_add),
        label: Text(l10n.addUser),
      ),
      body: users.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorWithMessage('$e'))),
        data: (list) => list.isEmpty
            ? Center(child: Text(l10n.noUsers))
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final u = list[i];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(u.name.isEmpty ? '?' : u.name.characters.first),
                    ),
                    title: Text(u.name),
                    subtitle: Text('${u.role.label(l10n)} · ${u.email}'),
                    trailing: u.active
                        ? null
                        : Chip(label: Text(l10n.inactive)),
                    onTap: () => context.go('/users/${u.id}'),
                  );
                },
              ),
      ),
    );
  }
}
