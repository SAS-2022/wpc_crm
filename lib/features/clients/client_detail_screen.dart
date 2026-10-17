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
import '../visits/visit.dart';
import '../visits/visits_repository.dart';
import 'client.dart';
import 'client_tags.dart';
import 'client_widgets.dart';
import 'clients_repository.dart';
import 'transfer.dart';
import 'transfer_dialog.dart';
import 'visit_rules.dart';

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
    String nameOf(String? uid) => uid == null ? l10n.unassigned : usersById[uid]?.name ?? '?';

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

    final lastVisit = client.lastVisitAt == null
        ? l10n.never
        : '${DateFormat.yMMMd(locale).format(client.lastVisitAt!)} · ${l10n.daysAgo(now.difference(client.lastVisitAt!).inDays)}';

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
          if (me?.role.isSupervisor ?? false)
            IconButton(
              icon: Icon(client.hidden ? Icons.visibility : Icons.visibility_off),
              tooltip: client.hidden ? l10n.unhideClient : l10n.hideClient,
              onPressed: () => _setHidden(context, ref, hidden: !client.hidden),
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
                action(Icons.call, l10n.callPhone, phone.isEmpty ? null : () => launchUrl(Uri.parse('tel:$phone'))),
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
                  !client.hasLocation
                      ? null
                      : () => launchUrl(
                            Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${client.lat},${client.lng}'),
                            mode: LaunchMode.externalApplication,
                          ),
                ),
                action(Icons.add_location_alt, l10n.addVisit, () => context.push('/clients/$clientId/visit')),
              ],
            ),
          ),
          section(l10n.contact, [
            row(Icons.person, l10n.contactPerson, client.contactPerson),
            row(Icons.phone, l10n.phone, client.phone, onTap: () => launchUrl(Uri.parse('tel:${client.phone}'))),
            row(Icons.smartphone, l10n.mobile, client.mobile, onTap: () => launchUrl(Uri.parse('tel:${client.mobile}'))),
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
                        onPressed: () => launchUrl(Uri.parse('tel:${c.mobile.isNotEmpty ? c.mobile : c.phone}')),
                      ),
              ),
            if (client.contactPerson.isEmpty &&
                client.phone.isEmpty &&
                client.mobile.isEmpty &&
                client.email.isEmpty &&
                client.contacts.isEmpty)
              ListTile(dense: true, title: Text(l10n.noContactDetails)),
          ]),
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
          section(l10n.locationSection, [
            row(Icons.place, l10n.address, client.address),
            if (client.street.isNotEmpty && !client.address.contains(client.street))
              row(Icons.signpost, l10n.street, client.street),
            row(Icons.location_city, l10n.city, client.city),
            row(Icons.map, l10n.region, client.state),
            row(Icons.public, l10n.country, client.country),
            if (client.hasLocation)
              row(Icons.my_location, l10n.coordinates, '${client.lat!.toStringAsFixed(6)}, ${client.lng!.toStringAsFixed(6)}',
                  onTap: () => launchUrl(
                        Uri.parse('https://www.google.com/maps/search/?api=1&query=${client.lat},${client.lng}'),
                        mode: LaunchMode.externalApplication,
                      ))
            else
              ListTile(dense: true, leading: const Icon(Icons.location_off), title: Text(l10n.noLocation)),
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
  const _VisitTile({required this.visit, required this.author, required this.locale});

  final Visit visit;
  final String author;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = Theme.of(context).colorScheme.error;
    final far = visit.distanceMeters != null && visit.distanceMeters! > visitRadiusMeters;
    final when = visit.checkedInAt == null ? '' : DateFormat.yMMMd(locale).add_jm().format(visit.checkedInAt!);
    return ListTile(
      onTap: () => context.push('/visits/${visit.id}'),
      leading: const Icon(Icons.event_available),
      title: Text([when, author].where((s) => s.isNotEmpty).join(' · ')),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(visit.notes),
          if (far) Text(l10n.farFlag(formatDistance(visit.distanceMeters!)), style: TextStyle(color: error)),
          if (visit.mocked) Text(l10n.fakeGpsFlag, style: TextStyle(color: error)),
        ],
      ),
    );
  }
}
