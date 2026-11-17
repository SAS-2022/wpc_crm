import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/search_text.dart';
import '../../l10n/app_localizations.dart';
import '../clients/client.dart';
import '../clients/client_detail_screen.dart' show whatsAppNumber;
import '../clients/client_widgets.dart';
import '../clients/clients_repository.dart';
import '../clients/visit_rules.dart';
import '../users/users_repository.dart';
import 'project.dart';
import 'project_widgets.dart';

// Companies on a project (2026-11-17, user): contracting companies, designer
// offices and consultants, each a card with several contacts; and the
// linked clients drawn as branches of the project.

String partyKindLabel(AppLocalizations l10n, PartyKind k) => switch (k) {
      PartyKind.contractor => l10n.contractingCompany,
      PartyKind.designer => l10n.designerOffice,
      PartyKind.consultant => l10n.consultant,
    };

String partyKindPlural(AppLocalizations l10n, PartyKind k) => switch (k) {
      PartyKind.contractor => l10n.contractors,
      PartyKind.designer => l10n.designerOffices,
      PartyKind.consultant => l10n.consultants,
    };

String addPartyLabel(AppLocalizations l10n, PartyKind k) => switch (k) {
      PartyKind.contractor => l10n.addContractor,
      PartyKind.designer => l10n.addDesignerOffice,
      PartyKind.consultant => l10n.addConsultant,
    };

IconData partyKindIcon(PartyKind k) => switch (k) {
      PartyKind.contractor => Icons.engineering,
      PartyKind.designer => Icons.design_services,
      PartyKind.consultant => Icons.support_agent,
    };

Color partyKindColor(PartyKind k) => switch (k) {
      PartyKind.contractor => const Color(0xFFE65100),
      PartyKind.designer => const Color(0xFF6A1B9A),
      PartyKind.consultant => const Color(0xFF00695C),
    };

/// Client tag that marks a client as this kind of company (name suggestions).
const partyClientTag = {PartyKind.contractor: 'contractor', PartyKind.designer: 'interior_designer'};

/// A company on the project page: name and each contact with call /
/// WhatsApp / email.
class PartyCard extends StatelessWidget {
  const PartyCard({super.key, required this.party});

  final ProjectParty party;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = partyKindColor(party.kind);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: color.withValues(alpha: 0.08),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color,
                  child: Icon(partyKindIcon(party.kind), color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(party.name, style: theme.textTheme.titleMedium),
                      Text(partyKindLabel(l10n, party.kind), style: theme.textTheme.bodySmall?.copyWith(color: color)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (party.contacts.isEmpty)
            ListTile(dense: true, title: Text(l10n.noContactsYet, style: theme.textTheme.bodySmall)),
          for (final (i, c) in party.contacts.indexed) ...[
            if (i > 0) const Divider(height: 1, indent: 60),
            _ContactRow(contact: c),
          ],
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact});

  final PartyContact contact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = contact;
    return ListTile(
      leading: CircleAvatar(radius: 16, child: Text(c.name.trim().isEmpty ? '?' : c.name.trim().characters.first)),
      title: Text(c.name.isEmpty ? '—' : c.name),
      subtitle: Text([c.title, c.phone, c.email].where((s) => s.isNotEmpty).join(' · ')),
      trailing: Wrap(
        children: [
          if (c.phone.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.call),
              tooltip: l10n.callPhone,
              onPressed: () => launchUrl(Uri.parse('tel:${c.phone.replaceAll(' ', '')}')),
            ),
            IconButton(
              icon: const Icon(Icons.chat),
              tooltip: 'WhatsApp',
              onPressed: () => launchUrl(Uri.parse('https://wa.me/${whatsAppNumber(c.phone)}'), mode: LaunchMode.externalApplication),
            ),
          ],
          if (c.email.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.email_outlined),
              tooltip: l10n.email,
              onPressed: () => launchUrl(Uri.parse('mailto:${c.email}')),
            ),
        ],
      ),
    );
  }
}

/// Add / edit a contact; null = cancelled.
Future<PartyContact?> showContactDialog(BuildContext context, {PartyContact? initial}) {
  final l10n = AppLocalizations.of(context);
  final name = TextEditingController(text: initial?.name ?? '');
  final title = TextEditingController(text: initial?.title ?? '');
  final phone = TextEditingController(text: initial?.phone ?? '');
  final email = TextEditingController(text: initial?.email ?? '');
  final form = GlobalKey<FormState>();
  return showDialog<PartyContact>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(initial == null ? l10n.addContact : l10n.editContact),
      content: SizedBox(
        width: 420,
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                autofocus: true,
                decoration: InputDecoration(labelText: '${l10n.contactName} *', prefixIcon: const Icon(Icons.person)),
                validator: (v) => (v ?? '').trim().isEmpty ? l10n.required : null,
              ),
              TextFormField(
                controller: title,
                decoration: InputDecoration(labelText: l10n.contactTitle, prefixIcon: const Icon(Icons.badge_outlined)),
              ),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: l10n.phone, prefixIcon: const Icon(Icons.phone)),
              ),
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: l10n.email, prefixIcon: const Icon(Icons.email_outlined)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () {
            if (!form.currentState!.validate()) return;
            Navigator.pop(dialog, PartyContact(name: name.text.trim(), title: title.text.trim(), phone: phone.text.trim(), email: email.text.trim()));
          },
          child: Text(l10n.save),
        ),
      ],
    ),
  );
}

/// A company being edited on the project form.
class PartyDraft {
  PartyDraft({required this.id, required this.kind, String name = '', List<PartyContact> contacts = const []})
      : name = TextEditingController(text: name),
        contacts = [...contacts];

  factory PartyDraft.of(ProjectParty p) => PartyDraft(id: p.id, kind: p.kind, name: p.name, contacts: p.contacts);

  final String id;
  final PartyKind kind;
  final TextEditingController name;
  final focus = FocusNode();
  final List<PartyContact> contacts;

  ProjectParty toParty() => ProjectParty(id: id, kind: kind, name: name.text.trim(), contacts: contacts);

  void dispose() {
    name.dispose();
    focus.dispose();
  }
}

/// Edit card: company name (suggestions from other projects and tagged
/// clients) and its contacts.
class PartyEditorCard extends StatelessWidget {
  const PartyEditorCard({
    super.key,
    required this.draft,
    required this.suggestions,
    required this.required,
    required this.onChanged,
    required this.onRemove,
  });

  final PartyDraft draft;
  final List<String> suggestions;

  /// The first contractor: its name is required.
  final bool required;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = partyKindColor(draft.kind);
    final label = partyKindLabel(l10n, draft.kind);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(partyKindIcon(draft.kind), color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: RawAutocomplete<String>(
                    textEditingController: draft.name,
                    focusNode: draft.focus,
                    optionsBuilder: (v) => v.text.trim().isEmpty
                        ? const Iterable<String>.empty()
                        : suggestions.where((o) => searchHas(o, v.text) && o != v.text).take(8),
                    onSelected: (_) => onChanged(),
                    fieldViewBuilder: (context, controller, focus, _) => TextFormField(
                      controller: controller,
                      focusNode: focus,
                      decoration: InputDecoration(labelText: required ? '$label *' : label),
                      validator: required ? (v) => (v ?? '').trim().isEmpty ? l10n.required : null : null,
                    ),
                    optionsViewBuilder: (context, onSelected, options) => Align(
                      alignment: AlignmentDirectional.topStart,
                      child: Material(
                        elevation: 4,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 240, maxWidth: 420),
                          child: ListView(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            children: [
                              for (final o in options) ListTile(dense: true, title: Text(o), onTap: () => onSelected(o)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (onRemove != null)
                  IconButton(icon: const Icon(Icons.close), tooltip: l10n.remove, onPressed: onRemove),
              ],
            ),
            for (final (i, c) in draft.contacts.indexed)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsetsDirectional.only(start: 36),
                leading: const Icon(Icons.person_outline),
                title: Text(c.name, style: theme.textTheme.bodyLarge),
                subtitle: Text([c.title, c.phone, c.email].where((s) => s.isNotEmpty).join(' · ')),
                onTap: () async {
                  final edited = await showContactDialog(context, initial: c);
                  if (edited == null) return;
                  draft.contacts[i] = edited;
                  onChanged();
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.delete,
                  onPressed: () {
                    draft.contacts.removeAt(i);
                    onChanged();
                  },
                ),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 28),
                child: TextButton.icon(
                  onPressed: () async {
                    final added = await showContactDialog(context);
                    if (added == null) return;
                    draft.contacts.add(added);
                    onChanged();
                  },
                  icon: const Icon(Icons.person_add_alt),
                  label: Text(l10n.addContact),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The linked clients as branches of the project: the project at the top,
/// a line down the side and one branch per client.
class ProjectClientsTree extends ConsumerWidget {
  const ProjectClientsTree({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final clients = ref.watch(clientsByIdProvider);
    final users = {for (final u in ref.watch(usersProvider).value ?? const []) u.id: u};
    final rules = ref.watch(visitRulesProvider).value ?? VisitRules.defaults;
    final now = DateTime.now();
    final p = project;
    final line = theme.colorScheme.outline;
    final stageColor = projectStageColor(p.stage);

    Widget branch(String id, bool last) {
      final c = clients[id];
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 40, child: CustomPaint(painter: _BranchPainter(color: line, last: last, rtl: Directionality.of(context) == TextDirection.rtl))),
            Expanded(
              child: Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: ListTile(
                  dense: true,
                  leading: c == null
                      ? CircleAvatar(radius: 14, backgroundColor: theme.disabledColor, child: const Text('?', style: TextStyle(color: Colors.white)))
                      : CategoryBadge(category: c.category, color: clientColor(c, rules, now)),
                  title: Text(c?.name ?? p.clientNames[id] ?? '?', style: theme.textTheme.bodyLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(c == null
                      ? l10n.clientNotYours
                      : [c.city, users[c.assignedTo]?.name ?? l10n.unassigned].where((s) => s.isNotEmpty).join(' · ')),
                  trailing: c == null ? null : const Icon(Icons.chevron_right),
                  onTap: c == null ? null : () => context.push('/clients/$id'),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The project: the trunk.
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: stageColor, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.apartment, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: theme.textTheme.titleSmall),
                    Text(l10n.clientsCountShort(p.clientIds.length), style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          if (p.clientIds.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 52, top: 8, bottom: 4),
              child: Text(l10n.noClientsLinked, style: theme.textTheme.bodySmall),
            ),
          for (final (i, id) in p.clientIds.indexed) branch(id, i == p.clientIds.length - 1),
        ],
      ),
    );
  }
}

/// A trunk line down from the project and a branch across to the client
/// card; the last one ends at its branch.
class _BranchPainter extends CustomPainter {
  _BranchPainter({required this.color, required this.last, required this.rtl});

  final Color color;
  final bool last;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    double x(double v) => rtl ? size.width - v : v;
    const trunk = 20.0;
    final mid = size.height / 2;
    canvas.drawLine(Offset(x(trunk), 0), Offset(x(trunk), last ? mid - 8 : size.height), paint);
    final path = Path()
      ..moveTo(x(trunk), mid - 8)
      ..quadraticBezierTo(x(trunk), mid, x(trunk + 8), mid)
      ..lineTo(x(size.width), mid);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BranchPainter old) => old.color != color || old.last != last || old.rtl != rtl;
}

/// Client names usable as suggestions for a company of [kind].
List<String> partySuggestions(PartyKind kind, List<Project> projects, Iterable<Client> clients) {
  final tag = partyClientTag[kind];
  return <String>{
    for (final p in projects)
      for (final party in p.partiesOf(kind))
        if (party.name.isNotEmpty) party.name,
    if (tag != null)
      for (final c in clients)
        if (c.tagIds.contains(tag)) c.name,
  }.toList()
    ..sort();
}
