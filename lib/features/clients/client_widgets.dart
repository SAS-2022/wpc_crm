import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../plan/plan_repository.dart';
import '../plan/plan_task.dart';
import '../users/users_repository.dart';
import 'client.dart';
import 'clients_repository.dart';
import 'person_style.dart';
import 'visit_rules.dart';

/// Status colour from the client's category and last visit; grey = no location.
/// Closed / not working clients are dark grey (shown only when the status
/// filter asks for them).
Color clientColor(Client c, VisitRules rules, DateTime now) => !c.isActive
    ? Colors.blueGrey.shade700
    : c.hasLocation
        ? visitStatusColor(visitStatus(c, rules, now))
        : Colors.grey;

/// Clients on today's plan (approved visit tasks not yet done) → plan owner.
final plannedTodayProvider = Provider<Map<String, String>>((ref) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return const {};
  final today = dayKey(DateTime.now());
  final tasks = me.role.isSupervisor
      ? ref.watch(teamDayTasksProvider(today)).value
      : ref.watch(dayTasksProvider((me.id, today))).value;
  return {
    for (final t in tasks ?? const <PlanTask>[])
      if (t.isVisit && t.approval == TaskApproval.approved && !t.done) t.clientId!: t.ownerId,
  };
});

/// People the client list and map can be filtered by: every active sales
/// executive and KAM (KAMs may hold Odoo clients), plus anyone else who has
/// clients assigned.
final clientOwnersProvider = Provider<List<AppUser>>((ref) {
  final users = ref.watch(usersProvider).value ?? const [];
  final owners = {for (final c in ref.watch(allClientsProvider).value ?? const <Client>[]) c.assignedTo};
  return users.where((u) => (u.active && u.role.isTracked) || owners.contains(u.id)).toList();
});

/// Salesperson filter for KAM / managers (hidden for sales executives):
/// tick one or several people; none ticked = everyone.
class SalesFilterChips extends ConsumerWidget {
  const SalesFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final owners = ref.watch(clientOwnersProvider);
    final selected = ref.watch(salesFilterProvider);
    final filter = ref.read(salesFilterProvider.notifier);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: Text(l10n.allSalespeople),
          selected: selected.isEmpty,
          onSelected: (_) => filter.clear(),
        ),
        for (final u in owners)
          FilterChip(
            avatar: PersonBadge(userId: u.id, name: u.name, size: 20),
            label: Text(u.role == UserRole.salesExec ? u.name : '${u.name} (${u.role.label(l10n)})'),
            selected: selected.contains(u.id),
            showCheckmark: false,
            onSelected: (_) => filter.toggle(u.id),
          ),
        FilterChip(
          label: Text(l10n.unassigned),
          selected: selected.contains(unassignedFilter),
          onSelected: (_) => filter.toggle(unassignedFilter),
        ),
      ],
    );
  }
}

/// Round marker with the client's category letter, filled with its status colour.
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({super.key, required this.category, required this.color, this.size = 28});

  final String category;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(blurRadius: 2, color: Colors.black26)],
        ),
        alignment: Alignment.center,
        child: Text(
          category,
          style: TextStyle(
            // Dark letter on yellow, white on the darker colours.
            color: color == statusDueSoonColor ? Colors.black87 : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.45,
          ),
        ),
      );
}
