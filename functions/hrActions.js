// HR records (2026-11-07, `hr_actions`): when to tell the employee (a record
// sent to them that waits for "Agreed and Accepted" — new, newly sent,
// restored, or asked again after an edit) and when to tell HR (accepted).
// Same idea as `HrAction.awaitingAcceptance` in lib/features/hr/hr_actions.dart.

const awaiting = (d) => !!d && d.sent === true && d.cancelled !== true && !d.acceptedAt;

/** {issued, accepted} for a write from [before] to [after] (null = no doc). */
function hrActionEvents(before, after) {
  return {
    issued: awaiting(after) && !awaiting(before),
    accepted: !!after && !!after.acceptedAt && !(before && before.acceptedAt),
  };
}

module.exports = { hrActionEvents };
