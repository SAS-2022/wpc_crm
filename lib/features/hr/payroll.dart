import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_user.dart';
import 'hr_actions.dart';

// Payroll (user request 2026-11-07): ACTIVE for the accounts in
// [payrollEmails] only (the user's own, the SM) — nobody else, not HR or the
// GM, sees it (user decision 2026-11-07). Salary per employee in Firestore
// `payroll/{uid}` (rules: the same email). Still open: GOSI, overtime pay,
// unpaid leave / absence days, payslips.

const payrollActive = true;

/// Who sees and edits payroll. Same address in firestore.rules `payrollUser()`.
const payrollEmails = {'wissam.b@woodpanelsco.com'};

bool canSeePayroll(AppUser? me) => payrollActive && me != null && me.active && payrollEmails.contains(me.email.toLowerCase());

/// One "other allowance" (named by the user, e.g. Phone, Food).
class OtherAllowance {
  const OtherAllowance({required this.name, required this.amount});

  final String name;
  final double amount;

  Map<String, dynamic> toMap() => {'name': name, 'amount': amount};

  static OtherAllowance? fromMap(Object? m) => m is Map && m['name'] is String
      ? OtherAllowance(name: m['name'] as String, amount: (m['amount'] as num?)?.toDouble() ?? 0)
      : null;
}

/// Saudi practice: a day's wage = the monthly wage ÷ 30.
const payrollDaysInMonth = 30;

/// One employee's monthly salary parts (SAR): basic, home (housing)
/// allowance, transportation and any number of other allowances.
class SalaryStructure {
  const SalaryStructure({this.basic = 0, this.housing = 0, this.transport = 0, this.others = const []});

  final double basic;
  final double housing;
  final double transport;
  final List<OtherAllowance> others;

  static const empty = SalaryStructure();

  double get otherTotal => others.fold(0.0, (a, o) => a + o.amount);

  double get monthly => basic + housing + transport + otherTotal;

  bool get isSet => monthly > 0;

  Map<String, dynamic> toMap() => {
        'basic': basic,
        'housing': housing,
        'transport': transport,
        'others': [for (final o in others) o.toMap()],
      };

  factory SalaryStructure.fromMap(Map<String, dynamic>? d) {
    if (d == null) return empty;
    double n(String k) => (d[k] as num?)?.toDouble() ?? 0;
    return SalaryStructure(
      basic: n('basic'),
      housing: n('housing'),
      transport: n('transport'),
      others: [for (final o in d['others'] as List? ?? const []) ?OtherAllowance.fromMap(o)],
    );
  }

  factory SalaryStructure.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) => SalaryStructure.fromMap(doc.data());

  double get dailyWage => monthly / payrollDaysInMonth;
}

/// A month's pay before GOSI / overtime (not decided yet).
typedef Payslip = ({double gross, double deductions, double rewards, double net});

/// [uid]'s pay for [month] ('yyyy-MM'): the salary, minus deductions and plus
/// rewards from the HR actions of that payroll month (days × daily wage +
/// amounts). Net never goes below 0.
Payslip payslipFor(SalaryStructure salary, List<HrAction> actions, String uid, String month) {
  final e = payEffects(actions, uid, month);
  double round(double v) => (v * 100).roundToDouble() / 100;
  final deductions = round(e.deductedAmount + e.deductedDays * salary.dailyWage);
  final rewards = round(e.rewardAmount + e.rewardDays * salary.dailyWage);
  final net = round(salary.monthly - deductions + rewards);
  return (gross: round(salary.monthly), deductions: deductions, rewards: rewards, net: net < 0 ? 0 : net);
}
