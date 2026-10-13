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
import 'visit_rules.dart';

/// Status colour from the client's category and last visit; grey = no location.
Color clientColor(Client c, VisitRules rules, DateTime now) =>
    c.hasLocation ? visitStatusColor(visitStatus(c, rules, now)) : Colors.grey;

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

final salesExecsProvider = Provider<List<AppUser>>((ref) {
  final users = ref.watch(usersProvider).value ?? const [];
  return users.where((u) => u.role == UserRole.salesExec).toList();
});

/// Sales executive filter for KAM / managers; hidden for sales executives.
class SalesFilterDropdown extends ConsumerWidget {
  const SalesFilterDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final execs = ref.watch(salesExecsProvider);
    return DropdownButton<String?>(
      value: ref.watch(salesFilterProvider),
      isExpanded: true,
      underline: const SizedBox.shrink(),
      items: [
        DropdownMenuItem(value: null, child: Text(l10n.allSalespeople)),
        DropdownMenuItem(value: unassignedFilter, child: Text(l10n.unassigned)),
        for (final u in execs) DropdownMenuItem(value: u.id, child: Text(u.name)),
      ],
      onChanged: ref.read(salesFilterProvider.notifier).set,
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
