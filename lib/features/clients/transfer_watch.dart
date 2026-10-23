import '../visits/visit.dart';
import 'client.dart';
import 'transfer.dart';

/// One client moved to a salesperson, and whether that person has visited
/// or called the client since (user request 2026-10-19: watch that moved
/// clients get visited).
class TransferWatch {
  const TransferWatch({
    required this.client,
    required this.transfer,
    required this.firstContact,
    required this.movedAgain,
    required this.days,
  });

  final Client client;
  final ClientTransfer transfer;

  /// The new salesperson's first visit or call after the move; null = none.
  final Visit? firstContact;

  /// The client was moved again afterwards (this row is history).
  final bool movedAgain;

  /// Days from the move to the first contact, or to now when there is none.
  final int days;

  bool get contacted => firstContact != null;

  /// Done with (user request 2026-10-22: visited clients leave the list and
  /// show only as archived): visited or called by the new salesperson, or
  /// moved again since (a newer row follows the client).
  bool get archived => contacted || movedAgain;
}

/// Moves to a salesperson (not to Unassigned) from [since] on, for the
/// people in [people] (as new or previous owner; null = everyone). Not
/// contacted first (longest waiting first), then the rest, newest move first.
List<TransferWatch> transferWatchRows({
  required List<Client> clients,
  required List<Visit> visits,
  required DateTime since,
  required DateTime now,
  Set<String>? people,
}) {
  final byClient = <String, List<Visit>>{};
  for (final v in visits) {
    if (v.checkedInAt != null) (byClient[v.clientId] ??= []).add(v);
  }
  for (final list in byClient.values) {
    list.sort((a, b) => a.checkedInAt!.compareTo(b.checkedInAt!));
  }
  final rows = <TransferWatch>[];
  for (final c in clients) {
    for (final (i, t) in c.transfers.indexed) {
      final at = t.at;
      final to = t.toId;
      if (at == null || to == null || at.isBefore(since) || at.isAfter(now)) continue;
      if (people != null && !people.contains(to) && !people.contains(t.fromId)) continue;
      final first = byClient[c.id]?.where((v) => v.salesExecId == to && !v.checkedInAt!.isBefore(at)).firstOrNull;
      rows.add(TransferWatch(
        client: c,
        transfer: t,
        firstContact: first,
        movedAgain: c.transfers.skip(i + 1).any((later) => later.at != null && later.at!.isAfter(at)),
        days: (first?.checkedInAt ?? now).difference(at).inDays,
      ));
    }
  }
  rows.sort((a, b) {
    if (a.contacted != b.contacted) return a.contacted ? 1 : -1;
    return a.contacted ? b.transfer.at!.compareTo(a.transfer.at!) : a.transfer.at!.compareTo(b.transfer.at!);
  });
  return rows;
}
