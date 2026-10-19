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
  String get visitAlreadyTodayTitle => 'تمت زيارته اليوم';

  @override
  String visitAlreadyToday(String time) {
    return 'لقد حفظت زيارة لهذا العميل اليوم الساعة $time. زيارة واحدة فقط لكل عميل في اليوم: افتحها لإضافة صور أو تعليقات.';
  }

  @override
  String get openVisit => 'فتح الزيارة';

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
  String get openClient => 'فتح';

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
  String get visitDetails => 'تفاصيل الزيارة';

  @override
  String get otherPhoneTitle => 'موقعك يُشارك من هاتف آخر';

  @override
  String get otherPhoneBody =>
      'هاتف آخر مسجّل الدخول بحسابك يشارك موقعك، لذلك لا يرسل هذا الهاتف شيئًا. إذا كان هذا هو هاتف عملك، اضغط \"استخدم هذا الهاتف\".';

  @override
  String get useThisPhone => 'استخدم هذا الهاتف';

  @override
  String otherTrackIgnored(int count) {
    return 'تم تجاهل $count نقطة من هاتف آخر';
  }

  @override
  String reportNewClients(int count) {
    return 'عملاء جدد ($count)';
  }

  @override
  String get reportNoNewClients => 'لم تتم إضافة عملاء في هذه الفترة.';

  @override
  String get reportAddedInApp => 'أضيفوا في التطبيق';

  @override
  String get reportImported => 'مستوردون';

  @override
  String reportAddedBy(String name) {
    return 'أضافه $name';
  }

  @override
  String get reportRouting => 'أداء المسارات والكفاءة';

  @override
  String get reportNoRoutingDays =>
      'لا يوجد يوم فيه زيارتان أو أكثر في هذه الفترة.';

  @override
  String get reportAvgEfficiency => 'متوسط الكفاءة';

  @override
  String get reportDaysCounted => 'الأيام';

  @override
  String get reportVisitsPerDay => 'زيارات / يوم';

  @override
  String get reportShortestOrderDays => 'أقصر ترتيب';

  @override
  String get reportExtraDistance => 'مسافة إضافية';

  @override
  String get reportNeededTook => 'المطلوب / الفعلي';

  @override
  String get reportLowestDays => 'أقل الأيام';

  @override
  String get reportRoutingHelp =>
      'تُحسب الأيام التي فيها زيارتان أو أكثر. الكفاءة = الوقت المطلوب (أقصر مسار بين نفس العملاء + 30 دقيقة لكل زيارة) ÷ الوقت من أول زيارة إلى آخر زيارة، بحد أقصى 100%. المسافة الإضافية = الكيلومترات المستقيمة الزائدة عن أقصر ترتيب بين الزيارات.';

  @override
  String get reportCatalogs => 'توزيع الكتالوجات';

  @override
  String get reportNoCatalogs =>
      'لم يتم تسليم كتالوجات أو ستاندات في هذه الفترة.';

  @override
  String get reportTotal => 'الإجمالي';

  @override
  String get reportClientsReached => 'العملاء';

  @override
  String get reportCatalogsDue => 'عملاء مستحقون لواحد جديد';

  @override
  String reportDueNever(String item, int due, int never) {
    return '$item: $due مستحق · $never لم يُسلَّم';
  }

  @override
  String get reportCatalogsHelp =>
      'من التسليمات في الزيارات والمسجّلة في صفحات العملاء، محسوبة لمن سلّمها. اضغط على صنف لرؤية العملاء المستحقين.';

  @override
  String get givenSwitchCatalog => 'كتالوج سواتش';

  @override
  String get givenBookletCatalog => 'كتالوج كتيّب';

  @override
  String get givenDisplayStand => 'ستاند عرض';

  @override
  String get givenA4Samples => 'عينات A4';

  @override
  String get itemsGiven => 'الكتالوجات والستاندات المسلّمة';

  @override
  String get givenNever => 'لم يُسلَّم';

  @override
  String givenLast(int qty, String date) {
    return 'آخر مرة: $qty في $date';
  }

  @override
  String givenTotal(int count) {
    return '$count إجمالًا';
  }

  @override
  String givenDueOn(String date) {
    return 'الجديد مستحق في $date';
  }

  @override
  String get givenDue => 'مستحق';

  @override
  String get givenDueSoon => 'مستحق قريبًا';

  @override
  String get givenItemsSettings => 'الكتالوجات والستاندات';

  @override
  String get givenItemsHelp =>
      'بعد كم يومًا يجب أن يحصل العميل على واحد جديد. العملاء الذين تجاوزوا ذلك يظهر لهم \"مستحق\" في صفحتهم وعند تسجيل الزيارة وفي الفلتر.';

  @override
  String get givenEveryDaysSuffix => 'يوم';

  @override
  String get givenDueFilter => 'مستحق كتالوج / ستاند جديد';

  @override
  String get givenHistory => 'السجل';

  @override
  String get givenRecord => 'تسجيل كتالوج / ستاند مسلّم';

  @override
  String get givenRecordedByHand => 'مسجّل يدويًا';

  @override
  String get givenAtVisit => 'في زيارة';

  @override
  String get givenOn => 'تاريخ التسليم';

  @override
  String get quantity => 'الكمية';

  @override
  String get notAssignedTitle => 'غير مُسند إلى مندوب مبيعات';

  @override
  String notAssignedBody(int count, String names) {
    return '$count من العملاء المختارين بدون مندوب مبيعات، فلا يمكن إضافتهم إلى خطة: $names. انقلهم إلى أحد المندوبين أولًا.';
  }

  @override
  String get moveThemFirst => 'نقلهم';

  @override
  String planTheOthers(int count) {
    return 'خطط للـ $count الباقين';
  }

  @override
  String planNotAllowed(int count) {
    return '$count عملاء يتبعون أشخاصًا خارج فريقك ولن تتم إضافتهم.';
  }

  @override
  String planSelectedTitle(int count) {
    return 'إضافة $count عملاء إلى الخطط';
  }

  @override
  String get planSelectedHint =>
      'يُضاف كل عميل إلى خطة المندوب الذي يتبعه، معتمدًا، ويتم إشعاره.';

  @override
  String plannedFromSelection(int count, int plans) {
    return 'تمت إضافة $count عملاء إلى $plans خطط';
  }

  @override
  String alreadyOnPlanCount(int count) {
    return '$count موجودون في الخطة مسبقًا';
  }

  @override
  String get dupSameCompanyId => 'نفس رقم السجل التجاري';

  @override
  String get duplicatesFoundBody => 'هؤلاء العملاء يشبهون العميل الذي تضيفه:';

  @override
  String get duplicateOverrideHint =>
      'إذا تحققت وكان عميلًا مختلفًا، يمكنك إضافته.';

  @override
  String get duplicateAskManager =>
      'إذا كان عميلًا مختلفًا، اطلب من مدير المبيعات إضافته.';

  @override
  String get notDuplicateAdd => 'ليس مكررًا – أضف';

  @override
  String get useThisClient => 'استخدم هذا العميل';

  @override
  String addNewClientNamed(String name) {
    return 'إضافة \"$name\" كعميل جديد';
  }

  @override
  String get selectClientsToMove => 'اختيار عملاء للتخطيط أو النقل';

  @override
  String get tapPinsToSelect => 'اضغط على الدبابيس لاختيار العملاء';

  @override
  String get selectSeveralToMove => 'اختيار عدة عملاء للتخطيط أو النقل';

  @override
  String get showRouteMap => 'عرض على خريطة المسار';

  @override
  String get shortestOrderHint => 'الأرقام تتبع أقصر مسار';

  @override
  String get efficiency => 'الكفاءة';

  @override
  String efficiencyDetail(String needed, String took) {
    return 'المطلوب نحو $needed (أقصر مسار + 30 دقيقة لكل زيارة)، واستغرق $took من أول زيارة إلى آخر زيارة';
  }

  @override
  String get efficiencyBestOrder => 'تمت الزيارات بترتيب أقصر مسار';

  @override
  String efficiencyOtherOrder(String shortest, String taken) {
    return 'أقصر ترتيب: $shortest بين الزيارات بدلًا من $taken';
  }

  @override
  String notifNotificationsOff(String name) {
    return 'أوقف $name الإشعارات لتطبيق WPC CRM';
  }

  @override
  String get logNotificationsOff => 'تم إيقاف الإشعارات';

  @override
  String get logNotificationsOn => 'تم تشغيل الإشعارات';

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

  @override
  String get exportClients => 'تصدير إلى Excel';

  @override
  String get exportClientsTitle => 'تصدير العملاء إلى Excel';

  @override
  String exportClientsBody(int count) {
    return '$count عميل (القائمة الحالية مع البحث والفلاتر). اختر الأعمدة:';
  }

  @override
  String exportColumnsCount(int selected, int total) {
    return '$selected من $total عمود';
  }

  @override
  String get exportSelectNone => 'مسح';

  @override
  String get exportButton => 'تصدير';

  @override
  String get exportLegalName => 'الاسم القانوني';

  @override
  String get exportVisitStatus => 'حالة الزيارة';

  @override
  String get exportDaysSinceVisit => 'أيام منذ آخر زيارة';

  @override
  String get exportOtherContacts => 'جهات اتصال أخرى';

  @override
  String get exportMapsLink => 'رابط خرائط Google';

  @override
  String get exportGooglePin => 'دبوس Google من Odoo';

  @override
  String get exportOdooTags => 'وسوم Odoo';

  @override
  String get exportCurrency => 'العملة';

  @override
  String get exportSource => 'المصدر';

  @override
  String get exportSourceImport => 'استيراد Odoo';

  @override
  String get exportHidden => 'مخفي';

  @override
  String get exportAddedOn => 'تاريخ الإضافة';

  @override
  String get yes => 'نعم';

  @override
  String get no => 'لا';

  @override
  String get call => 'مكالمة';

  @override
  String get calls => 'مكالمات';

  @override
  String get logCall => 'تسجيل مكالمة';

  @override
  String get saveCall => 'حفظ المكالمة';

  @override
  String get callSaved => 'تم حفظ المكالمة';

  @override
  String get callNotes => 'ما الذي تمت مناقشته في المكالمة';

  @override
  String get callNotesHint => 'طلبات، متابعات، الزيارة القادمة…';

  @override
  String get callNotesRequired => 'اكتب ما تمت مناقشته في المكالمة';

  @override
  String get callFromApp => 'اتصال من التطبيق';

  @override
  String get callLoggedByHand => 'مسجلة يدويًا';

  @override
  String callDuration(String duration) {
    return 'حوالي $duration خارج التطبيق';
  }

  @override
  String get notThisCall => 'ليست هذه المكالمة';

  @override
  String logThisCall(String duration) {
    return 'عدت من مكالمة ($duration). هل تريد تسجيلها؟';
  }

  @override
  String calledBy(String name) {
    return 'مكالمة بواسطة $name';
  }

  @override
  String get visitsAndCalls => 'الزيارات والمكالمات';

  @override
  String get visitsPlusCalls => 'الزيارات + المكالمات';

  @override
  String visitsAndCallsDetail(int visits, int calls) {
    return '$visits زيارة + $calls مكالمة';
  }

  @override
  String barTooltipCalls(
    String name,
    int done,
    int calls,
    int target,
    int expected,
  ) {
    return '$name: $done زيارة + $calls مكالمة · الهدف $target · المتوقع حتى اليوم $expected';
  }

  @override
  String get roleHr => 'الموارد البشرية';

  @override
  String get roleAccounting => 'المحاسبة';

  @override
  String get roleProcurement => 'المشتريات';

  @override
  String get roleUnknown => 'دور غير معروف';

  @override
  String get updateAppForRole =>
      'حسابك يستخدم دورًا لا يعرفه هذا الإصدار من التطبيق. يرجى تحديث التطبيق (Google Play / TestFlight) أو إعادة تحميل صفحة الويب.';

  @override
  String get backOfficeHomeBody => 'سيظهر هنا حضورك وطلبات إجازاتك.';

  @override
  String get hrArea => 'الموارد البشرية';

  @override
  String get myLeave => 'إجازاتي';

  @override
  String get myLeaveHint => 'الأرصدة والطلبات';

  @override
  String get myRequests => 'طلباتي';

  @override
  String get newLeaveRequest => 'طلب جديد';

  @override
  String get noLeaveRequests => 'لا توجد طلبات';

  @override
  String get leaveRequests => 'الطلبات';

  @override
  String get leaveBalances => 'الأرصدة';

  @override
  String get leaveTypesAndHolidays => 'أنواع الإجازات والعطل';

  @override
  String leaveBalanceYear(int year) {
    return 'رصيد الإجازات $year';
  }

  @override
  String leavePendingDays(String days) {
    return '$days يوم بانتظار الموافقة';
  }

  @override
  String leaveRemainingOf(String left, String total) {
    return 'متبقي $left من $total';
  }

  @override
  String leaveDaysCount(String days) {
    return '$days يوم';
  }

  @override
  String leaveLeftAfter(String days) {
    return 'يتبقى $days بعد هذا الطلب';
  }

  @override
  String get leaveOverBalance =>
      'هذا أكثر من الأيام المتبقية. الموارد البشرية تقرر ما إذا كان مسموحًا.';

  @override
  String waitingFor(String who) {
    return 'بانتظار $who';
  }

  @override
  String get waitingForMe => 'بانتظاري';

  @override
  String get pendingStatus => 'قيد الانتظار';

  @override
  String get leaveApprovedStatus => 'موافق عليه';

  @override
  String get leaveCancelledStatus => 'ملغى';

  @override
  String leaveWaitingForYou(int count) {
    return 'طلبات بانتظار موافقتك ($count)';
  }

  @override
  String get requestType => 'النوع';

  @override
  String get pickLeaveDates => 'اختر التواريخ';

  @override
  String get halfDay => 'نصف يوم';

  @override
  String get countsCalendarDays => 'تُحسب كل الأيام';

  @override
  String get countsWorkDays => 'تُحسب أيام العمل فقط';

  @override
  String get leaveReasonOptional => 'السبب (اختياري)';

  @override
  String get leaveRequestDetails => 'ما الذي تحتاجه؟';

  @override
  String get leaveReasonRequired => 'اكتب ما تحتاجه';

  @override
  String leaveDocumentRequired(String document) {
    return 'مطلوب: $document';
  }

  @override
  String get approvalOrder => 'ترتيب الموافقات';

  @override
  String get noApproverYet =>
      'لا يوجد من يوافق على هذا الطلب بعد. اطلب من المدير العام إضافة مستخدم للموارد البشرية.';

  @override
  String get leaveAcrossYears =>
      'لا يمكن أن يتجاوز الطلب نهاية السنة. أرسل طلبًا لكل سنة.';

  @override
  String get leaveNoWorkDays => 'لا توجد أيام عمل في هذه التواريخ.';

  @override
  String get sendRequest => 'إرسال الطلب';

  @override
  String get leaveRequestSent => 'تم إرسال الطلب';

  @override
  String get approveRequest => 'الموافقة على الطلب';

  @override
  String get rejectRequest => 'رفض الطلب';

  @override
  String get rejectReason => 'السبب';

  @override
  String get cancelRequest => 'إلغاء الطلب';

  @override
  String get leaveAlreadyDecided => 'تم اتخاذ قرار في هذه الخطوة مسبقًا.';

  @override
  String get leaveTypesHint =>
      'القيم المبدئية حسب نظام العمل السعودي – يرجى من الموارد البشرية مراجعتها. اضغط على النوع لتعديله.';

  @override
  String get noYearlyLimit => 'بدون حد سنوي';

  @override
  String daysPerYear(int days) {
    return '$days يوم في السنة';
  }

  @override
  String get unpaid => 'بدون راتب';

  @override
  String get otherRequest => 'طلب (بدون أيام)';

  @override
  String needsDocumentNamed(String document) {
    return 'يتطلب: $document';
  }

  @override
  String get addLeaveType => 'إضافة نوع';

  @override
  String get editLeaveType => 'تعديل النوع';

  @override
  String get nameEnglish => 'الاسم (إنجليزي)';

  @override
  String get nameArabic => 'الاسم (عربي)';

  @override
  String get isLeaveType => 'إجازة (لها تواريخ)';

  @override
  String get isLeaveTypeHint => 'أوقفه لطلبات مثل تعريف بالراتب';

  @override
  String get daysPerYearLabel => 'أيام في السنة';

  @override
  String get daysPerYearHelper => 'فارغ = بدون حد';

  @override
  String get paidLeave => 'مدفوعة الأجر';

  @override
  String get needsDocument => 'يتطلب مستندًا';

  @override
  String get documentNameEnglish => 'المستند (إنجليزي)';

  @override
  String get documentNameArabic => 'المستند (عربي)';

  @override
  String get publicHolidays => 'العطل الرسمية';

  @override
  String get publicHolidaysHint => 'لا تُحسب هذه الأيام من الإجازة.';

  @override
  String get addHoliday => 'إضافة عطلة';

  @override
  String get tapTypeToEdit =>
      'اضغط على النوع لتحديد أيام هذا الموظف أو إضافة تعديل.';

  @override
  String get daysThisYear => 'أيام هذه السنة لهذا الموظف';

  @override
  String daysThisYearHelper(int days) {
    return 'فارغ = $days يوم حسب النوع';
  }

  @override
  String get adjustDays => 'إضافة أو خصم أيام';

  @override
  String get adjustDaysHelper => 'مثال: 5 مرحّلة، أو -2';

  @override
  String get adjustNote => 'ملاحظة';

  @override
  String get adjustments => 'التعديلات';

  @override
  String notifLeaveRequested(String owner) {
    return 'طلب من $owner – بانتظار موافقتك';
  }

  @override
  String notifLeaveApproved(String name) {
    return 'وافق $name على طلبك';
  }

  @override
  String notifLeaveRejected(String name) {
    return 'رفض $name طلبك';
  }

  @override
  String get addLocation => 'إضافة موقع';

  @override
  String get editLocation => 'تعديل الموقع';

  @override
  String get locationType => 'التصنيف';

  @override
  String get noLocationType => 'بدون تصنيف';

  @override
  String get mainLocationType => 'تصنيف الموقع الرئيسي';

  @override
  String get moreLocationsOnClientPage =>
      'أضف مواقع أخرى (مصنع، معرض، …) من صفحة العميل';

  @override
  String get mainLocation => 'رئيسي';

  @override
  String get makeMainLocation => 'جعله الموقع الرئيسي';

  @override
  String locationNumber(int n) {
    return 'الموقع $n';
  }

  @override
  String deleteLocationTitle(String name) {
    return 'حذف \"$name\"؟';
  }

  @override
  String get visitLocation => 'موقع الزيارة';

  @override
  String get nearestLocation => 'الأقرب';

  @override
  String get locationTypes => 'أنواع المواقع';

  @override
  String get locationTypesHelp =>
      'تصنيفات مواقع العميل، مثل مكتب ومصنع ومعرض. حذف تصنيف يترك مواقعه بدون تصنيف.';

  @override
  String get otherLocations => 'مواقع أخرى';

  @override
  String get saveClientFirstForLocations =>
      'احفظ العميل أولاً، ثم أضف مواقع أخرى هنا.';

  @override
  String get setMainLocationFirst =>
      'حدد الموقع الرئيسي واحفظه أولاً، ثم أضف مواقع أخرى.';

  @override
  String visitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count زيارة',
      few: '$count زيارات',
      two: 'زيارتان',
      one: 'زيارة واحدة',
      zero: 'لا زيارات',
    );
    return '$_temp0';
  }

  @override
  String callsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مكالمة',
      few: '$count مكالمات',
      two: 'مكالمتان',
      one: 'مكالمة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get deleteClient => 'حذف العميل';

  @override
  String deleteClientTitle(String name) {
    return 'حذف $name؟';
  }

  @override
  String get deleteClientBody =>
      'سيتم حذف العميل وعناصر الخطط والصور والملفات الخاصة به. لا يمكن التراجع عن ذلك.';

  @override
  String deleteClientWithVisits(int count) {
    return 'لدى هذا العميل $count زيارة. تبقى الزيارات في قائمة الزيارات والتقارير، ويُحذف العميل وعناصر الخطط والصور والملفات الخاصة به. لا يمكن التراجع عن ذلك.\n\nأدخل كلمة المرور للتأكيد.';
  }

  @override
  String get yourPassword => 'كلمة المرور الخاصة بك';

  @override
  String get wrongPassword => 'كلمة المرور غير صحيحة';

  @override
  String clientDeleted(String name) {
    return 'تم حذف $name';
  }

  @override
  String get documents => 'المستندات';

  @override
  String get docCr => 'السجل التجاري';

  @override
  String get docVat => 'شهادة ضريبة القيمة المضافة';

  @override
  String get docNationalAddress => 'العنوان الوطني';

  @override
  String get docsHelp =>
      'ارفع ملف PDF من المنصة (الأفضل) أو صورة واضحة. يقرأ التطبيق الأرقام والعنوان ويعرض تعبئة الحقول.';

  @override
  String get docNotAdded => 'غير مضاف';

  @override
  String docWillUpload(String name) {
    return '$name – يُرفع عند الحفظ';
  }

  @override
  String get upload => 'رفع';

  @override
  String get replace => 'استبدال';

  @override
  String get docUnreadable =>
      'تم إرفاق المستند، لكن تعذّرت قراءة أي نص منه. عبّئ الحقول يدويًا.';

  @override
  String get docPhotoOnWeb =>
      'تم إرفاق المستند. تُقرأ الصور في تطبيق الجوال فقط؛ على الويب ارفع ملف PDF لتعبئة الحقول.';

  @override
  String get docNothingFound =>
      'تم إرفاق المستند، لكن لم يُعثر فيه على رقم سجل أو رقم ضريبي أو عنوان.';

  @override
  String docFoundTitle(String document) {
    return 'ما تم العثور عليه في $document';
  }

  @override
  String get docFoundHelp =>
      'تحقق من القيم قبل تعبئتها. الحقول المحددة تستبدل ما في النموذج.';

  @override
  String docCurrentValue(String value) {
    return 'الحالي: $value';
  }

  @override
  String get docFill => 'تعبئة';

  @override
  String get clientStatus => 'حالة العميل';

  @override
  String get clientStatusActive => 'نشط';

  @override
  String get clientStatusClosed => 'مغلق';

  @override
  String get clientStatusNotWorking => 'لا يتعامل معنا';

  @override
  String get changeClientStatus => 'تغيير حالة العميل';

  @override
  String get clientStatusReason => 'السبب (اختياري)';

  @override
  String get clientStatusNeedsApproval =>
      'سيوافق مدير الحسابات أو مدير المبيعات أو المدير العام على التغيير.';

  @override
  String get sendForApproval => 'إرسال للموافقة';

  @override
  String get clientStatusChanged => 'تم تغيير حالة العميل';

  @override
  String get clientStatusRequestSent => 'تم الإرسال للموافقة';

  @override
  String get clientStatusRequestCancelled => 'تم إلغاء الطلب';

  @override
  String get clientStatusApproved => 'تمت الموافقة';

  @override
  String get clientStatusRejected => 'تم الرفض';

  @override
  String clientStatusSince(String status, String date) {
    return '$status منذ $date';
  }

  @override
  String clientStatusWaiting(String status) {
    return 'بانتظار الموافقة: $status';
  }

  @override
  String clientStatusAsked(String name, String status) {
    return 'طلب $name تحويل هذا العميل إلى $status';
  }

  @override
  String clientStatusRejectedEntry(String status) {
    return '$status – مرفوض';
  }

  @override
  String clientStatusRequestedBy(String name) {
    return 'بطلب من $name';
  }

  @override
  String clientStatusDecidedBy(String name) {
    return 'بواسطة $name';
  }

  @override
  String get clientStatusHistory => 'سجل الحالة';

  @override
  String get clientStatusRequests => 'طلبات تغيير الحالة';

  @override
  String get clientStatusFilterHelp =>
      'العملاء المغلقون ومن لا يتعاملون معنا يظهرون فقط عند تحديدهم هنا.';

  @override
  String notifClientStatusRequested(String name, String client, String status) {
    return 'طلب $name تحويل $client إلى $status – بانتظار موافقتك';
  }

  @override
  String notifClientStatusApproved(String name, String client, String status) {
    return 'وافق $name: $client أصبح $status';
  }

  @override
  String notifClientStatusRejected(String name, String client, String status) {
    return 'رفض $name تحويل $client إلى $status';
  }

  @override
  String get transferredClients => 'العملاء المنقولون';

  @override
  String get transfersHelp =>
      'العملاء الذين نُقلوا من مندوب إلى آخر، وهل زارهم المندوب الجديد أو اتصل بهم منذ ذلك.';

  @override
  String lastNDays(int n) {
    return 'آخر $n يوم';
  }

  @override
  String get transfersNotVisitedOnly => 'لم تتم زيارتهم بعد';

  @override
  String transfersSummary(int total, int visited, int waiting) {
    return '$total منقول · $visited تمت زيارتهم · $waiting لم تتم بعد';
  }

  @override
  String get transfersNone => 'لم يُنقل أي عميل في هذه الفترة.';

  @override
  String transferMovedBy(String name, String date) {
    return 'نقله $name · $date';
  }

  @override
  String transferVisitedAfter(String date, int days) {
    return 'تمت الزيارة $date · بعد $days يوم من النقل';
  }

  @override
  String transferCalledAfter(String date, int days) {
    return 'تم الاتصال $date · بعد $days يوم من النقل';
  }

  @override
  String transferNotVisited(int days) {
    return 'لم تتم الزيارة · $days يوم منذ النقل';
  }

  @override
  String get transferMovedAgain => 'نُقل مرة أخرى لاحقاً';

  @override
  String get newSalesperson => 'المندوب الجديد';

  @override
  String get motionDriving => 'يقود';

  @override
  String get motionWalking => 'يمشي';

  @override
  String get motionStopped => 'متوقف';

  @override
  String motionIdleFor(String time) {
    return 'متوقف منذ $time';
  }

  @override
  String get appVersion => 'إصدار التطبيق';

  @override
  String get newerVersionAvailable => 'يتوفر إصدار أحدث';

  @override
  String get updateApp => 'تحديث';

  @override
  String latestAppVersion(String version) {
    return 'أحدث إصدار: $version';
  }

  @override
  String get everyoneUpToDate => 'جميع الجوالات على أحدث إصدار';

  @override
  String peopleOnOlderVersion(int n) {
    return '$n على إصدار أقدم';
  }

  @override
  String remindAll(int n) {
    return 'تذكير ($n)';
  }

  @override
  String get remindToUpdate => 'تذكير بالتحديث';

  @override
  String remindedWait(int seconds) {
    return 'تم التذكير – انتظر $seconds ث';
  }

  @override
  String get noAppVersion => 'لم يُبلَّغ عن إصدار التطبيق بعد';

  @override
  String updateRemindersSent(int n) {
    return 'تم إرسال التذكير إلى $n';
  }

  @override
  String notifUpdateReminder(String name) {
    return 'يطلب $name تحديث تطبيق WPC CRM إلى أحدث إصدار – اضغط للتحديث';
  }

  @override
  String get linkedClients => 'العملاء المرتبطون';

  @override
  String get mainCompany => 'الشركة الرئيسية';

  @override
  String get branch => 'فرع';

  @override
  String get linkToMainCompany => 'ربط بشركة رئيسية';

  @override
  String get addBranch => 'إضافة فرع';

  @override
  String get unlinkClient => 'إلغاء الربط';

  @override
  String moveBranchConfirm(String branch, String from, String to) {
    return '$branch فرع من $from. نقله ليصبح تحت $to؟';
  }

  @override
  String get noLinkedClients =>
      'لا يوجد عملاء مرتبطون. اربط فرعاً من صفحة العميل.';

  @override
  String branchCount(int n) {
    return '$n فرع';
  }

  @override
  String get addCompany => 'إضافة شركة';

  @override
  String get addWorkSite => 'إضافة موقع عمل';

  @override
  String get allow => 'سماح';

  @override
  String get allowAlwaysForAttendance =>
      'اسمح بالموقع \"دائماً\" ليتم تسجيل حضورك تلقائياً عند وصولك';

  @override
  String get atTheSite => 'في موقع العمل';

  @override
  String get attendance => 'الحضور';

  @override
  String get autoCheckInHelp =>
      'يُسجَّل حضورك تلقائياً عند وصولك إلى موقع العمل.';

  @override
  String get checkIn => 'تسجيل حضور';

  @override
  String get checkInAgain => 'تسجيل حضور مرة أخرى';

  @override
  String get checkOut => 'تسجيل انصراف';

  @override
  String get checkOutAuto => 'أُغلق تلقائياً (لم يُرصد خروج)';

  @override
  String get checkOutConfirm => 'تسجيل الانصراف الآن؟ ينتهي يومك في هذا الوقت.';

  @override
  String get checkOutEndOfDay => 'نهاية يوم العمل';

  @override
  String get checkOutLeft => 'غادر الموقع';

  @override
  String get checkOutLeftEarly => 'غادر مبكراً';

  @override
  String get checkOutManual => 'انصراف يدوي';

  @override
  String get companies => 'الشركات';

  @override
  String get company => 'الشركة';

  @override
  String get confirmPassword => 'تأكيد كلمة المرور';

  @override
  String get createAccount => 'إنشاء حساب';

  @override
  String get editWorkSite => 'تعديل موقع العمل';

  @override
  String get noCompanies =>
      'لا توجد شركات بعد. أضف الشركات التي يمكن اختيارها عند التسجيل.';

  @override
  String get noOneAssignedToSites =>
      'لم يُعيَّن أحد لموقع عمل بعد. عيّن الأشخاص من المزيد ← مواقع العمل أو من صفحة المستخدم.';

  @override
  String get noWorkSiteAssigned => 'لم يتم تعيينك لموقع عمل.';

  @override
  String get noWorkSites => 'لا توجد مواقع عمل بعد.';

  @override
  String get notCheckedIn => 'لم يسجّل حضوراً';

  @override
  String get overtimeAllowed => 'العمل الإضافي مسموح';

  @override
  String get overtimeAllowedHelp =>
      'الوقت بعد نهاية يوم العمل يُحتسب عملاً إضافياً. عند الإيقاف: يُحتسب اليوم حتى نهاية يوم العمل فقط.';

  @override
  String get position => 'المسمى الوظيفي';

  @override
  String get positionHint => 'مثال: محاسب، سائق، مهندس موقع';

  @override
  String get radiusHelp =>
      'المسافة التي تُعد \"في الموقع\". تحتاج الجوالات 100 م على الأقل لرصد الوصول والمغادرة بدقة.';

  @override
  String get registerEmailInUse =>
      'هذا البريد لديه حساب بالفعل. سجّل الدخول أو استخدم \"نسيت كلمة المرور؟\".';

  @override
  String get registerHelp =>
      'للأشخاص الذين ليس لديهم حساب في الشركة. بعد التسجيل يوافق مدير المبيعات أو المدير العام على حسابك.';

  @override
  String get registrationPendingBanner => 'حساب مسجّل – بانتظار الموافقة';

  @override
  String get registrationPendingHelp =>
      'راجع البيانات واختر الدور والشركة ومواقع العمل ثم وافق.';

  @override
  String get registrationRejected => 'تم رفض التسجيل';

  @override
  String get registrationRejectedBody =>
      'لم تتم الموافقة على تسجيلك. تواصل مع مديرك إذا كان ذلك خطأ.';

  @override
  String get registrationRejectedShort => 'غير موافق عليه';

  @override
  String get registrationRejectedTitle => 'لم تتم الموافقة على التسجيل';

  @override
  String get renameCompany => 'إعادة تسمية الشركة';

  @override
  String get roleDriver => 'سائق';

  @override
  String get roleEngineer => 'مهندس';

  @override
  String get roleWorker => 'عامل';

  @override
  String get waitingForApprovalTitle => 'بانتظار الموافقة';

  @override
  String get workSiteNameHint => 'مثال: المكتب الرئيسي، المستودع';

  @override
  String get workSiteNeedsNameAndPlace =>
      'أدخل اسم موقع العمل واختر مكانه على الخريطة.';

  @override
  String get workSiteNoPlace => 'لم يُحدَّد المكان بعد';

  @override
  String get workSites => 'مواقع العمل';

  @override
  String attendanceAbsent(int n) {
    return 'لم يحضر: $n';
  }

  @override
  String attendanceIn(int n) {
    return 'حاضر: $n';
  }

  @override
  String attendanceOut(int n) {
    return 'انصرف: $n';
  }

  @override
  String checkedInAt(String site) {
    return 'تم تسجيل الحضور في $site';
  }

  @override
  String checkedInSince(String time, String site) {
    return 'حضور الساعة $time · $site';
  }

  @override
  String checkedOutAt(String time) {
    return 'انصراف الساعة $time';
  }

  @override
  String deleteWorkSiteConfirm(String name) {
    return 'حذف $name؟ سيُلغى تعيين الأشخاص المرتبطين به.';
  }

  @override
  String inSince(String time) {
    return 'حاضر منذ $time';
  }

  @override
  String leftSiteAt(String time) {
    return 'غادر الموقع الساعة $time';
  }

  @override
  String notAtWorkSite(String distance) {
    return 'لست في موقع العمل (على بعد $distance).';
  }

  @override
  String notifRegistrationRequested(String name) {
    return 'سجّل $name حساباً – بانتظار موافقتك';
  }

  @override
  String overtimeTime(String time) {
    return 'إضافي $time';
  }

  @override
  String peopleAtSite(int n) {
    return 'العاملون هنا ($n)';
  }

  @override
  String peopleCount(int n) {
    return '$n شخص';
  }

  @override
  String radiusMeters(int m) {
    return 'نصف القطر $m م';
  }

  @override
  String rejectRegistrationConfirm(String name) {
    return 'رفض تسجيل $name؟ لن يتمكن من استخدام التطبيق.';
  }

  @override
  String waitingForApprovalBody(String name) {
    return 'شكراً $name. تم إنشاء حسابك وسيوافق عليه مدير المبيعات أو المدير العام، وبعدها يمكنك استخدام التطبيق.';
  }

  @override
  String workedTime(String time) {
    return 'عمل $time';
  }

  @override
  String get positions => 'المسميات الوظيفية';

  @override
  String get positionsHelp =>
      'المسميات الوظيفية التي يختارها الأشخاص عند التسجيل أو التي تحددها في صفحة المستخدم.';

  @override
  String get addPosition => 'إضافة مسمى';

  @override
  String deletePositionBody(int count) {
    return 'لدى $count شخص هذا المسمى وسيظهر كمحذوف. لا يمكن التراجع عن ذلك.';
  }

  @override
  String get moreSectionSales => 'المبيعات';

  @override
  String get moreSectionPeople => 'الموظفون والحضور';

  @override
  String get moreSectionSettings => 'الإعدادات';

  @override
  String get searchUsers => 'ابحث بالاسم أو البريد أو الهاتف أو المسمى';

  @override
  String get olderAppVersion => 'تطبيق قديم';

  @override
  String usersShown(int shown, int total) {
    return '$shown من $total مستخدم';
  }

  @override
  String get noUsersMatch => 'لا يوجد مستخدمون مطابقون للبحث أو الفلاتر.';

  @override
  String get dayMissed => 'غياب – لا يوجد تسجيل حضور';

  @override
  String get dayOnLeave => 'في إجازة';

  @override
  String get dayOff => 'يوم عطلة';

  @override
  String daysAttended(int n) {
    return 'حضور $n';
  }

  @override
  String daysMissed(int n) {
    return 'غياب $n';
  }

  @override
  String get leaveLegend => 'إجازة';

  @override
  String monthHours(String time) {
    return '$time هذا الشهر';
  }

  @override
  String checkedInFor(String time) {
    return '$time حتى الآن';
  }

  @override
  String get noWorkSiteYet =>
      'لم يتم تعيينك في موقع عمل بعد. اطلب من مديرك إضافتك.';

  @override
  String sendGap(String from, String to) {
    return 'لم يُرسل موقعك من $from إلى $to اليوم – أوقف الجوال التطبيق مؤقتاً. راجع الإعدادات أدناه.';
  }

  @override
  String get issueBackgroundRestricted =>
      'استخدام البطارية لتطبيق WPC CRM مضبوط على \"مقيّد\": اضبطه على \"غير مقيّد\"';

  @override
  String get issueAppSleeping =>
      'وضع أندرويد تطبيق WPC CRM في وضع السكون – اسمح له بالعمل في الخلفية';

  @override
  String get phoneSetupTitle => 'إعداد إضافي على هذا الجوال';

  @override
  String get phoneSetupXiaomi =>
      'تقوم أجهزة Xiaomi / Redmi / POCO بإيقاف التطبيقات تلقائياً. فعّل التشغيل التلقائي (Autostart) لتطبيق WPC CRM واضبط توفير البطارية على \"بلا قيود\".';

  @override
  String get phoneSetupSamsung =>
      'تضع سامسونج التطبيقات في وضع السكون. من الإعدادات ← البطارية ← حدود الاستخدام في الخلفية، أزل WPC CRM من \"التطبيقات الخاملة\" و\"التطبيقات الخاملة بعمق\" وأضفه إلى \"التطبيقات التي لا تخمل أبداً\".';

  @override
  String get phoneSetupHuawei =>
      'توقف أجهزة Huawei / Honor التطبيقات في الخلفية. من الإعدادات ← البطارية ← تشغيل التطبيقات، اضبط WPC CRM على الإدارة اليدوية وفعّل التشغيل التلقائي والتشغيل الثانوي والتشغيل في الخلفية.';

  @override
  String get phoneSetupOppo =>
      'توقف أجهزة Oppo / Realme التطبيقات في الخلفية. اسمح بالتشغيل التلقائي لتطبيق WPC CRM، ومن إعدادات البطارية اسمح بالنشاط في الخلفية.';

  @override
  String get phoneSetupVivo =>
      'توقف أجهزة Vivo التطبيقات في الخلفية. اسمح بالتشغيل التلقائي و\"استهلاك طاقة عالٍ في الخلفية\" لتطبيق WPC CRM.';

  @override
  String get phoneSetupOneplus =>
      'توقف أجهزة OnePlus التطبيقات في الخلفية. اضبط تحسين البطارية لتطبيق WPC CRM على \"عدم التحسين\" واسمح بالتشغيل التلقائي.';

  @override
  String get openSettings => 'فتح الإعدادات';

  @override
  String get phoneSetupDone => 'تم الإعداد';
}
