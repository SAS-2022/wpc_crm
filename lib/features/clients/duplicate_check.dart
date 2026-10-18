import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../l10n/app_localizations.dart';

/// An existing client that looks like a client being added, from the
/// `findClientDuplicates` Cloud Function (it sees every client; a sales exec
/// can read only their own).
class DuplicateMatch {
  const DuplicateMatch({
    required this.id,
    required this.name,
    required this.city,
    required this.assignedTo,
    required this.ownerName,
    required this.reasons,
  });

  final String id;
  final String name;
  final String city;
  final String? assignedTo;
  final String ownerName;

  /// sameVat, sameCompanyId, sameName, samePhone, similarName, nearby.
  final List<String> reasons;

  factory DuplicateMatch.fromMap(Map<Object?, Object?> m) => DuplicateMatch(
        id: m['id'] as String? ?? '',
        name: m['name'] as String? ?? '',
        city: m['city'] as String? ?? '',
        assignedTo: m['assignedTo'] as String?,
        ownerName: m['ownerName'] as String? ?? '',
        reasons: [for (final r in m['reasons'] as List<Object?>? ?? const []) '$r'],
      );
}

/// Clients that look like the new client in [data] (the client form's
/// fields: name, vat, companyId, phone, mobile, lat, lng).
Future<List<DuplicateMatch>> findClientDuplicates(Map<String, dynamic> data) async {
  final res = await FirebaseFunctions.instance.httpsCallable('findClientDuplicates').call<Map<Object?, Object?>>({
    for (final k in ['name', 'vat', 'companyId', 'phone', 'mobile', 'lat', 'lng']) k: data[k],
  });
  return [
    for (final m in res.data['matches'] as List<Object?>? ?? const [])
      if (m is Map<Object?, Object?>) DuplicateMatch.fromMap(m),
  ];
}

String duplicateReasonLabel(AppLocalizations l10n, String reason) => switch (reason) {
      'sameVat' => l10n.dupSameVat,
      'sameCompanyId' => l10n.dupSameCompanyId,
      'sameName' => l10n.dupSameName,
      'samePhone' => l10n.dupSamePhone,
      'similarName' => l10n.dupSimilarName,
      'nearby' => l10n.dupNearby,
      _ => reason,
    };

/// What the user chose in [showDuplicatesDialog].
sealed class DuplicateChoice {
  const DuplicateChoice();
}

/// Sales manager / GM: checked, it's a different client.
class AddAnyway extends DuplicateChoice {
  const AddAnyway();
}

/// Use (plan) or open the existing client instead.
class UseExisting extends DuplicateChoice {
  const UseExisting(this.match);
  final DuplicateMatch match;
}

/// Lists the look-alike clients. Only the sales manager / GM ([canOverride])
/// may still add the client; others pick an existing one or ask them.
/// [canUse]: whether a match can be taken instead (e.g. it's on the plan
/// owner's list); [useLabel] names that action ("Use this client" / "Open").
Future<DuplicateChoice?> showDuplicatesDialog(
  BuildContext context, {
  required List<DuplicateMatch> matches,
  required bool canOverride,
  required bool Function(DuplicateMatch) canUse,
  required String useLabel,
}) {
  final l10n = AppLocalizations.of(context);
  return showDialog<DuplicateChoice>(
    context: context,
    builder: (dialog) => PointerInterceptor(
      child: AlertDialog(
        title: Text(l10n.possibleDuplicate),
        content: SizedBox(
          width: 460,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(l10n.duplicatesFoundBody),
              const SizedBox(height: 8),
              for (final m in matches)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.store),
                  title: Text(m.name),
                  subtitle: Text([
                    if (m.city.isNotEmpty) m.city,
                    m.assignedTo == null ? l10n.unassigned : m.ownerName,
                    m.reasons.map((r) => duplicateReasonLabel(l10n, r)).join(', '),
                  ].join(' · ')),
                  trailing: canUse(m)
                      ? TextButton(onPressed: () => Navigator.pop(dialog, UseExisting(m)), child: Text(useLabel))
                      : null,
                ),
              const SizedBox(height: 8),
              Text(
                canOverride ? l10n.duplicateOverrideHint : l10n.duplicateAskManager,
                style: Theme.of(dialog).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: Text(l10n.cancel)),
          if (canOverride)
            FilledButton(onPressed: () => Navigator.pop(dialog, const AddAnyway()), child: Text(l10n.notDuplicateAdd)),
        ],
      ),
    ),
  );
}
