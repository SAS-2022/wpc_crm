import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/plan/plan_task.dart';

PlanTask _visit(List<ChecklistItem> items) => PlanTask(
      id: 't',
      ownerId: 'u',
      date: '2026-10-15',
      clientId: 'c',
      clientName: 'Client',
      title: '',
      createdBy: 'k',
      approval: TaskApproval.approved,
      done: false,
      visitId: null,
      checklist: items,
    );

void main() {
  const pay = ChecklistItem(id: '1', text: 'Collect payment', addedBy: 'k');

  test('completing keeps the first done time and can be undone', () {
    final done = pay.complete(done: true, comment: 'Paid 5,000');
    expect(done.done, isTrue);
    expect(done.comment, 'Paid 5,000');
    expect(done.doneAt, isNotNull);
    // Editing the comment of a done task doesn't move its time.
    expect(done.complete(done: true, comment: 'Paid 6,000').doneAt, done.doneAt);
    final undone = done.complete(done: false);
    expect(undone.done, isFalse);
    expect(undone.doneAt, isNull);
    expect(undone.comment, 'Paid 5,000');
  });

  test('map round trip', () {
    final item = pay.complete(done: true, comment: 'ok');
    final back = ChecklistItem.fromMap(item.toMap());
    expect((back.id, back.text, back.addedBy, back.done, back.comment), ('1', 'Collect payment', 'k', true, 'ok'));
    expect(back.doneAt!.millisecondsSinceEpoch, item.doneAt!.millisecondsSinceEpoch);
  });

  test('recent texts: most used first, counted once per use', () {
    const catalogue = ChecklistItem(id: '2', text: 'Deliver catalogue', addedBy: 'k');
    final tasks = [
      _visit([pay, catalogue]),
      _visit([pay]),
      _visit(const []),
    ];
    expect(recentChecklistTexts(tasks), ['Collect payment', 'Deliver catalogue']);
    expect(tasks.first.checklistDone, 0);
    expect(_visit([pay.complete(done: true), catalogue]).checklistDone, 1);
  });
}
