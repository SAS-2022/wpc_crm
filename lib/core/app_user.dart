import 'package:cloud_firestore/cloud_firestore.dart';

import '../l10n/app_localizations.dart';

enum UserRole {
  salesExec('sales_exec'),
  kam('kam'),
  salesManager('sales_manager'),
  gm('gm');

  const UserRole(this.value);

  /// Value stored in Firestore `users/{uid}.role` and RTDB `roles/{uid}`.
  final String value;

  static UserRole fromValue(String? value) =>
      values.firstWhere((r) => r.value == value, orElse: () => salesExec);

  /// Sales manager and GM: manage users, import and edit clients.
  bool get isAdmin => this == salesManager || this == gm;

  /// KAM, sales manager and GM: see all clients, visits and live locations.
  bool get isSupervisor => isAdmin || this == kam;

  /// Field staff whose location is tracked live.
  bool get isTracked => this == salesExec || this == kam;

  String label(AppLocalizations l10n) => switch (this) {
        salesExec => l10n.roleSalesExec,
        kam => l10n.roleKam,
        salesManager => l10n.roleSalesManager,
        gm => l10n.roleGm,
      };
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.kamId,
    required this.active,
    this.odooName = '',
    this.monthlyTarget = 0,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;

  /// The KAM supervising this sales executive.
  final String? kamId;
  final bool active;

  /// Salesperson name as written in Odoo exports, used to assign imported clients.
  final String odooName;

  /// Visits per month expected from this person; 0 = no target.
  final int monthlyTarget;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return AppUser(
      id: doc.id,
      name: d['name'] as String? ?? '',
      email: d['email'] as String? ?? '',
      phone: d['phone'] as String? ?? '',
      role: UserRole.fromValue(d['role'] as String?),
      kamId: d['kamId'] as String?,
      active: d['active'] as bool? ?? false,
      odooName: d['odooName'] as String? ?? '',
      monthlyTarget: (d['monthlyTarget'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'phone': phone,
        'role': role.value,
        'kamId': role == UserRole.salesExec ? kamId : null,
        'active': active,
        'odooName': odooName,
        'monthlyTarget': role.isTracked ? monthlyTarget : 0,
      };
}
