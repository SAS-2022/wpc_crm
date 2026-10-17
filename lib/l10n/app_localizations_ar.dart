// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'WPC CRM';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get signInFailed => 'البريد الإلكتروني أو كلمة المرور غير صحيحة';

  @override
  String get language => 'اللغة';

  @override
  String get noAccessTitle => 'لا توجد صلاحية';

  @override
  String get noAccessBody =>
      'حسابك غير مُعد أو تم إيقافه. تواصل مع مدير المبيعات.';

  @override
  String welcome(String name) {
    return 'مرحباً، $name';
  }

  @override
  String get roleSalesExec => 'مندوب مبيعات';

  @override
  String get roleKam => 'مدير حسابات رئيسية';

  @override
  String get roleSalesManager => 'مدير المبيعات';

  @override
  String get roleGm => 'المدير العام';

  @override
  String get clients => 'العملاء';

  @override
  String get map => 'الخريطة';

  @override
  String get visits => 'الزيارات';

  @override
  String get liveTracking => 'التتبع المباشر';

  @override
  String get dashboard => 'لوحة المعلومات';

  @override
  String get users => 'المستخدمون';

  @override
  String get comingSoon => 'قريباً';

  @override
  String get addUser => 'إضافة مستخدم';

  @override
  String get editUser => 'تعديل مستخدم';

  @override
  String get name => 'الاسم';

  @override
  String get phone => 'الجوال';

  @override
  String get role => 'الدور';

  @override
  String get keyAccountManager => 'مدير الحسابات الرئيسية';

  @override
  String get none => 'لا يوجد';

  @override
  String get active => 'نشط';

  @override
  String get inactive => 'غير نشط';

  @override
  String get save => 'حفظ';

  @override
  String get required => 'مطلوب';

  @override
  String get invalidEmail => 'بريد إلكتروني غير صالح';

  @override
  String get passwordTooShort => '6 أحرف على الأقل';

  @override
  String get saved => 'تم الحفظ';

  @override
  String errorWithMessage(String message) {
    return 'خطأ: $message';
  }

  @override
  String get noUsers => 'لا يوجد مستخدمون بعد';

  @override
  String clientsCount(int count, int green) {
    return '$count عميل · $green تمت زيارتهم مؤخراً';
  }

  @override
  String get allSalespeople => 'كل مندوبي المبيعات';

  @override
  String get unassigned => 'غير مُسند';

  @override
  String get search => 'بحث';

  @override
  String get noClients => 'لا يوجد عملاء';

  @override
  String get importClients => 'استيراد العملاء';

  @override
  String get importPickFile => 'اختر ملف التصدير من أودو (.xlsx أو .csv)';

  @override
  String get importReading => 'جارٍ قراءة الملف…';

  @override
  String importResolving(int done, int total) {
    return 'جارٍ قراءة المواقع $done/$total';
  }

  @override
  String get importNew => 'عملاء جدد';

  @override
  String get importUpdated => 'عملاء محدَّثون';

  @override
  String get importUnchanged => 'بدون تغيير';

  @override
  String get importNoLocation => 'عملاء جدد بدون موقع';

  @override
  String get importUnresolved =>
      'عملاء جدد – رابط الموقع غير مقروء (حُفظوا بدون موقع)';

  @override
  String get importDuplicates => 'نفس الرقم الضريبي، تم الدمج';

  @override
  String get importUnknownSalespeople => 'مندوبو أودو غير المرتبطين بمستخدم';

  @override
  String get importConfirm => 'استيراد';

  @override
  String importDone(int added, int updated) {
    return 'اكتمل الاستيراد: $added مضاف، $updated محدَّث';
  }

  @override
  String get importResolverUnavailable =>
      'تعذّرت قراءة روابط المواقع المختصرة (خدمة الخادم غير متاحة). تم حفظ هؤلاء العملاء بدون موقع.';

  @override
  String get latitude => 'خط العرض';

  @override
  String get longitude => 'خط الطول';

  @override
  String get address => 'العنوان';

  @override
  String get city => 'المدينة';

  @override
  String get mobile => 'الجوال';

  @override
  String get salesExecutive => 'مندوب المبيعات';

  @override
  String get openInMaps => 'فتح في خرائط جوجل';

  @override
  String get editClient => 'تعديل العميل';

  @override
  String get lastVisit => 'آخر زيارة';

  @override
  String get never => 'أبداً';

  @override
  String get tags => 'الوسوم';

  @override
  String get vat => 'الرقم الضريبي';

  @override
  String get odooSalesperson => 'مندوب أودو';

  @override
  String get odooSalespersonName => 'اسم المندوب في أودو';

  @override
  String get odooSalespersonHelp =>
      'كما يظهر في ملف أودو تماماً، مثل Sami Mansour @ Sales';

  @override
  String get details => 'التفاصيل';

  @override
  String get invalidNumber => 'رقم غير صالح';

  @override
  String get mergedContacts => 'جهات اتصال مدمجة';

  @override
  String get noLocation => 'بدون موقع';

  @override
  String get statusAll => 'الكل';

  @override
  String get zoomIn => 'تكبير';

  @override
  String get zoomOut => 'تصغير';

  @override
  String get showAllClients => 'عرض كل العملاء';

  @override
  String get addVisit => 'إضافة زيارة';

  @override
  String get saveVisit => 'حفظ الزيارة';

  @override
  String get visitNotes => 'ما الذي تم في الزيارة';

  @override
  String get visitNotesHint =>
      'المنتجات التي تمت مناقشتها، الطلبات، المتابعات…';

  @override
  String get visitNotesRequired => 'اكتب ما تم في الزيارة';

  @override
  String get visitSaved => 'تم حفظ الزيارة';

  @override
  String get gettingLocation => 'جارٍ تحديد موقعك…';

  @override
  String get locationUnavailable => 'الموقع غير متاح. شغّل GPS وحاول مرة أخرى.';

  @override
  String get locationPermissionDenied =>
      'تم رفض إذن الموقع. اسمح به من إعدادات الجوال.';

  @override
  String locationAccuracy(int meters) {
    return 'دقة GPS ±$meters م';
  }

  @override
  String distanceFromClient(String distance) {
    return '$distance من العميل';
  }

  @override
  String farFromClientWarning(String distance) {
    return 'أنت على بعد $distance من هذا العميل. سيتم تمييز الزيارة بأنها بعيدة عن العميل. هل تريد الحفظ؟';
  }

  @override
  String get mockedLocationWarning =>
      'تم اكتشاف موقع وهمي. سيتم تمييز هذه الزيارة.';

  @override
  String get setClientLocationHere => 'تعيين موقع العميل إلى موقعي الحالي';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get cancel => 'إلغاء';

  @override
  String get saveAnyway => 'حفظ على أي حال';

  @override
  String get myLocation => 'موقعي';

  @override
  String get visitHistory => 'الزيارات';

  @override
  String get noVisits => 'لا توجد زيارات بعد';

  @override
  String farFlag(String distance) {
    return 'بعيد عن العميل ($distance)';
  }

  @override
  String get fakeGpsFlag => 'موقع وهمي';

  @override
  String get emailInUse =>
      'هذا البريد لديه حساب بالفعل. أدخل كلمة المرور المستخدمة في المرة الأولى، أو احذف الحساب من Firebase Console ← Authentication ثم حاول مرة أخرى.';

  @override
  String get delete => 'حذف';

  @override
  String deleteUserTitle(String name) {
    return 'حذف $name؟';
  }

  @override
  String get deleteUserBody =>
      'سيفقد الوصول إلى التطبيق فوراً. سيصبح عملاؤه غير مُسندين، وستبقى زياراته السابقة. لإعادة استخدام البريد نفسه لاحقاً، احذف الحساب أيضاً من Firebase Console ← Authentication.';

  @override
  String get userDeleted => 'تم حذف المستخدم';

  @override
  String savedWithClients(int count) {
    return 'تم الحفظ · تم إسناد $count عميل من أودو';
  }

  @override
  String get pickOnMap => 'اختيار على الخريطة';

  @override
  String get pickOnMapHint => 'حرّك الخريطة حتى يكون الدبوس على موقع العميل';

  @override
  String get useThisLocation => 'استخدام هذا الموقع';

  @override
  String get useMyLocation => 'استخدام موقعي';

  @override
  String get importLocationsOnly => 'استيراد المواقع فقط (اسم العميل + الموقع)';

  @override
  String get chooseFile => 'اختيار ملف';

  @override
  String get locationSheetColumns =>
      'يجب أن يحتوي الملف على صف عناوين يتضمن:\n• اسم العميل (\"Name\" أو \"Complete Name\") أو \"Tax ID\"\n• الموقع: رابط خرائط جوجل (\"Location\" أو \"Google Pin\")، أو نص مثل \"24.71, 46.67\"، أو عمودي \"Latitude\" و\"Longitude\"';

  @override
  String get shortLinksUnavailable =>
      'لا يمكن قراءة روابط خرائط جوجل المختصرة حتى يتم تفعيل خدمة الخادم. استخدم روابط كاملة أو إحداثيات حالياً.';

  @override
  String get locationsToSet => 'عملاء سيتم تعيين موقعهم';

  @override
  String get locationsToReplace => 'عملاء سيتغير موقعهم';

  @override
  String get clientNotFound => 'لا يوجد عميل مطابق';

  @override
  String get sameNameSeveralClients =>
      'الاسم يطابق أكثر من عميل (أضف الرقم الضريبي)';

  @override
  String get locationUnreadable => 'تعذّرت قراءة الموقع';

  @override
  String get replaceExistingLocations =>
      'استبدال المواقع المعيّنة مسبقاً أيضاً';

  @override
  String updateLocationsButton(int count) {
    return 'تحديث $count موقع';
  }

  @override
  String locationsUpdated(int count) {
    return 'تم تحديث $count موقع';
  }

  @override
  String get everyone => 'الجميع';

  @override
  String withKam(String name) {
    return 'مع مدير الحسابات $name';
  }

  @override
  String kamWasThere(String name) {
    return '$name (مدير الحسابات) كان في هذه الزيارة';
  }

  @override
  String markedHoursLater(int hours) {
    return 'تم التمييز بعد $hours ساعة من الزيارة';
  }

  @override
  String get iWasThere => 'كنت في هذه الزيارة';

  @override
  String get remove => 'إزالة';

  @override
  String visitedBy(String name) {
    return 'زيارة بواسطة $name';
  }

  @override
  String get openClient => 'فتح العميل';

  @override
  String get comments => 'التعليقات';

  @override
  String get noComments => 'لا توجد تعليقات بعد';

  @override
  String get writeComment => 'اكتب تعليقاً…';

  @override
  String get send => 'إرسال';

  @override
  String get pasteMapsLink => 'لصق رابط خرائط جوجل';

  @override
  String get pasteMapsLinkHint => 'https://maps.app.goo.gl/… أو 24.63, 46.80';

  @override
  String get linkUnreadable =>
      'تعذّرت قراءة الموقع من هذا الرابط. افتحه في خرائط جوجل، ثم مشاركة ← نسخ الرابط، والصقه.';

  @override
  String get justNow => 'الآن';

  @override
  String minutesAgo(int m) {
    return 'قبل $m دقيقة';
  }

  @override
  String hoursAgo(int h) {
    return 'قبل $h ساعة';
  }

  @override
  String liveUpdated(String ago) {
    return 'مباشر · آخر تحديث $ago';
  }

  @override
  String get liveGpsOff => 'متصل، لكن GPS مغلق';

  @override
  String liveNoFix(String ago) {
    return 'متصل، لا يوجد موقع جديد منذ $ago';
  }

  @override
  String liveOffline(String ago) {
    return 'غير متصل · آخر ظهور $ago';
  }

  @override
  String get liveNotAlways =>
      'الموقع غير مضبوط على \"السماح طوال الوقت\" في هذا الجوال';

  @override
  String get noTrackedStaff => 'لا يوجد موظفو مبيعات لعرضهم';

  @override
  String get noLocationYet => 'لم يصل أي موقع بعد';

  @override
  String get showEveryone => 'عرض الجميع';

  @override
  String get callPhone => 'اتصال';

  @override
  String get sharingOn => 'مشاركة الموقع مفعّلة';

  @override
  String get sharingIncomplete => 'مشاركة الموقع مفعّلة، لكنها تحتاج إلى ضبط';

  @override
  String get sharingOff => 'مشاركة الموقع متوقفة';

  @override
  String get issueGpsOff => 'GPS مغلق';

  @override
  String get issueLocationDenied => 'إذن الموقع غير مسموح';

  @override
  String get issueNotAlways => 'اضبط الموقع على \"السماح طوال الوقت\"';

  @override
  String get issueNotifications => 'اسمح بالإشعارات (لاستمرار المشاركة)';

  @override
  String get issueBattery => 'أوقف تحسين البطارية لهذا التطبيق';

  @override
  String get fix => 'إصلاح';

  @override
  String get xiaomiHint =>
      'في أجهزة شاومي أو هواوي أو أوبو افتح أيضاً إعدادات التطبيق ← فعّل التشغيل التلقائي واضبط توفير البطارية على \"بلا قيود\".';

  @override
  String get appSettings => 'إعدادات التطبيق';

  @override
  String get home => 'الرئيسية';

  @override
  String get more => 'المزيد';

  @override
  String get myPlan => 'خطتي';

  @override
  String planOf(String name) {
    return 'خطة $name';
  }

  @override
  String get addToTodaysPlan => 'إضافة إلى خطة اليوم';

  @override
  String get onTodaysPlan => 'في خطة اليوم';

  @override
  String get moveToSalesperson => 'نقل إلى مندوب آخر';

  @override
  String get clientType => 'النوع';

  @override
  String get clientTypeCompany => 'شركة';

  @override
  String get clientTypeIndividual => 'فرد';

  @override
  String get companyId => 'رقم السجل التجاري';

  @override
  String get notSet => 'غير محدد';

  @override
  String get importFillOnly => 'تعبئة الحقول الناقصة فقط';

  @override
  String get importFillOnlyHint =>
      'الشخص المسؤول، شركة / فرد، ورقم السجل التجاري للعملاء الحاليين، فقط إذا كانت فارغة. لا يتغير أي شيء آخر ولا يُضاف عملاء جدد.';

  @override
  String get filters => 'الفلاتر';

  @override
  String get clearFilters => 'مسح الكل';

  @override
  String get clientTags => 'تصنيفات العملاء';

  @override
  String get tagFilterAny =>
      'يعرض العملاء الذين لديهم أي من التصنيفات المختارة.';

  @override
  String tagClientsTitle(int count) {
    return 'تصنيفات $count عميل';
  }

  @override
  String get tagClientsHelp =>
      'اضغط على التصنيف مرة لإضافته ومرتين لإزالته. التصنيفات الأخرى تبقى كما هي.';

  @override
  String get tagWillAdd => 'ستتم إضافته';

  @override
  String get tagWillRemove => 'ستتم إزالته';

  @override
  String tagsUpdatedCount(int count) {
    return 'تم تحديث التصنيفات لـ $count عميل';
  }

  @override
  String get addTag => 'إضافة تصنيف';

  @override
  String get editTag => 'تعديل التصنيف';

  @override
  String get tagNameEn => 'الاسم (إنجليزي)';

  @override
  String get tagNameAr => 'الاسم (عربي)';

  @override
  String get tagDuplicate => 'يوجد تصنيف بهذا الاسم';

  @override
  String deleteTagTitle(String name) {
    return 'حذف \"$name\"؟';
  }

  @override
  String deleteTagBody(int count) {
    return 'ستتم إزالته من $count عميل. لا يمكن التراجع عن ذلك.';
  }

  @override
  String get clientTagsHelp =>
      'التصنيفات تصف نشاط العميل (مصنع، معرض، …). استخدمها لتصفية قائمة العملاء والخريطة. صنّف العملاء من شاشة التعديل، أو اختر عدة عملاء من القائمة.';

  @override
  String clientsCountShort(int count) {
    return '$count عميل';
  }

  @override
  String get addToPlan => 'إضافة إلى الخطة';

  @override
  String get today => 'اليوم';

  @override
  String get nothingPlanned => 'لا يوجد شيء مخطط لهذا اليوم';

  @override
  String planSummary(int done, int total, int pending) {
    return 'تم $done من $total · $pending بانتظار الموافقة';
  }

  @override
  String get waitingApproval => 'بانتظار الموافقة';

  @override
  String get rejected => 'مرفوض';

  @override
  String get done => 'تم';

  @override
  String get toDo => 'مطلوب';

  @override
  String get approve => 'موافقة';

  @override
  String get reject => 'رفض';

  @override
  String get chooseClient => 'اختر عميلاً';

  @override
  String get clientVisit => 'زيارة عميل';

  @override
  String get task => 'مهمة';

  @override
  String get noteOptional => 'ملاحظة (اختياري)';

  @override
  String get taskDescription => 'ما المطلوب إنجازه';

  @override
  String get needsApprovalHint =>
      'سيوافق مدير الحسابات على هذا قبل احتسابه في خطتك.';

  @override
  String get todaysPlan => 'خطة اليوم';

  @override
  String get openPlan => 'فتح الخطة';

  @override
  String monthProgress(String month) {
    return 'التقدم · $month';
  }

  @override
  String visitsOfTarget(int count, int target) {
    return '$count من $target زيارة';
  }

  @override
  String visitsThisMonth(int count) {
    return '$count زيارة هذا الشهر';
  }

  @override
  String get planTasksDone => 'مهام مخططة منجزة';

  @override
  String get missedTasks => 'مهام فائتة';

  @override
  String get rideAlongs => 'زيارات مع مدير الحسابات';

  @override
  String get flaggedVisits => 'زيارات مميزة بتنبيه';

  @override
  String get coverage => 'تغطية العملاء';

  @override
  String waitingForYourApproval(int count) {
    return 'بانتظار موافقتك ($count)';
  }

  @override
  String get myTeam => 'فريقي';

  @override
  String teamLine(int done, int total, String visits) {
    return 'اليوم $done/$total · زيارات الشهر $visits';
  }

  @override
  String get noKamHint =>
      'لم يتم تعيين مدير حسابات لك بعد، لذا يوافق مدير المبيعات على خطتك.';

  @override
  String get monthlyVisitTarget => 'هدف الزيارات الشهري';

  @override
  String get monthlyVisitTargetHelp => 'اتركه فارغاً بدون هدف';

  @override
  String get paceOnTrack => 'على المسار';

  @override
  String get paceSlightlyBehind => 'متأخر قليلاً';

  @override
  String get paceBehind => 'متأخر';

  @override
  String get completedVisits => 'الزيارات المنجزة';

  @override
  String get target => 'الهدف';

  @override
  String get targetPace => 'وتيرة الهدف';

  @override
  String barTooltip(String name, int done, int target, int expected) {
    return '$name: $done زيارة · الهدف $target · المتوقع حتى اليوم $expected';
  }

  @override
  String get thisMonth => 'هذا الشهر';

  @override
  String get lastMonth => 'الشهر الماضي';

  @override
  String get customRange => 'تواريخ مخصصة';

  @override
  String get noTargetSet => 'لا يوجد هدف';

  @override
  String coverageDetail(int green, int total) {
    return '$green من $total عميل تمت زيارتهم مؤخراً';
  }

  @override
  String get planCompletion => 'إنجاز الخطة';

  @override
  String tasksDetail(int done, int total) {
    return '$done من $total مهمة مخططة';
  }

  @override
  String get flaggedDetail => 'بعيدة عن العميل أو موقع وهمي';

  @override
  String get visitsVsTarget => 'الزيارات مقابل الهدف';

  @override
  String get progressVsTarget => 'التقدم مقابل وتيرة الهدف';

  @override
  String get statusRecent => 'تمت زيارته مؤخراً';

  @override
  String get statusDueSoon => 'مستحق قريباً';

  @override
  String get statusOverdue => 'متأخر';

  @override
  String get plannedToday => 'مخطط اليوم';

  @override
  String get category => 'التصنيف';

  @override
  String categoryName(String c) {
    return 'التصنيف $c';
  }

  @override
  String categoryRule(String c, int green, int yellow) {
    return '$c · أخضر حتى $green يوم، أصفر حتى $yellow يوم';
  }

  @override
  String get visitStatus => 'حالة الزيارة';

  @override
  String get visitFrequency => 'وتيرة الزيارات';

  @override
  String get visitFrequencyHelp =>
      'عدد الأيام منذ آخر زيارة قبل أن يتحول العميل إلى الأصفر ثم الأحمر. العملاء الذين لم تتم زيارتهم يظهرون بالأحمر.';

  @override
  String get greenUpTo => 'أخضر حتى (أيام)';

  @override
  String get yellowUpTo => 'أصفر حتى (أيام)';

  @override
  String get yellowAfterGreen => 'يجب أن يكون أكبر من الأخضر';

  @override
  String get redAfter => 'أحمر بعد ذلك';

  @override
  String get importDefaultCategory =>
      'التصنيف للعملاء الجدد (إذا لم يحتوِ الملف على عمود التصنيف)';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get noNotifications => 'لا توجد إشعارات';

  @override
  String get markAllRead => 'تعليم الكل كمقروء';

  @override
  String notifPlanSubmitted(String name, int count, String day) {
    return 'أضاف $name $count عنصر إلى خطته ليوم $day – بانتظار موافقتك';
  }

  @override
  String notifPlanApproved(String name, String day) {
    return 'وافق $name على خطتك ليوم $day';
  }

  @override
  String notifPlanRejected(String name, String day) {
    return 'رفض $name عنصراً في خطتك ليوم $day';
  }

  @override
  String notifPlanChanged(String name, String day) {
    return 'عدّل $name خطتك ليوم $day';
  }

  @override
  String planUpdated(int count) {
    return 'تمت إضافة $count إلى الخطة';
  }

  @override
  String planSentForApproval(int count) {
    return 'تمت إضافة $count وإرسالها للموافقة';
  }

  @override
  String saveCount(int count) {
    return 'حفظ ($count)';
  }

  @override
  String get showOnMap => 'عرض على الخريطة';

  @override
  String get share => 'مشاركة';

  @override
  String shareTitle(String name, String day) {
    return '$name – خطة يوم $day';
  }

  @override
  String get tasks => 'المهام';

  @override
  String get route => 'المسار';

  @override
  String approveAll(int count) {
    return 'الموافقة على الكل ($count)';
  }

  @override
  String get removeFromPlan => 'إزالة من الخطة';

  @override
  String planClientsWithoutLocation(int count) {
    return '$count من العملاء المخططين بدون موقع ولا يظهرون على الخريطة';
  }

  @override
  String get clear => 'مسح';

  @override
  String get clearPlanTitle => 'مسح الخطة؟';

  @override
  String clearPlanUnapproved(int count) {
    return 'إزالة $count عنصر لم تتم الموافقة عليها بعد؟';
  }

  @override
  String clearPlanAll(int count) {
    return 'إزالة جميع العناصر ($count) من خطة هذا اليوم؟ سيتم إشعار مندوب المبيعات.';
  }

  @override
  String get addClient => 'إضافة عميل';

  @override
  String get clientName => 'اسم العميل';

  @override
  String get clientAdded => 'تمت إضافة العميل';

  @override
  String get possibleDuplicate => 'قد يكون العميل موجوداً';

  @override
  String possibleDuplicateBody(String name) {
    return '\"$name\" موجود في التطبيق بنفس الاسم أو الرقم الضريبي. هل تريد إضافة عميل جديد على أي حال؟';
  }

  @override
  String get addAnyway => 'إضافة على أي حال';

  @override
  String get contact => 'التواصل';

  @override
  String get contactPerson => 'الشخص المسؤول';

  @override
  String get locationSection => 'الموقع';

  @override
  String get salesSection => 'المبيعات';

  @override
  String get notes => 'ملاحظات';

  @override
  String get directions => 'الاتجاهات';

  @override
  String get addedInApp => 'أضيف من التطبيق';

  @override
  String get noContactDetails => 'لا توجد بيانات تواصل بعد';

  @override
  String get coordinates => 'الإحداثيات';

  @override
  String daysAgo(int days) {
    return 'قبل $days يوم';
  }

  @override
  String get importLinkedContacts => 'أشخاص تواصل مرتبطون بشركة';

  @override
  String get accountSection => 'الحساب';

  @override
  String get receivable => 'مستحق لنا';

  @override
  String get payable => 'مستحق علينا';

  @override
  String get street => 'الشارع';

  @override
  String get region => 'المنطقة';

  @override
  String get country => 'الدولة';

  @override
  String get teamPlansToday => 'خطط الفريق اليوم';

  @override
  String get attachments => 'الصور والملفات';

  @override
  String get noAttachments => 'لا توجد صور أو ملفات بعد';

  @override
  String get addAttachment => 'إضافة صورة أو ملف';

  @override
  String get takePhoto => 'التقاط صورة';

  @override
  String get chooseFromGallery => 'اختيار من المعرض';

  @override
  String get uploading => 'جارٍ الرفع…';

  @override
  String deleteAttachmentConfirm(String name) {
    return 'حذف $name؟';
  }

  @override
  String fileTooLarge(String name) {
    return 'حجم $name أكبر من 20 ميغابايت';
  }

  @override
  String visitPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صورة أو ملف',
      many: '$count صورة أو ملفاً',
      few: '$count صور أو ملفات',
      two: 'صورتان أو ملفان',
      one: 'صورة أو ملف واحد',
      zero: 'لا توجد صور',
    );
    return '$_temp0';
  }

  @override
  String addUnmatchedClients(int count) {
    return 'إضافة $count من الصفوف غير المطابقة كعملاء جدد';
  }

  @override
  String newClientsAssignedTo(String name, int noLocation) {
    return 'مُسند إلى $name · $noLocation بدون موقع';
  }

  @override
  String importApplyButton(int added, int updated) {
    return 'إضافة $added عميل · تحديث $updated موقع';
  }

  @override
  String importApplyDone(int added, int updated) {
    return 'تمت إضافة $added عميل · تحديث $updated موقع';
  }

  @override
  String get newVisit => 'زيارة جديدة';

  @override
  String get searchVisits => 'ابحث باسم العميل أو الملاحظات';

  @override
  String get yesterday => 'أمس';

  @override
  String get thisWeek => 'هذا الأسبوع';

  @override
  String get allTime => 'الكل';

  @override
  String get visitsTotal => 'الزيارات';

  @override
  String get withKamCount => 'مع مدير الحسابات';

  @override
  String get noVisitsHint => 'اضغط \"زيارة جديدة\" لتسجيل زيارة لدى عميل';

  @override
  String get noMatchingVisits => 'لا توجد زيارات تطابق هذه الفلاتر';

  @override
  String get planProgress => 'تقدم الخطة';

  @override
  String get missed => 'فائتة';

  @override
  String get noPlanItems => 'لا توجد عناصر في الخطة لهذه الفترة';

  @override
  String get clientVisitsCard => 'زيارات العملاء';

  @override
  String get visitedLabel => 'تمت زيارتهم';

  @override
  String get notVisitedYet => 'لم تتم زيارتهم بعد';

  @override
  String get noAssignedClients => 'لا يوجد عملاء مسندون';

  @override
  String ofTotal(int total) {
    return 'من $total';
  }

  @override
  String visitedOfClients(int visited, int total, int pending) {
    return 'تمت زيارة $visited من $total عميل · $pending متبقٍ';
  }

  @override
  String get reports => 'التقارير';

  @override
  String get tripDetails => 'تفاصيل الرحلة';

  @override
  String get routeHistory => 'سجل المسار';

  @override
  String get teamPerformance => 'أداء الفريق';

  @override
  String get person => 'الشخص';

  @override
  String get clientsVisitedColumn => 'العملاء الذين تمت زيارتهم';

  @override
  String get ownClientsVisited => 'زيارة عملائه';

  @override
  String get onSchedule => 'ضمن الموعد';

  @override
  String unvisitedInPeriod(int count) {
    return 'لم تتم زيارتهم في هذه الفترة ($count)';
  }

  @override
  String get allClientsVisited => 'تمت زيارة جميع العملاء في هذه الفترة';

  @override
  String showAllCount(int count) {
    return 'عرض الكل ($count)';
  }

  @override
  String get importHistory => 'عمليات الاستيراد';

  @override
  String get noImports => 'لا توجد عمليات استيراد بعد';

  @override
  String importBatchLine(int added, int updated, int unchanged) {
    return '$added جديد · $updated محدّث · $unchanged بدون تغيير';
  }

  @override
  String importedByName(String name) {
    return 'بواسطة $name';
  }

  @override
  String get distance => 'المسافة';

  @override
  String get firstLocation => 'أول موقع';

  @override
  String get lastLocation => 'آخر موقع';

  @override
  String locationPointsCount(int count) {
    return '$count نقطة';
  }

  @override
  String fakeGpsPoints(int count) {
    return '$count نقطة GPS مزيفة';
  }

  @override
  String get noRouteData => 'لا توجد مواقع مسجلة لهذا اليوم';

  @override
  String get choosePerson => 'اختر شخصًا';

  @override
  String get previousDay => 'اليوم السابق';

  @override
  String get nextDay => 'اليوم التالي';

  @override
  String trackingGaps(int count) {
    return '$count انقطاع في التتبع';
  }

  @override
  String get hiddenClients => 'العملاء المخفيون';

  @override
  String get hideClient => 'إخفاء العميل';

  @override
  String get unhideClient => 'إظهار مجددًا';

  @override
  String get hideClientTitle => 'إخفاء هذا العميل؟';

  @override
  String get hideClientBody =>
      'سيتم استبعادهم من قوائم العملاء والخريطة والخطط والزيارات وجميع الإحصائيات للجميع. تبقى زياراتهم وبياناتهم محفوظة. لإظهارهم مجددًا استخدم تصفية \"المخفيون\" في العملاء.';

  @override
  String get clientHiddenBanner => 'مخفي: مستبعد من القوائم والإحصائيات';

  @override
  String get clientHidden => 'تم إخفاء العميل';

  @override
  String get clientUnhidden => 'تم إظهار العميل مجددًا';

  @override
  String get selectClients => 'تحديد العملاء';

  @override
  String selectedCount(int count) {
    return 'تم تحديد $count';
  }

  @override
  String get selectAll => 'تحديد الكل';

  @override
  String hideClientsTitle(int count) {
    return 'إخفاء $count عميل؟';
  }

  @override
  String clientsHiddenCount(int count) {
    return 'تم إخفاء $count عميل';
  }

  @override
  String clientsUnhiddenCount(int count) {
    return 'تم إظهار $count عميل مجددًا';
  }

  @override
  String get liveOffDuty => 'خارج الدوام · لا تتم مشاركة الموقع';

  @override
  String get workHours => 'ساعات العمل';

  @override
  String get workHoursHelp =>
      'تتم مشاركة مواقع الفريق الميداني في هذه الأيام والساعات فقط (بتوقيت السعودية). خارجها لا يُرسل أي موقع ويظهر الموظفون خارج الدوام.';

  @override
  String get workDays => 'أيام العمل';

  @override
  String get startTime => 'البداية';

  @override
  String get endTime => 'النهاية';

  @override
  String get endAfterStart => 'يجب أن يكون وقت النهاية بعد وقت البداية';

  @override
  String get transferClients => 'نقل';

  @override
  String transferClientsTitle(int count) {
    return 'نقل $count عميل إلى';
  }

  @override
  String get transferClientTitle => 'نقل العميل إلى';

  @override
  String get transferPlanNote =>
      'تُحذف عناصر الخطة المفتوحة لهؤلاء العملاء من اليوم فصاعداً من خطة المندوب الحالي. تبقى الخطط والزيارات السابقة كما هي.';

  @override
  String transferSkipped(int count) {
    return '$count من العملاء المحددين ليسوا ضمن فريقك وسيتم تجاوزهم.';
  }

  @override
  String get transferNoneAllowed =>
      'لا ينتمي أي من العملاء المحددين إلى فريقك.';

  @override
  String get noTransferTargets => 'لا يوجد مندوبو مبيعات للنقل إليهم';

  @override
  String clientsTransferredCount(int count, String name) {
    return 'تم نقل $count عميل إلى $name';
  }

  @override
  String get transferHistory => 'سجل النقل';

  @override
  String transferBy(String name, String when) {
    return 'بواسطة $name · $when';
  }

  @override
  String notifClientsTransferredIn(String name, int count) {
    return 'نقل $name $count عميل إليك';
  }

  @override
  String notifClientsTransferredOut(String name, int count, String other) {
    return 'نقل $name $count من عملائك إلى $other';
  }

  @override
  String get teamPlans => 'خطط الفريق';

  @override
  String get noTeamMembers => 'لا يوجد أعضاء في الفريق بعد';

  @override
  String get viewAll => 'عرض الكل';

  @override
  String notifGpsOff(String name) {
    return 'أوقف $name خدمة الموقع (GPS)';
  }

  @override
  String notifLocationDenied(String name) {
    return 'ألغى $name إذن الموقع للتطبيق';
  }

  @override
  String notifLocationNotAlways(String name) {
    return 'سمح $name بالموقع أثناء استخدام التطبيق فقط – يتوقف التتبع في الخلفية';
  }

  @override
  String notifBatteryOptimized(String name) {
    return 'فعّل $name تحسين البطارية لتطبيق WPC CRM – قد يتوقف التتبع';
  }

  @override
  String get close => 'إغلاق';

  @override
  String get showLocation => 'عرض الموقع';

  @override
  String get deleteVisitTitle => 'حذف الزيارة';

  @override
  String get deleteVisitBody =>
      'سيتم حذف الزيارة وتعليقاتها وصورها وملفاتها لدى الجميع، وتعود عناصر الخطة التي أنجزتها مفتوحة. لا يمكن التراجع عن ذلك.';

  @override
  String get visitDeleted => 'تم حذف الزيارة';

  @override
  String get colourBy => 'التلوين حسب';

  @override
  String get salesperson => 'المندوب';

  @override
  String notifPlanItemsAdded(String name, int count, String day) {
    return 'أضاف $name $count عنصر إلى خطتك ليوم $day';
  }

  @override
  String notifTrackingOffline(String name) {
    return '$name غير متصل منذ أكثر من 30 دقيقة خلال ساعات العمل';
  }

  @override
  String get trackingLog => 'سجل التتبع';

  @override
  String get trackingLogEmpty => 'لا توجد تغييرات مسجلة لهذا اليوم';

  @override
  String get logOffline => 'انقطع الاتصال';

  @override
  String get logOnline => 'عاد متصلاً';

  @override
  String get logGpsOff => 'تم إيقاف GPS';

  @override
  String get logGpsOn => 'تم تشغيل GPS';

  @override
  String get logOnDuty => 'بدأت ساعات العمل';

  @override
  String get logOffDuty => 'انتهت ساعات العمل';

  @override
  String get logBatteryOn => 'تم تفعيل تحسين البطارية';

  @override
  String get logBatteryOff => 'تم إيقاف تحسين البطارية';

  @override
  String logPermission(String value) {
    return 'إذن الموقع: $value';
  }

  @override
  String get permissionAlways => 'السماح طوال الوقت';

  @override
  String get permissionWhileInUse => 'أثناء استخدام التطبيق فقط';

  @override
  String get permissionDenied => 'مرفوض';

  @override
  String logLasted(String duration) {
    return 'لمدة $duration';
  }

  @override
  String durationMinutes(int m) {
    return '$m دقيقة';
  }

  @override
  String durationHoursMinutes(int h, int m) {
    return '$h س $m د';
  }

  @override
  String get addTask => 'إضافة مهمة';

  @override
  String get commentOptional => 'تعليق (اختياري)';

  @override
  String get markDone => 'تم';

  @override
  String get markNotDone => 'لم تتم';

  @override
  String get visitTasksLabel => 'مهام عند العميل';

  @override
  String checklistProgress(int done, int total) {
    return '$done/$total مهام';
  }

  @override
  String get possibleDuplicates => 'عملاء مكررون محتملون';

  @override
  String get dupSameVat => 'نفس الرقم الضريبي';

  @override
  String get dupSameName => 'نفس الاسم';

  @override
  String get dupSamePhone => 'نفس رقم الهاتف';

  @override
  String get dupSimilarName => 'اسم مشابه';

  @override
  String get dupNearby => 'نفس المكان';

  @override
  String get noDuplicates => 'لا يوجد عملاء مكررون محتملون';

  @override
  String get notDuplicates => 'ليسوا مكررين';

  @override
  String get markedNotDuplicates => 'تم تمييزهم كعملاء مختلفين';

  @override
  String get mergeClients => 'دمج';

  @override
  String get mergeClientsTitle => 'دمج العملاء';

  @override
  String get mergeHint =>
      'اختر العميل الذي سيبقى. سيُحذف الآخرون: تنتقل زياراتهم وبنود الخطط والملفات وجهات الاتصال والأسماء إلى العميل المتبقي، وتُكمل بياناته الفارغة منهم. يبقى اسم العميل المتبقي وفئته ومندوبه. لا يمكن التراجع عن ذلك.';

  @override
  String get mergeKeep => 'إبقاء هذا العميل';

  @override
  String mergeCount(int count) {
    return 'دمج $count';
  }

  @override
  String clientsMerged(int count) {
    return 'تم دمج $count عملاء في عميل واحد';
  }

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get personalInfo => 'المعلومات الشخصية';

  @override
  String get emailChangeByAdmin =>
      'لتغيير بريدك الإلكتروني أو دورك، تواصل مع مدير المبيعات.';

  @override
  String get changePassword => 'تغيير كلمة المرور';

  @override
  String get currentPassword => 'كلمة المرور الحالية';

  @override
  String get newPassword => 'كلمة المرور الجديدة';

  @override
  String get confirmNewPassword => 'تأكيد كلمة المرور الجديدة';

  @override
  String get passwordsDontMatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get wrongCurrentPassword => 'كلمة المرور الحالية غير صحيحة';

  @override
  String get passwordChanged => 'تم تغيير كلمة المرور';

  @override
  String get resetPasswordByEmail => 'إعادة تعيين كلمة المرور عبر البريد';

  @override
  String get resetPasswordInfo =>
      'نسيت كلمة المرور الحالية؟ سنرسل لك رابطاً عبر البريد لتعيين كلمة جديدة.';

  @override
  String get sendResetLink => 'إرسال الرابط';

  @override
  String resetEmailSent(String email) {
    return 'تم إرسال رابط إعادة التعيين إلى $email';
  }

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get resetEmailSentIfExists =>
      'إذا كان لهذا البريد حساب، فقد أُرسل إليه رابط إعادة التعيين.';

  @override
  String get tooManyAttempts => 'محاولات كثيرة. حاول لاحقاً.';

  @override
  String get updateRequiredTitle => 'التحديث مطلوب';

  @override
  String get updateRequiredBody =>
      'يتوفر إصدار جديد من WPC CRM. يرجى تحديث التطبيق للمتابعة.';

  @override
  String get updateNow => 'حدّث الآن';
}
