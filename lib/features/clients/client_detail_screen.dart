import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../attachments/attachments.dart';
import '../attachments/attachments_section.dart';
import '../users/users_repository.dart';
import '../visits/app_calls.dart';
import '../visits/call_chip.dart';
import '../visits/visit.dart';
import '../visits/visits_repository.dart';
import 'client.dart';
import 'client_locations_section.dart';
import 'given_items_widgets.dart';
import 'client_tags.dart';
import 'client_widgets.dart';
import 'clients_repository.dart';
import 'client_status.dart';
import 'client_status_widgets.dart';
import 'transfer.dart';
import 'transfer_dialog.dart';
import 'visit_rules.dart';
import 'client_links_widgets.dart';

/// Client page: quick actions (call, WhatsApp, directions, visit), contact,
/// location, sales details, notes, photos & files and visit history.
class ClientDetailScreen extends ConsumerWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final String clientId;

  static String _money(double amount, String currency, String locale) =>
      NumberFormat.currency(locale: locale, name: currency.isEmpty ? 'SAR' : currency, decimalDigits: 2).format(amount);

  /// Digits only, with Saudi local numbers (05…) turned into 9665….
  static String _waNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.startsWith('05') ? '966${digits.substring(1)}' : digits;
  }

  /// Sales manager / GM: deletes the client after confirming. When it has
  /// visits, they must type their login password first (re-authentication).
  Future<void> _delete(BuildContext context, WidgetRef ref, Client client) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final repo = ref.read(clientsRepositoryProvider);
    final int visits;
    try {
      visits = await repo.visitCount(client.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
      return;
    }
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteClientDialog(client: client, visits: visits),
    );
    if (ok != true) return;
    try {
      await repo.delete(client);
      messenger.showSnackBar(SnackBar(content: Text(l10n.clientDeleted(client.name))));
      router.go('/clients');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    }
  }

  /// Hides the client (after confirming) or shows it again.
  Future<void> _setHidden(BuildContext context, WidgetRef ref, {required bool hidden}) async {
    final l10n = AppLocalizations.of(context);
    final me = ref.read(currentUserProvider).value;
    final messenger = ScaffoldMessenger.of(context);
    if (me == null) return;
    if (hidden) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(l10n.hideClientTitle),
          content: Text(l10n.hideClientBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.hideClient)),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await ref.read(clientsRepositoryProvider).setHidden(clientId, hidden: hidden, by: me.id);
      messenger.showSnackBar(SnackBar(content: Text(hidden ? l10n.clientHidden : l10n.clientUnhidden)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(currentUserProvider).value;
    final clients = ref.watch(allClientsProvider);
    final client = clients.value?.where((c) => c.id == clientId).firstOrNull;
    if (client == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: clients.isLoading ? const CircularProgressIndicator() : Text(l10n.noClients),
        ),
      );
    }
    final users = ref.watch(usersProvider).value ?? const [];
    final rules = ref.watch(visitRulesProvider).value ?? VisitRules.defaults;
    final theme = Theme.of(context);
    final exec = users.where((u) => u.id == client.assignedTo).firstOrNull;
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final status = visitStatus(client, rules, now);
    final rule = rules.of(client.category);
    final canEdit = (me?.role.isSupervisor ?? false) || client.assignedTo == me?.id;
    final phone = client.mobile.isNotEmpty ? client.mobile : client.phone;
    final usersById = {for (final u in users) u.id: u};
    final canTransfer = me != null && canTransferFrom(me, client.assignedTo, usersById);
    // Closed / not working: the owner asks, KAM / managers change it directly.
    final canChangeStatus = me != null &&
        client.statusRequest == null &&
        (canSetStatusDirectly(me, client, usersById) || canRequestStatus(me, client));
    String nameOf(String? uid) => uid == null ? l10n.unassigned : usersById[uid]?.name ?? '?';
    final calls = ref.read(appCallProvider.notifier);
    void dial(String number) => calls.dial(clientId, number);

    // Back from a call dialled here: offer to log it.
    ref.listen(appCallProvider, (prev, next) {
      if (next == null || next.clientId != clientId || next.endedAt == null || prev?.endedAt != null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 10),
        content: Text(l10n.logThisCall(formatCallDuration(next.seconds))),
        action: SnackBarAction(label: l10n.logCall, onPressed: () => context.push('/clients/$clientId/call')),
      ));
    });

    Widget section(String title, List<Widget> rows) {
      final visible = rows.where((w) => w is! SizedBox).toList();
      if (visible.isEmpty) return const SizedBox.shrink();
      return Card(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
              ),
              ...visible,
            ],
          ),
        ),
      );
    }

    Widget row(IconData icon, String label, String value, {VoidCallback? onTap}) => value.isEmpty
        ? const SizedBox.shrink()
        : ListTile(
            dense: true,
            leading: Icon(icon),
            title: Text(label, style: theme.textTheme.bodySmall),
            subtitle: SelectableText(value, style: theme.textTheme.bodyLarge),
            trailing: onTap == null ? null : const Icon(Icons.chevron_right),
            onTap: onTap,
          );

    Widget action(IconData icon, String label, VoidCallback? onPressed) => Expanded(
          child: Column(children: [
            IconButton.filledTonal(onPressed: onPressed, icon: Icon(icon)),
            Text(label, style: theme.textTheme.labelSmall, textAlign: TextAlign.center),
          ]),
        );

    // "· Call" when the latest contact was a phone call.
    final latest = ref.watch(clientVisitsProvider(clientId)).value?.firstOrNull;
    final lastWasCall = latest != null &&
        latest.isCall &&
        client.lastVisitAt != null &&
        (latest.checkedInAt == null || latest.checkedInAt!.difference(client.lastVisitAt!).inMinutes.abs() < 2);
    final lastVisit = client.lastVisitAt == null
        ? l10n.never
        : '${DateFormat.yMMMd(locale).format(client.lastVisitAt!)} · ${l10n.daysAgo(now.difference(client.lastVisitAt!).inDays)}'
            '${lastWasCall ? ' · ${l10n.call}' : ''}';

    return Scaffold(
      appBar: AppBar(
        title: Text(client.name),
        actions: [
          if (canTransfer)
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: l10n.transferClients,
              onPressed: () => showTransferDialog(context, ref, [client]),
            ),
          if (canChangeStatus)
            IconButton(
              icon: const Icon(Icons.store_mall_directory_outlined),
              tooltip: l10n.changeClientStatus,
              onPressed: () => showClientStatusDialog(context, ref, client),
            ),
          if (me?.role.isSupervisor ?? false)
            IconButton(
              icon: Icon(client.hidden ? Icons.visibility : Icons.visibility_off),
              tooltip: client.hidden ? l10n.unhideClient : l10n.hideClient,
              onPressed: () => _setHidden(context, ref, hidden: !client.hidden),
            ),
          if (me?.role.isAdmin ?? false)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.deleteClient,
              onPressed: () => _delete(context, ref, client),
            ),
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: l10n.editClient,
              onPressed: () => context.push('/clients/$clientId/edit'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ClientStatusBanners(client: client),
          if (client.hidden)
            Card(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              color: theme.colorScheme.surfaceContainerHighest,
              child: ListTile(
                leading: const Icon(Icons.visibility_off),
                title: Text(l10n.clientHiddenBanner),
                trailing: (me?.role.isSupervisor ?? false)
                    ? TextButton(
                        onPressed: () => _setHidden(context, ref, hidden: false),
                        child: Text(l10n.unhideClient),
                      )
                    : null,
              ),
            ),
          // Header: category, status and quick actions.
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CategoryBadge(category: client.category, color: clientColor(client, rules, now), size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(client.name, style: theme.textTheme.titleLarge),
                      if (client.legalName.isNotEmpty && client.legalName != client.name)
                        Text(client.legalName, style: theme.textTheme.titleSmall),
                      Text(
                        [
                          if (client.city.isNotEmpty) client.city,
                          client.hasLocation ? visitStatusLabel(status, l10n) : l10n.noLocation,
                          if (client.source == 'manual') l10n.addedInApp,
                        ].join(' · '),
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      ClientTagChips(client: client),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Row(
              children: [
                action(Icons.call, l10n.callPhone, phone.isEmpty ? null : () => dial(phone)),
                action(
                  Icons.chat,
                  'WhatsApp',
                  phone.isEmpty
                      ? null
                      : () => launchUrl(Uri.parse('https://wa.me/${_waNumber(phone)}'), mode: LaunchMode.externalApplication),
                ),
                action(
                  Icons.directions,
                  l10n.directions,
                  !client.hasLocation ? null : () => directionsToClient(context, client),
                ),
                action(Icons.add_location_alt, l10n.addVisit, () => context.push('/clients/$clientId/visit')),
                action(Icons.add_call, l10n.logCall, () => context.push('/clients/$clientId/call')),
              ],
            ),
          ),
          section(l10n.contact, [
            row(Icons.person, l10n.contactPerson, client.contactPerson),
            row(Icons.phone, l10n.phone, client.phone, onTap: () => dial(client.phone)),
            row(Icons.smartphone, l10n.mobile, client.mobile, onTap: () => dial(client.mobile)),
            row(Icons.email, l10n.email, client.email, onTap: () => launchUrl(Uri.parse('mailto:${client.email}'))),
            for (final c in client.contacts)
              ListTile(
                dense: true,
                leading: const Icon(Icons.person_outline),
                title: Text(c.name, style: theme.textTheme.bodyLarge),
                subtitle: Text([c.mobile, c.phone].where((p) => p.isNotEmpty).toSet().join(' · ')),
                trailing: c.mobile.isEmpty && c.phone.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.call),
                        tooltip: l10n.callPhone,
                        onPressed: () => dial(c.mobile.isNotEmpty ? c.mobile : c.phone),
                      ),
              ),
            if (client.contactPerson.isEmpty &&
                client.phone.isEmpty &&
                client.mobile.isEmpty &&
                client.email.isEmpty &&
                client.contacts.isEmpty)
              ListTile(dense: true, title: Text(l10n.noContactDetails)),
          ]),
          // Catalogs / display stands: what the client got, when a new one is
          // due, and recording one (backdated if needed).
          section(l10n.itemsGiven, [GivenItemsSection(client: client, canEdit: canEdit)]),
          section(l10n.accountSection, [
            if (client.receivable != 0)
              row(Icons.account_balance_wallet, l10n.receivable, _money(client.receivable, client.currency, locale)),
            if (client.payable != 0)
              row(Icons.payments, l10n.payable, _money(client.payable, client.currency, locale)),
          ]),
          section(l10n.salesSection, [
            row(Icons.event_available, l10n.lastVisit, lastVisit),
            row(Icons.category, l10n.category, l10n.categoryRule(client.category, rule.greenDays, rule.yellowDays)),
            row(Icons.badge, l10n.salesExecutive, exec?.name ?? l10n.unassigned),
            row(Icons.business, l10n.odooSalesperson, client.odooSalesperson),
            row(Icons.apartment, l10n.clientType, switch (client.clientType) {
              clientTypeCompany => l10n.clientTypeCompany,
              clientTypeIndividual => l10n.clientTypeIndividual,
              _ => '',
            }),
            row(Icons.receipt_long, l10n.vat, client.vat),
            row(Icons.numbers, l10n.companyId, client.companyId),
            row(Icons.sell, l10n.tags, client.tags),
            row(Icons.merge_type, l10n.mergedContacts, client.aliases.join('\n')),
          ]),
          section(l10n.transferHistory, [
            for (final t in client.transfers.reversed)
              ListTile(
                dense: true,
                leading: const Icon(Icons.swap_horiz),
                title: Text('${nameOf(t.fromId)} → ${nameOf(t.toId)}', style: theme.textTheme.bodyLarge),
                subtitle: Text(l10n.transferBy(
                  nameOf(t.byId),
                  t.at == null ? '' : DateFormat.yMMMd(locale).add_jm().format(t.at!),
                )),
              ),
          ]),
          section(l10n.linkedClients, [
            ClientLinksSection(client: client, canEdit: me?.role.isSupervisor ?? false),
          ]),
          section(l10n.clientStatusHistory, [
            if (client.statusLog.isNotEmpty) ClientStatusHistory(client: client),
          ]),
          section(l10n.locationSection, [
            row(Icons.place, l10n.address, client.address),
            if (client.street.isNotEmpty && !client.address.contains(client.street))
              row(Icons.signpost, l10n.street, client.street),
            row(Icons.location_city, l10n.city, client.city),
            row(Icons.map, l10n.region, client.state),
            row(Icons.public, l10n.country, client.country),
            // Every location (main, factory, showroom, …), each labelled.
            ClientLocationsList(client: client, canEdit: canEdit),
          ]),
          section(l10n.notes, [row(Icons.notes, l10n.notes, client.notes)]),
          AttachmentsSection(
            owner: (parent: AttachmentParent.clients, id: clientId),
            canAdd: canEdit,
            canDelete: me?.role.isSupervisor ?? false,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(l10n.visitHistory, style: theme.textTheme.titleMedium),
          ),
          ...switch (ref.watch(clientVisitsProvider(clientId))) {
            AsyncData(value: final visits) when visits.isEmpty => [ListTile(title: Text(l10n.noVisits))],
            AsyncData(value: final visits) => [
                for (final v in visits)
                  _VisitTile(
                    visit: v,
                    place: ref.watch(locationTypesByIdProvider)[v.locationTypeId]?.label(locale.split('_').first),
                    author: users.where((u) => u.id == v.salesExecId).firstOrNull?.name ?? '',
                    locale: locale,
                  ),
              ],
            AsyncError(:final error) => [ListTile(title: Text(l10n.errorWithMessage('$error')))],
            _ => [const Center(child: CircularProgressIndicator())],
          },
        ],
      ),
    );
  }
}

class _VisitTile extends StatelessWidget {
  const _VisitTile({required this.visit, required this.author, required this.locale, this.place});

  final Visit visit;

  /// Which of the client's locations, when labelled.
  final String? place;
  final String author;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = Theme.of(context).colorScheme.error;
    final far = !visit.isCall && visit.distanceMeters != null && visit.distanceMeters! > visitRadiusMeters;
    final when = visit.checkedInAt == null ? '' : DateFormat.yMMMd(locale).add_jm().format(visit.checkedInAt!);
    return ListTile(
      onTap: () => context.push('/visits/${visit.id}'),
      leading: visit.isCall ? const Icon(Icons.call, color: callColor) : const Icon(Icons.event_available),
      title: Text([when, author, ?place].where((s) => s.isNotEmpty).join(' · ')),
      trailing: visit.given.isEmpty ? null : GivenIcons(given: visit.given),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (visit.isCall) CallChip(visit: visit),
          Text(visit.notes),
          if (far) Text(l10n.farFlag(formatDistance(visit.distanceMeters!)), style: TextStyle(color: error)),
          if (visit.mocked) Text(l10n.fakeGpsFlag, style: TextStyle(color: error)),
        ],
      ),
    );
  }
}

/// Confirms deleting a client. With visits, the user's login password is
/// required and checked with Firebase before the dialog returns true.
class _DeleteClientDialog extends StatefulWidget {
  const _DeleteClientDialog({required this.client, required this.visits});

  final Client client;
  final int visits;

  @override
  State<_DeleteClientDialog> createState() => _DeleteClientDialogState();
}

class _DeleteClientDialogState extends State<_DeleteClientDialog> {
  final _password = TextEditingController();
  String? _error;
  bool _checking = false;

  bool get _needsPassword => widget.visits > 0;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (!_needsPassword) {
      Navigator.pop(context, true);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null || _password.text.isEmpty) {
      setState(() => _error = l10n.wrongPassword);
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      await user!.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: _password.text),
      );
      if (mounted) Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.code == 'too-many-requests' ? l10n.tooManyAttempts : l10n.wrongPassword);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = Theme.of(context).colorScheme.error;
    return AlertDialog(
      title: Text(l10n.deleteClientTitle(widget.client.name)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_needsPassword ? l10n.deleteClientWithVisits(widget.visits) : l10n.deleteClientBody),
            if (_needsPassword) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                autofocus: true,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _checking ? null : _confirm(),
                decoration: InputDecoration(labelText: l10n.yourPassword, errorText: _error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _checking ? null : () => Navigator.pop(context, false), child: Text(l10n.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: error),
          onPressed: _checking ? null : _confirm,
          child: _checking
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.delete),
        ),
      ],
    );
  }
}
