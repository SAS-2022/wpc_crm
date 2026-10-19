import '../../core/app_user.dart';
import '../clients/client.dart';

/// Users page status chips (user request 2026-10-19).
enum UserStatusFilter { all, active, pending, inactive, olderApp }

/// Search and filters of the Users page. [search] matches name, email,
/// phone and position (by its label); empty sets / null = no filter.
class UserFilter {
  const UserFilter({
    this.search = '',
    this.status = UserStatusFilter.all,
    this.roles = const {},
    this.companyId,
    this.siteId,
  });

  final String search;
  final UserStatusFilter status;
  final Set<UserRole> roles;
  final String? companyId;
  final String? siteId;

  /// Role, company and site (the status chips and search are shown apart).
  int get sheetCount => roles.length + (companyId == null ? 0 : 1) + (siteId == null ? 0 : 1);

  UserFilter copyWith({
    String? search,
    UserStatusFilter? status,
    Set<UserRole>? roles,
    String? Function()? companyId,
    String? Function()? siteId,
  }) =>
      UserFilter(
        search: search ?? this.search,
        status: status ?? this.status,
        roles: roles ?? this.roles,
        companyId: companyId == null ? this.companyId : companyId(),
        siteId: siteId == null ? this.siteId : siteId(),
      );

  /// [positionLabel]: the position's name in the reader's language;
  /// [outdated]: on an older app build than the newest.
  bool matches(AppUser u, {required String Function(String) positionLabel, required bool Function(AppUser) outdated}) {
    final ok = switch (status) {
      UserStatusFilter.all => true,
      UserStatusFilter.active => u.active,
      UserStatusFilter.pending => u.isPendingApproval,
      UserStatusFilter.inactive => !u.active && !u.isPendingApproval,
      UserStatusFilter.olderApp => u.active && outdated(u),
    };
    if (!ok) return false;
    if (roles.isNotEmpty && !roles.contains(u.role)) return false;
    if (companyId != null && u.companyId != companyId) return false;
    if (siteId != null && !u.workSiteIds.contains(siteId)) return false;
    final q = Client.normalizeName(search);
    if (q.isEmpty) return true;
    final digits = search.replaceAll(RegExp(r'\D'), '');
    return Client.normalizeName(u.name).contains(q) ||
        u.email.toLowerCase().contains(q) ||
        Client.normalizeName(positionLabel(u.position)).contains(q) ||
        (digits.length >= 3 && u.phone.replaceAll(RegExp(r'\D'), '').contains(digits));
  }
}
