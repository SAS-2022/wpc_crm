import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';

/// Settings → Import (2026-11-17, user): one page for everything that can
/// be imported (clients, client locations, later products and more).
/// Sales manager / GM.
class ImportHubScreen extends StatelessWidget {
  const ImportHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget tile(IconData icon, String title, String subtitle, String? path) => Card(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: ListTile(
            enabled: path != null,
            leading: CircleAvatar(child: Icon(icon)),
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: path == null ? null : const Icon(Icons.chevron_right),
            onTap: path == null ? null : () => context.push(path),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.importData)),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(l10n.importHubHelp, style: theme.textTheme.bodyMedium),
          ),
          tile(Icons.store_outlined, l10n.importClients, l10n.importClientsSubtitle, '/import/clients'),
          tile(Icons.add_location_alt_outlined, l10n.importLocationsTitle, l10n.importLocationsSubtitle, '/import/locations'),
          tile(Icons.palette_outlined, l10n.importProducts, l10n.importProductsSubtitle, '/import/products'),
        ],
      ),
    );
  }
}
