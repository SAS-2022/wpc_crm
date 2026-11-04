import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;

import '../../l10n/app_localizations.dart';
import 'device_health.dart';

// Step-by-step phone setup per maker (2026-11-04, user: the autostart button
// didn't open the right page on some phones, and most staff use Arabic, so
// the manager couldn't find the settings either). Every step is shown in the
// app's language with the other language under it, so a manager reading
// English can guide a phone set to Arabic (and the other way round). Menu
// names differ a little between phone versions — the guide says so.

typedef SetupStep = ({String en, String ar});

/// Kept as the last step for every maker.
const SetupStep _lockInRecents = (
  en: 'Open the recent apps screen, press and hold WPC CRM and choose Lock (padlock), so it isn\'t closed when apps are cleared. Never swipe it away.',
  ar: 'افتح شاشة التطبيقات الأخيرة، اضغط مطولاً على WPC CRM واختر «قفل» (رمز القفل) حتى لا يُغلق عند مسح التطبيقات. لا تسحبه للإغلاق أبداً.',
);

const SetupStep _appInfoUnrestricted = (
  en: 'Settings → Apps → WPC CRM → Battery (App battery usage) → choose "Unrestricted".',
  ar: 'الإعدادات ← التطبيقات ← WPC CRM ← البطارية (استخدام البطارية للتطبيق) ← اختر «غير مقيد».',
);

List<SetupStep> phoneSetupSteps(PhoneBrand brand) => switch (brand) {
      PhoneBrand.xiaomi => const [
          (
            en: 'Settings → Apps → Manage apps → WPC CRM.',
            ar: 'الإعدادات ← التطبيقات ← إدارة التطبيقات ← WPC CRM.',
          ),
          (en: 'Turn on "Autostart".', ar: 'فعّل «التشغيل التلقائي».'),
          (
            en: 'Tap "Battery saver" and choose "No restrictions".',
            ar: 'اضغط «توفير البطارية» واختر «بلا قيود».',
          ),
          _lockInRecents,
        ],
      PhoneBrand.samsung => const [
          _appInfoUnrestricted,
          (
            en: 'Settings → Battery → Background usage limits → "Never sleeping apps" → + → add WPC CRM.',
            ar: 'الإعدادات ← البطارية ← حدود الاستخدام في الخلفية ← «التطبيقات التي لا تخمل أبداً» ← + ← أضف WPC CRM.',
          ),
          (
            en: 'In the same place, make sure WPC CRM is NOT under "Sleeping apps" or "Deep sleeping apps".',
            ar: 'في نفس المكان تأكد أن WPC CRM ليس ضمن «التطبيقات الخاملة» أو «التطبيقات الخاملة بعمق».',
          ),
          _lockInRecents,
        ],
      PhoneBrand.huawei => const [
          (
            en: 'Settings → Battery → App launch (on some Honor phones: Settings → Apps → App launch).',
            ar: 'الإعدادات ← البطارية ← تشغيل التطبيقات (في بعض أجهزة Honor: الإعدادات ← التطبيقات ← تشغيل التطبيقات).',
          ),
          (
            en: 'Find WPC CRM and switch OFF "Manage automatically".',
            ar: 'ابحث عن WPC CRM وأوقف «الإدارة تلقائياً».',
          ),
          (
            en: 'In the window that opens, turn ON "Auto-launch", "Secondary launch" and "Run in background", then OK.',
            ar: 'في النافذة التي تظهر فعّل «التشغيل التلقائي» و«التشغيل الثانوي» و«التشغيل في الخلفية» ثم «موافق».',
          ),
          _lockInRecents,
        ],
      PhoneBrand.oppo => const [
          (
            en: 'Settings → Apps → App management → WPC CRM.',
            ar: 'الإعدادات ← التطبيقات ← إدارة التطبيقات ← WPC CRM.',
          ),
          (
            en: 'Tap "Battery usage" and turn ON "Allow background activity", "Allow foreground activity" and "Allow auto launch".',
            ar: 'اضغط «استخدام البطارية» وفعّل «السماح بالنشاط في الخلفية» و«السماح بالنشاط في المقدمة» و«السماح بالتشغيل التلقائي».',
          ),
          (
            en: 'Older phones: Settings → Battery → WPC CRM → turn off "Optimize" / allow background running.',
            ar: 'الأجهزة الأقدم: الإعدادات ← البطارية ← WPC CRM ← أوقف «التحسين» / اسمح بالعمل في الخلفية.',
          ),
          _lockInRecents,
        ],
      PhoneBrand.vivo => const [
          (
            en: 'Settings → Battery → Background power consumption management → WPC CRM → "Allow" (older phones: "High background power consumption" → turn on WPC CRM).',
            ar: 'الإعدادات ← البطارية ← إدارة استهلاك الطاقة في الخلفية ← WPC CRM ← «السماح» (الأجهزة الأقدم: «استهلاك طاقة عالٍ في الخلفية» ← فعّل WPC CRM).',
          ),
          (
            en: 'Settings → Apps → Autostart (or i Manager → App manager → Autostart manager) → turn on WPC CRM.',
            ar: 'الإعدادات ← التطبيقات ← التشغيل التلقائي (أو i Manager ← مدير التطبيقات ← إدارة التشغيل التلقائي) ← فعّل WPC CRM.',
          ),
          _lockInRecents,
        ],
      PhoneBrand.oneplus => const [
          (
            en: 'Settings → Apps → WPC CRM → Battery usage → turn ON "Allow background activity" (older: Battery optimization → "Don\'t optimize").',
            ar: 'الإعدادات ← التطبيقات ← WPC CRM ← استخدام البطارية ← فعّل «السماح بالنشاط في الخلفية» (الأقدم: تحسين البطارية ← «عدم التحسين»).',
          ),
          (
            en: 'In the same page, turn ON "Allow auto launch".',
            ar: 'في نفس الصفحة فعّل «السماح بالتشغيل التلقائي».',
          ),
          _lockInRecents,
        ],
      PhoneBrand.motorola => const [
          _appInfoUnrestricted,
          (
            en: 'Settings → Battery → turn OFF "Battery Saver" during work (it stops apps in the background).',
            ar: 'الإعدادات ← البطارية ← أوقف «موفّر البطارية» أثناء العمل (يوقف التطبيقات في الخلفية).',
          ),
          _lockInRecents,
        ],
      PhoneBrand.transsion => const [
          (
            en: 'Settings → Apps → Auto-start management (or Phone Master → App auto-start) → turn on WPC CRM.',
            ar: 'الإعدادات ← التطبيقات ← إدارة التشغيل التلقائي (أو Phone Master ← التشغيل التلقائي للتطبيقات) ← فعّل WPC CRM.',
          ),
          _appInfoUnrestricted,
          (
            en: 'Phone Master → Power saving: make sure WPC CRM is not in the list of apps it closes.',
            ar: 'Phone Master ← توفير الطاقة: تأكد أن WPC CRM ليس ضمن التطبيقات التي يغلقها.',
          ),
          _lockInRecents,
        ],
      PhoneBrand.other => const [_appInfoUnrestricted, _lockInRecents],
    };

/// The maker's name as people know it.
String phoneBrandName(PhoneBrand brand) => switch (brand) {
      PhoneBrand.xiaomi => 'Xiaomi / Redmi / POCO',
      PhoneBrand.samsung => 'Samsung',
      PhoneBrand.huawei => 'Huawei / Honor',
      PhoneBrand.oppo => 'Oppo / Realme',
      PhoneBrand.vivo => 'Vivo',
      PhoneBrand.oneplus => 'OnePlus',
      PhoneBrand.motorola => 'Motorola',
      PhoneBrand.transsion => 'Tecno / Infinix / itel',
      PhoneBrand.other => 'Android',
    };

/// The steps for [brand]. On the phone itself (Android) it also has
/// buttons to the app's own settings page (always the right one) and the
/// maker's auto-start page.
Future<void> showPhoneSetupGuide(BuildContext context, PhoneBrand brand) {
  final l10n = AppLocalizations.of(context);
  final arabicUi = Directionality.of(context) == TextDirection.rtl;
  final onPhone = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final steps = phoneSetupSteps(brand);
  return showDialog<void>(
    context: context,
    builder: (dialog) {
      final theme = Theme.of(dialog);
      return AlertDialog(
        title: Text(l10n.phoneSetupGuideTitle(phoneBrandName(brand))),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.phoneSetupGuideNote, style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                for (final (i, step) in steps.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(radius: 12, child: Text('${i + 1}', style: theme.textTheme.labelSmall)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(arabicUi ? step.ar : step.en),
                              const SizedBox(height: 2),
                              // The other language, for whoever helps.
                              Directionality(
                                textDirection: arabicUi ? TextDirection.ltr : TextDirection.rtl,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    arabicUi ? step.en : step.ar,
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          if (onPhone) ...[
            TextButton(onPressed: openAppSettings, child: Text(l10n.openAppInfo)),
            if (brand != PhoneBrand.other)
              TextButton(onPressed: openBackgroundSettings, child: Text(l10n.openAutostart)),
          ],
          FilledButton(onPressed: () => Navigator.pop(dialog), child: Text(l10n.close)),
        ],
      );
    },
  );
}
