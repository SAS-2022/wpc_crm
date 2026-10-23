import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../core/text_input_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../users/users_repository.dart';
import 'early_checkout.dart';

/// Home, for direct managers: today's requests to leave early, with
/// Approve / Reject (hidden when none).
class EarlyCheckoutRequestsCard extends ConsumerStatefulWidget {
  const EarlyCheckoutRequestsCard({super.key});

  @override
  ConsumerState<EarlyCheckoutRequestsCard> createState() => _EarlyCheckoutRequestsCardState();
}

class _EarlyCheckoutRequestsCardState extends ConsumerState<EarlyCheckoutRequestsCard> {
  final _busy = <String>{};

  Future<void> _decide(EarlyCheckout r, AppUser me, {required bool approve}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    var comment = '';
    if (!approve) {
      final text = await showTextInputDialog(context, title: l10n.reject, label: l10n.rejectReason, confirmLabel: l10n.reject);
      if (text == null || !mounted) return;
      comment = text.trim();
    }
    setState(() => _busy.add(r.id));
    try {
      await decideEarlyCheckout(r, me, approve: approve, comment: comment);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(currentUserProvider).value;
    final list = ref.watch(earlyCheckoutsToDecideProvider).value ?? const <EarlyCheckout>[];
    if (me == null || list.isEmpty) return const SizedBox.shrink();
    final users = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};
    final time = DateFormat.jm(Localizations.localeOf(context).toString());
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(l10n.earlyRequestsWaiting(list.length), style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final r in list)
              ListTile(
                leading: Icon(Icons.directions_walk, color: Colors.orange.shade800),
                title: Text(users[r.uid]?.name ?? ''),
                subtitle: Text(
                  [if (r.createdAt != null) time.format(r.createdAt!), r.reason].join(' · '),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: l10n.reject,
                      color: Theme.of(context).colorScheme.error,
                      onPressed: _busy.contains(r.id) ? null : () => _decide(r, me, approve: false),
                      icon: const Icon(Icons.close),
                    ),
                    IconButton.filledTonal(
                      tooltip: l10n.approve,
                      onPressed: _busy.contains(r.id) ? null : () => _decide(r, me, approve: true),
                      icon: const Icon(Icons.check),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
