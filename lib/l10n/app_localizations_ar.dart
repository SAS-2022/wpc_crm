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
      'سيُحذف المستخدم نهائيًا: حساب الدخول (يمكن استخدام البريد مرة أخرى) والملف الشخصي وبيانات الموقع. يصبح عملاؤه غير مُسندين ويفقد فريقه مدير الحسابات. تبقى زياراته وخططه وسجل حضوره وإجازاته.';

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
  String get issueMotion =>
      'اسمح باكتشاف الحركة (\"النشاط البدني\" / \"الحركة واللياقة\") حتى لا يُحسب المشي ضمن كيلومترات السيارة';

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
  String get addPhoneTitle => 'أضف رقم تواصل';

  @override
  String addPhoneMessage(String client) {
    return 'لا يوجد رقم هاتف لـ $client. أضف رقماً لحفظ هذه الزيارة.';
  }

  @override
  String addPhoneMessageCall(String client) {
    return 'لا يوجد رقم هاتف لـ $client. أضف رقماً لحفظ هذه المكالمة.';
  }

  @override
  String get pickFromContacts => 'اختر من جهات اتصال الهاتف';

  @override
  String get phoneNumberInvalid => 'أدخل رقم هاتف (من 7 إلى 15 رقماً)';

  @override
  String get saudiPhoneInvalid =>
      'أدخل رقم جوال سعودي: 05X XXX XXXX (10 أرقام)';

  @override
  String get phoneNumberSaved => 'تم حفظ رقم التواصل';

  @override
  String get saveAndContinue => 'حفظ ومتابعة';

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
      'الأيام التي فيها زيارتان أو أكثر. يُقسَّم موقع كل يوم إلى وقت عند العملاء، والقيادة، والمكتب، والغداء (حتى 60 دقيقة وقت الظهر)، والتوقف في مكان آخر (15 دقيقة فأكثر)، وبدون بيانات موقع. معيار الفريق هو الوسيط لمتوسطات المندوبين: مدة الزيارة، وسرعة القيادة، وكم تطول الطرق عن الخط المستقيم. الكفاءة = المطلوب (عدد الزيارات × مدة الزيارة + أقصر مسار بتلك السرعة) ÷ المستغرق (من الوصول لأول عميل حتى مغادرة آخر عميل، دون الغداء والمكتب)، بحد أقصى 100%. الأيام بلا موقع تُحسب من أوقات تسجيل الزيارات.';

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
    return 'المطلوب نحو $needed بوتيرة الفريق (متوسط مدة الزيارة الوسيط + أقصر مسار بسرعة القيادة الوسيطة)، واستغرق $took من الوصول إلى أول عميل حتى مغادرة آخر عميل، دون الغداء ووقت المكتب';
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
  String get logQuiet => 'توقف الهاتف عن الإرسال';

  @override
  String get logWoken => 'أيقظه فحص التنبيه – عاد للإرسال';

  @override
  String get logResumed => 'عاد للإرسال';

  @override
  String get logNoAnswer => 'لم يستجب لفحص التنبيه – تم إبلاغ المديرين';

  @override
  String notifPhoneNoAnswer(String name, String time, int minutes) {
    return 'لم يرسل هاتف $name شيئاً منذ الساعة $time ($minutes دقيقة) ولم يستجب لفحص التنبيه – قد يكون التطبيق مغلقاً أو الهاتف مطفأً أو بلا شبكة';
  }

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
  String notifLeaveStepApproved(String name) {
    return 'وافق $name على طلبك – بانتظار الموافقة النهائية';
  }

  @override
  String notifLeaveReminder(String owner, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days يوم',
      few: '$days أيام',
      two: 'يومين',
      one: 'يوم واحد',
    );
    return 'تذكير: طلب $owner بانتظار موافقتك منذ $_temp0';
  }

  @override
  String notifLeaveUpdateSent(String owner) {
    return 'طلب إجازة جديد من $owner – للعلم';
  }

  @override
  String notifLeaveUpdateStepApproved(String name, String owner) {
    return 'وافق $name على طلب $owner – بانتظار الموافقة النهائية';
  }

  @override
  String notifLeaveUpdateApproved(String name, String owner) {
    return 'أعطى $name الموافقة النهائية على طلب $owner';
  }

  @override
  String notifLeaveUpdateRejected(String name, String owner) {
    return 'رفض $name طلب $owner';
  }

  @override
  String notifLeaveUpdateCancelled(String owner) {
    return 'أُلغي طلب $owner';
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
  String get movedBy => 'نقلها';

  @override
  String movedByName(String name) {
    return 'نقلها: $name';
  }

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
  String get overtimeMax => 'أقصى عمل إضافي في اليوم';

  @override
  String get overtimeMaxHelp =>
      'ما يزيد على ذلك لا يُحتسب (يُسجَّل كوقت بقاء بعد الدوام). الافتراضي: 3 ساعات.';

  @override
  String hoursCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ساعة',
      few: '$n ساعات',
      two: 'ساعتان',
      one: 'ساعة واحدة',
    );
    return '$_temp0';
  }

  @override
  String notifOvertimeStarted(String name, String site, String time) {
    return '$name ما زال في $site بعد نهاية الدوام ($time) – يُحتسب العمل الإضافي';
  }

  @override
  String notifOvertimeStartedSelf(String site, String time) {
    return 'انتهى دوامك الساعة $time وما زلت في $site – يُحتسب العمل الإضافي. اضغط «تسجيل انصراف» عند المغادرة.';
  }

  @override
  String get overtimeAllowedHelp =>
      'يُحتسب العمل الإضافي بعد بدئه: يُسأل موظفو الموقع بعد 10 دقائق من نهاية الدوام، ويبدأ تلقائياً للسائقين الذين ما زالوا في الطريق. يعتمده المدير لاحقاً.';

  @override
  String get attendanceRequired => 'الحضور مطلوب';

  @override
  String get attendanceRequiredHelp =>
      'يسجّل الحضور والانصراف في مواقع العمل. عند الإيقاف: لا يُسجَّل الحضور (عادةً فريق المبيعات).';

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

  @override
  String get pickWorkDays => 'اختر يوم عمل واحداً على الأقل';

  @override
  String get ownWorkSchedule => 'جدول عمل خاص';

  @override
  String get ownWorkScheduleHelp =>
      'يُحتسب الحضور والتأخير ونهاية اليوم حسب هذه الأيام والساعات.';

  @override
  String companyWorkHoursNote(String hours) {
    return 'عند الإيقاف: ساعات عمل الشركة ($hours)';
  }

  @override
  String stayedAfterTime(String time) {
    return 'بقي بعد الدوام $time (غير محتسب)';
  }

  @override
  String lateBy(String time) {
    return 'متأخر $time';
  }

  @override
  String lateDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n أيام تأخير',
      one: 'يوم تأخير واحد',
    );
    return '$_temp0';
  }

  @override
  String notifCheckedIn(String name, String time) {
    return 'سجّل $name حضوره الساعة $time';
  }

  @override
  String notifCheckedInSelf(String time) {
    return 'تم تسجيل حضورك الساعة $time';
  }

  @override
  String notifMinutesLate(int n) {
    return 'متأخر $n دقيقة';
  }

  @override
  String notifAttendanceLate(String time) {
    return 'لم تسجّل حضورك بعد – بدأ يوم عملك الساعة $time. يرجى الحضور إلى العمل قريباً.';
  }

  @override
  String get attendanceReport => 'التقرير الشهري';

  @override
  String get attendanceReportEmpty =>
      'لا يوجد موظفون يتطلبون الحضور بعد. فعّل \"الحضور مطلوب\" واختر موقع عمل في نموذج المستخدم.';

  @override
  String get reportEmployee => 'الموظف';

  @override
  String get reportSchedule => 'الجدول';

  @override
  String get reportWorkDays => 'أيام العمل';

  @override
  String get reportMissed => 'غياب';

  @override
  String get reportLateDays => 'أيام التأخير';

  @override
  String get reportLateHours => 'التأخير (ساعات)';

  @override
  String get reportLateMinutes => 'التأخير (دقائق)';

  @override
  String get reportWorkedHours => 'ساعات العمل';

  @override
  String get reportOvertimeApprovedHours => 'العمل الإضافي المعتمد (ساعات)';

  @override
  String get reportOvertimeHours => 'العمل الإضافي (ساعات)';

  @override
  String get reportStayedAfterHours =>
      'البقاء بعد الدوام بدون عمل إضافي (ساعات)';

  @override
  String get reportDate => 'التاريخ';

  @override
  String get reportStatus => 'الحالة';

  @override
  String get reportSite => 'موقع العمل';

  @override
  String get reportCheckOutType => 'طريقة انتهاء اليوم';

  @override
  String get dayAttended => 'حاضر';

  @override
  String reportSummaryLine(int attended, int workDays, int missed, int leave) {
    return 'حضر $attended من $workDays · غياب $missed · إجازة $leave';
  }

  @override
  String reportLateLine(int days, String time) {
    return 'تأخر $days مرة ($time)';
  }

  @override
  String reportStayedLine(String time) {
    return 'بقي بعد الدوام $time';
  }

  @override
  String get noClientsFound => 'لا يوجد عملاء مطابقون';

  @override
  String get searchContact => 'جهة الاتصال';

  @override
  String get searchOtherName => 'اسم آخر';

  @override
  String get salesTeam => 'فريق المبيعات';

  @override
  String get drivers => 'السائقون';

  @override
  String salesTeamCount(int n) {
    return 'فريق المبيعات ($n)';
  }

  @override
  String driversCount(int n) {
    return 'السائقون ($n)';
  }

  @override
  String get searchClientsHint =>
      'ابحث بالاسم، جهة الاتصال، الهاتف، الرقم الضريبي، السجل التجاري، المندوب';

  @override
  String searchResultsOnMap(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n عملاء',
      one: 'عميل واحد',
    );
    return '$_temp0';
  }

  @override
  String get noDriversYet =>
      'لا يوجد سائقون بعد. امنح مستخدماً دور السائق في صفحة المستخدمين، وسيظهر هنا بعد تثبيت أحدث إصدار من التطبيق على هاتفه.';

  @override
  String minutesShort(int n) {
    return '$n د';
  }

  @override
  String kmPerHour(int n) {
    return '$n كم/س';
  }

  @override
  String get reportBenchmarkDefault =>
      'معيار الفريق (قيم ثابتة حتى تتوفر أيام كافية من بيانات الموقع)';

  @override
  String reportBenchmarkTitle(int n) {
    return 'معيار الفريق · الوسيط لـ $n مندوبين';
  }

  @override
  String get reportBenchVisit => 'مدة الزيارة';

  @override
  String get reportBenchSpeed => 'سرعة القيادة';

  @override
  String get reportBenchRoad => 'الطرق مقابل الخط المستقيم';

  @override
  String reportBenchExample(String time) {
    return '10 زيارات بينها 30 كم (خط مستقيم) ≈ $time';
  }

  @override
  String get reportBenchPartly =>
      'بعض القيم ما زالت ثابتة (30 دقيقة للزيارة، 40 كم/س، الطرق 1.4×) حتى يتوفر لمندوبين اثنين على الأقل يومان من بيانات الموقع.';

  @override
  String get reportTimeSplit => 'أين ذهب يوم العمل';

  @override
  String get deliveries => 'التسليمات';

  @override
  String get deliveryStopsNote =>
      'توقفات مدتها 5 دقائق أو أكثر على بعد 200 م من موقع عميل. الأوقات من GPS السائق: من الوصول إلى المغادرة.';

  @override
  String deliveryFromPin(int meters) {
    return 'على بعد $meters م من الدبوس';
  }

  @override
  String get noDeliveriesFound =>
      'لم يُعثر على توقفات عند مواقع العملاء في هذا اليوم.';

  @override
  String get deliveryLocationOther => 'موقع آخر';

  @override
  String get timeAtClients => 'عند العملاء';

  @override
  String get timeDriving => 'القيادة';

  @override
  String get timeOffice => 'المكتب';

  @override
  String get timeLunch => 'الغداء';

  @override
  String get timeStopped => 'توقف في مكان آخر';

  @override
  String get timeNoData => 'بدون بيانات موقع';

  @override
  String get reportNoGpsDay => 'بدون موقع – من أوقات التسجيل';

  @override
  String efficiencyDetailNoGps(String needed, String took) {
    return 'المطلوب نحو $needed بوتيرة الفريق، واستغرق $took (بدون بيانات موقع: من أول تسجيل إلى آخر تسجيل مع زيارة واحدة)';
  }

  @override
  String get roleLogisticsManager => 'مدير اللوجستيات';

  @override
  String get roleWarehouseSupervisor => 'مشرف المستودع';

  @override
  String get roleFactoryManager => 'مدير المصنع';

  @override
  String get roleOperator => 'مشغل';

  @override
  String get driversPage => 'السائقون';

  @override
  String get routeHistoryToday => 'سجل المسار';

  @override
  String get checkInNeedsLocation => 'لتسجيل الحضور، فعّل:';

  @override
  String get checkInGpsOff => 'خدمة الموقع (GPS) في الهاتف';

  @override
  String get checkInNoPermission => 'إذن الموقع للتطبيق';

  @override
  String get checkInNotAlways => 'الوصول إلى الموقع \"السماح طوال الوقت\"';

  @override
  String get mapView => 'عرض الخريطة';

  @override
  String get mapViewMap => 'خريطة';

  @override
  String get mapViewSatellite => 'قمر صناعي';

  @override
  String get mapViewHybrid => 'مختلط (قمر صناعي + أسماء)';

  @override
  String get settingsSectionTracking => 'التتبع وساعات العمل';

  @override
  String get settingsSectionClients => 'العملاء والزيارات';

  @override
  String get settingsSectionPeople => 'الموظفون والحضور';

  @override
  String get trackingSchedules => 'جداول التتبع';

  @override
  String trackingSchedulesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أشخاص لديهم جدول خاص',
      one: 'شخص واحد لديه جدول خاص',
      zero: 'الجميع يتبع ساعات عمل الشركة',
    );
    return '$_temp0';
  }

  @override
  String trackingSchedulesHelp(String hours) {
    return 'متى يُشارك موقع كل شخص. افتراضيًا يتبع فريق المبيعات ساعات عمل الشركة ($hours) ويُتتبع السائقون طوال اليوم. اضغط على شخص لتحديد أيام وساعات خاصة به، أو طوال اليوم.';
  }

  @override
  String get noTrackedPeople => 'لا يوجد أحد يُتتبع بعد.';

  @override
  String get trackingAllDay => 'طوال اليوم، كل يوم';

  @override
  String get trackingAllDayDriver => 'طوال اليوم (سائق)';

  @override
  String get trackingCompanyHours => 'ساعات عمل الشركة';

  @override
  String trackingScheduleOf(String name) {
    return 'ساعات التتبع · $name';
  }

  @override
  String get trackingModeStandard => 'افتراضي';

  @override
  String get trackingModeOwn => 'ساعات خاصة';

  @override
  String get trackingModeAllDay => 'طوال اليوم';

  @override
  String get trackingStandardDriverHelp =>
      'تبقى سيارة الشركة مع السائقين، لذلك يُشارك موقعهم طوال اليوم.';

  @override
  String trackingStandardHelp(String hours) {
    return 'يُشارك الموقع خلال ساعات عمل الشركة: $hours.';
  }

  @override
  String get trackingAllDayHelp =>
      'يُشارك الموقع في جميع الأوقات، حتى في أيام الإجازة. تُرسل تنبيهات التتبع فقط خلال ساعات عمل الشركة.';

  @override
  String get trackingOwnHelp =>
      'يُشارك الموقع في هذه الأيام والساعات فقط، وتتبعها أيضًا تنبيهات التتبع وعدم الاتصال.';

  @override
  String get trackingHours => 'ساعات التتبع';

  @override
  String get settingTrackingInterval => 'فترة إرسال الموقع';

  @override
  String get settingTrackingIntervalHelp =>
      'كم مرة يرسل الهاتف المُتتبع موقعه. فترة أقصر = مسارات أدق واستهلاك أكثر للبطارية.';

  @override
  String get settingOfflineAlert => 'تنبيه عدم الاتصال بعد';

  @override
  String get settingOfflineAlertHelp =>
      'يُبلَّغ مدير الحسابات أو المدراء إذا بقي الهاتف المُتتبع غير متصل هذه المدة خلال وقت العمل.';

  @override
  String get settingVisitRadius => 'حد مسافة تسجيل الزيارة';

  @override
  String get settingVisitRadiusHelp =>
      'تُعلَّم الزيارات المسجلة على مسافة أبعد من هذه عن العميل بأنها بعيدة.';

  @override
  String get settingLateGrace => 'مهلة التأخير في الحضور';

  @override
  String get settingLateGraceHelp =>
      'يُعد تسجيل الحضور في حدود هذه المدة بعد بداية الدوام في الوقت.';

  @override
  String get settingGivenDueSoon => 'تنبيه \"قريب الاستحقاق\" للكتالوجات';

  @override
  String get settingGivenDueSoonHelp =>
      'تظهر الكتالوجات والستاندات \"قريبة الاستحقاق\" قبل هذا العدد من الأيام من موعد الجديد.';

  @override
  String valueSeconds(int count) {
    return '$count ث';
  }

  @override
  String valueMinutes(int count) {
    return '$count د';
  }

  @override
  String valueMeters(int count) {
    return '$count م';
  }

  @override
  String valueDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يومًا',
      few: '$count أيام',
      two: 'يومان',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String settingRange(String min, String max) {
    return 'أدخل قيمة من $min إلى $max';
  }

  @override
  String settingDefault(String value) {
    return 'الافتراضي: $value';
  }

  @override
  String get resetToDefault => 'إعادة إلى الافتراضي';

  @override
  String get deleteUser => 'حذف المستخدم';

  @override
  String get checkInBatteryOptimized =>
      'السماح لتطبيق WPC CRM بالعمل في الخلفية (إيقاف تحسين البطارية)';

  @override
  String get checkInAutostartOff => 'التشغيل التلقائي متوقف لتطبيق WPC CRM';

  @override
  String get allowBackgroundForAttendance =>
      'اسمح للتطبيق بالعمل في الخلفية ليُسجَّل حضورك عند وصولك إلى موقع العمل';

  @override
  String get openAutostart => 'التشغيل التلقائي';

  @override
  String get openBatterySaver => 'توفير البطارية';

  @override
  String get locationDisclosureTitle => 'استخدام الموقع في الخلفية';

  @override
  String get locationDisclosureTracking =>
      'يجمع تطبيق WPC CRM بيانات الموقع لعرض موقعك لمدرائك على خريطة الفريق المباشرة، وحفظ سجل مسارك اليومي، والتأكد من أن زيارات العملاء تتم عند العميل، خلال ساعات عملك، حتى عندما يكون التطبيق مغلقًا أو غير مستخدم.';

  @override
  String get locationDisclosureAttendance =>
      'يجمع تطبيق WPC CRM بيانات الموقع لتسجيل حضورك تلقائيًا عند وصولك إلى موقع العمل وتسجيل مغادرتك له، حتى عندما يكون التطبيق مغلقًا أو غير مستخدم. ولموظفي المكتب يسجّل التطبيق أيضًا موقعك من الساعة 08:00 إلى 18:00 في أيام عملك، لتكون أوقات وصولك وحضورك صحيحة، ولا يظهر على أي خريطة مباشرة.';

  @override
  String get locationDisclosureNext =>
      'يُستخدم موقعك فقط لعملك مع الشركة ولا يُستخدم للإعلانات. في الشاشة التالية اختر \"السماح طوال الوقت\".';

  @override
  String get locationDisclosureNo => 'لا، شكرًا';

  @override
  String get locationDisclosureContinue => 'متابعة';

  @override
  String get addToWhosePlan => 'إضافة إلى خطة من اليوم؟';

  @override
  String personsPlan(String name) {
    return 'خطة $name';
  }

  @override
  String addToPersonsPlanToday(String name) {
    return 'إضافة إلى خطة $name اليوم';
  }

  @override
  String onPersonsPlanToday(String name) {
    return 'في خطة $name اليوم';
  }

  @override
  String addedToPersonsPlan(String name) {
    return 'أُضيف إلى خطة $name لليوم';
  }

  @override
  String get dayView => 'يوم';

  @override
  String get weekView => 'أسبوع';

  @override
  String get monthView => 'شهر';

  @override
  String get clearAllFilters => 'مسح كل الفلاتر';

  @override
  String workedOf(String worked, String scheduled) {
    return '$worked من $scheduled';
  }

  @override
  String get stillIn => 'ما زال في الدوام';

  @override
  String startAt(String time) {
    return 'البداية $time';
  }

  @override
  String get notInYet => 'لم يحضر بعد';

  @override
  String checkedInAtTime(String time) {
    return 'سجّل الحضور $time';
  }

  @override
  String get onSite => 'في الموقع';

  @override
  String get notOnSite => 'خارج الموقع';

  @override
  String get leftTheSite => 'غادر الموقع';

  @override
  String get checkedOutTitle => 'سجّل الانصراف';

  @override
  String get workedSoFar => 'ساعات العمل حتى الآن';

  @override
  String delaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count متأخرًا',
      few: '$count متأخرين',
      two: 'متأخران',
      one: 'متأخر واحد',
      zero: 'التأخير',
    );
    return '$_temp0';
  }

  @override
  String get noDelays => 'لم يتأخر أحد';

  @override
  String get searchByName => 'ابحث بالاسم';

  @override
  String get viewStatus => 'الحالة';

  @override
  String get viewWorkedHours => 'الساعات';

  @override
  String get viewDelays => 'التأخير';

  @override
  String get noOneMatches => 'لا أحد مطابق';

  @override
  String get mrScore => 'النقاط';

  @override
  String mrHowScored(
    int target,
    int efficiency,
    int clients,
    int newClients,
    int first,
  ) {
    return 'النقاط من 100: الهدف $target نقطة (النسبة المحققة حتى 100%؛ بدون هدف يُقارن بالأكثر نشاطًا)، الكفاءة $efficiency، العملاء الذين زارهم $clients، العملاء الجدد $newClients والزيارات الأولى $first (كل منها مقارنة بالأفضل في الفريق).';
  }

  @override
  String get mrTargetAchieved => 'تحقق الهدف';

  @override
  String get mrTargetMissed => 'لم يتحقق الهدف';

  @override
  String get mrNoTarget => 'لا يوجد هدف';

  @override
  String get mrWorkDays => 'أيام العمل الميداني';

  @override
  String get mrVisitsPerDay => 'زيارات في اليوم';

  @override
  String get mrClientsVisited => 'العملاء الذين تمت زيارتهم';

  @override
  String get mrFirstVisits => 'زيارات أولى';

  @override
  String get mrRevisited => 'زيارات متكررة';

  @override
  String get mrNewClients => 'عملاء جدد';

  @override
  String mrEfficiencyHint(int days) {
    return 'الوقت اللازم للزيارات بوتيرة الفريق ÷ الوقت الفعلي، متوسط $days أيام فيها زيارتان أو أكثر';
  }

  @override
  String get mrDrivingKmColumn => 'كم القيادة يوميًا';

  @override
  String get mrClientType => 'نوع العميل';

  @override
  String get mrClient => 'العميل';

  @override
  String get mrNoVisits => 'لا توجد زيارات في هذه الفترة';

  @override
  String get mrClientTypes => 'أنواع العملاء الذين تمت زيارتهم';

  @override
  String get mrTypesHint => 'عملاء · زيارات';

  @override
  String get mrNoTag => 'بدون نوع';

  @override
  String get mrAverageDay => 'اليوم المتوسط';

  @override
  String mrAverageDayHint(int days) {
    return 'من $days أيام بمسار تحديد الموقع';
  }

  @override
  String get mrNoGps => 'لا توجد مسارات لتحديد الموقع في هذه الفترة';

  @override
  String get mrTimePerClient => 'الوقت عند كل عميل';

  @override
  String get mrAtClientsDay => 'عند العملاء يوميًا';

  @override
  String get mrDrivingDay => 'القيادة يوميًا';

  @override
  String mrDayStartEnd(String start, String end) {
    return '$start – $end';
  }

  @override
  String get mrFirstToLast => 'من أول عميل إلى آخر عميل';

  @override
  String mrKm(String km) {
    return '$km كم';
  }

  @override
  String get mrDistance => 'المسافة المقطوعة';

  @override
  String mrGpsDays(int days) {
    return '$days أيام بنظام GPS';
  }

  @override
  String get transfersShowMap => 'عرض على الخريطة';

  @override
  String get transfersShowList => 'عرض كقائمة';

  @override
  String transfersNoLocation(int count) {
    return '$count من هؤلاء العملاء بلا موقع ولا يظهرون على الخريطة';
  }

  @override
  String get transferLegendVisited => 'تمت زيارته';

  @override
  String get transferLegendCalled => 'تم الاتصال';

  @override
  String get transferLegendWaiting => 'لم تتم زيارته بعد';

  @override
  String get transferLegendLate => 'لم تتم زيارته منذ 14 يومًا أو أكثر';

  @override
  String get transferPinHelp =>
      'الدبابيس: لون المندوب الجديد وأحرفه الأولى؛ والحلقة تبين هل زاره.';

  @override
  String mrFirstVisitList(int count) {
    return 'زيارة لأول مرة ($count)';
  }

  @override
  String mrRevisitedList(int count) {
    return 'زيارة متكررة ($count)';
  }

  @override
  String get mrFirstVisitsHint =>
      'زيارة أولى = لم يزر أحد العميل من قبل في التطبيق. زيارة متكررة = تمت زيارته قبل هذه الفترة، أو زاره زميل في وقت سابق منها.';

  @override
  String mrPoints(String points) {
    return '$points / 100';
  }

  @override
  String get reportPdfTitle => 'تقرير المبيعات';

  @override
  String rankOfTeam(int rank, int count) {
    return 'المرتبة $rank من $count';
  }

  @override
  String get keyNumbers => 'الأرقام الرئيسية';

  @override
  String get scoreBreakdown => 'تفاصيل النقاط';

  @override
  String pdfCreated(String date) {
    return 'أُنشئ في $date';
  }

  @override
  String pdfPage(int page, int pages) {
    return 'صفحة $page من $pages';
  }

  @override
  String get downloadPdfs => 'تنزيل تقارير PDF';

  @override
  String get pdfChoosePeople => 'ملف PDF لكل مندوب';

  @override
  String pdfDownloadCount(int count) {
    return 'تنزيل ($count)';
  }

  @override
  String get pdfOne => 'تقرير PDF';

  @override
  String get mrFirstAndRevisited => 'الزيارات الأولى والمتكررة';

  @override
  String get scoreInfoTitle => 'كيف تُحسب النقاط';

  @override
  String get scoreInfoIntro =>
      'يحصل كل مندوب مبيعات على 100 نقطة كحد أقصى من خمسة أجزاء. الترتيب حسب النقاط، والنقاط المتساوية تتشارك المرتبة. مدراء الحسابات لا يدخلون الترتيب.';

  @override
  String get scoreInfoPart => 'الجزء';

  @override
  String get scoreInfoMax => 'الحد الأقصى';

  @override
  String get scoreInfoHow => 'طريقة القياس';

  @override
  String get scoreInfoPoints => 'النقاط';

  @override
  String get scorePartTargetHow =>
      '(الزيارات + المكالمات) ÷ الهدف، حتى 100%. بدون هدف: مقارنة بأكثر مندوب نشاطًا.';

  @override
  String get scorePartEfficiencyHow =>
      'متوسط كفاءة الأيام التي فيها زيارتان أو أكثر (انظر المسارات).';

  @override
  String get scorePartClientsHow =>
      'العملاء الذين تمت زيارتهم أو الاتصال بهم، مقارنة بالمندوب الأعلى.';

  @override
  String get scorePartNewHow =>
      'العملاء الجدد الذين أضافهم أو استُوردوا له، مقارنة بالأعلى.';

  @override
  String get scorePartFirstHow =>
      'العملاء الذين زيروا لأول مرة، مقارنة بالأعلى.';

  @override
  String get scoreInfoExample =>
      'مثال: 54 زيارة ومكالمة مع هدف 60 = 90%، أي 0.9 × 35 = 31.5 نقطة. و10 زيارات أولى بينما الأفضل 20: 0.5 × 10 = 5 نقاط.';

  @override
  String scoreFor(String name, String points) {
    return 'نقاط $name: $points / 100';
  }

  @override
  String get salesExecutivesSection => 'مندوبو المبيعات';

  @override
  String get kamSection => 'مدراء الحسابات الرئيسية';

  @override
  String get kamSectionNote =>
      'لم تُحدد بعد طريقة قياس أداء مدراء الحسابات. هذه أرقامهم الخاصة، بدون نقاط أو ترتيب.';

  @override
  String get kamVisitsWithTeam => 'زيارات مع فريقه';

  @override
  String get kamTeamSize => 'أعضاء الفريق';

  @override
  String get kamTeamVisits => 'زيارات ومكالمات الفريق';

  @override
  String firstAndRevisitedShort(int first, int revisited) {
    return '$first أولى · $revisited متكررة';
  }

  @override
  String onScheduleShort(String value) {
    return 'ضمن الموعد $value';
  }

  @override
  String get moreActions => 'المزيد';

  @override
  String get settingAwayGrace => 'مدة الابتعاد عن الموقع قبل تسجيل الانصراف';

  @override
  String get settingAwayGraceHelp =>
      'من لا يُسمح لهم بمغادرة موقع العمل ويبقون بعيدين أكثر من هذه المدة يُسجَّل انصرافهم وقت مغادرتهم. العودة تسجّل حضورهم من جديد.';

  @override
  String get leaveSiteAllowed => 'مسموح بمغادرة الموقع';

  @override
  String get leaveSiteAllowedHelp =>
      'مغادرة الموقع خلال يوم العمل لا تسجّل الانصراف (عادة فريق المبيعات والسائقون).';

  @override
  String leaveSiteNotAllowedHelp(int minutes) {
    return 'الابتعاد عن الموقع أكثر من $minutes دقيقة ← يُسجَّل الانصراف وقت المغادرة. العودة تسجّل الحضور من جديد، ولا يُحتسب وقت الغياب.';
  }

  @override
  String get checkOutLeftSite => 'غادر الموقع';

  @override
  String get absenceSick => 'مريض';

  @override
  String get absenceTired => 'متعب';

  @override
  String get absenceCantCome => 'لا أستطيع الحضور';

  @override
  String get absencePickReason => 'اختر السبب';

  @override
  String get absenceWriteReason => 'اكتب السبب';

  @override
  String get absenceSent => 'تم الإرسال. تم إبلاغ الموارد البشرية ومديرك.';

  @override
  String get absenceTitle => 'لن أحضر إلى العمل';

  @override
  String get tomorrow => 'غداً';

  @override
  String get absenceReasonField => 'السبب';

  @override
  String get absenceSickHelp =>
      'أرفق تقريرك الطبي (الآن أو لاحقاً). لا تقبل الموارد البشرية اليوم كإجازة مرضية إلا بالتقرير.';

  @override
  String get absenceSend => 'إرسال';

  @override
  String absentToday(String reason) {
    return 'لن أحضر اليوم · $reason';
  }

  @override
  String absentOn(String date, String reason) {
    return 'لن أحضر يوم $date · $reason';
  }

  @override
  String get absenceUndoConfirm => 'هل تريد التراجع عن هذا الغياب؟';

  @override
  String get absenceUndo => 'تراجع';

  @override
  String get sickReportMissing =>
      'لم يُرفق التقرير الطبي بعد – مطلوب لاعتماد الإجازة المرضية';

  @override
  String get attachSickReport => 'إرفاق التقرير الطبي';

  @override
  String get openRequest => 'فتح الطلب';

  @override
  String get absenceButton => 'لن تحضر إلى العمل؟';

  @override
  String dayReportedAbsent(String reason) {
    return 'أبلغ بالغياب: $reason';
  }

  @override
  String daysReportedAbsent(int count) {
    return '$count غياب مُبلّغ عنه';
  }

  @override
  String get reportedAbsent => 'أبلغ بالغياب';

  @override
  String leaveDocumentMissingMine(String document) {
    return 'أرفق $document – لا يمكن اعتماد الطلب بدونه.';
  }

  @override
  String leaveDocumentMissing(String document) {
    return 'بانتظار $document – يمكن اعتماده بعد إرفاقه.';
  }

  @override
  String notifAbsenceReported(String name, String day, String reason) {
    return '$name لن يحضر إلى العمل يوم $day – $reason';
  }

  @override
  String get checkOutHr => 'صحّحته الموارد البشرية';

  @override
  String get asSickLeave => 'إجازة مرضية';

  @override
  String get asAnnualLeave => 'إجازة سنوية';

  @override
  String get absenceWaiting => 'بانتظار الموارد البشرية';

  @override
  String absenceAcceptedAs(String leave) {
    return 'مقبول ك$leave';
  }

  @override
  String get absenceRejectedText => 'غير مقبول – يُحتسب يوم غياب';

  @override
  String get attachDocument => 'إرفاق مستند';

  @override
  String documentsCount(int count) {
    return '$count مستند';
  }

  @override
  String get rejectAbsence => 'رفض';

  @override
  String acceptAbsenceAs(String leave) {
    return 'قبول ك$leave';
  }

  @override
  String get rejectAbsenceHelp => 'يُحتسب اليوم يوم غياب.';

  @override
  String get acceptAbsenceHelp =>
      'يُحفظ طلب إجازة معتمد لهذا اليوم ويُخصم من رصيده، ويُبلَّغ مديره المباشر.';

  @override
  String get absenceNotFound => 'تم التراجع عن هذا الغياب.';

  @override
  String get sickReportMissingMine =>
      'أرفق تقريرك الطبي – لا يمكن قبول اليوم كإجازة مرضية بدونه.';

  @override
  String get decideAbsence => 'القرار';

  @override
  String get sickNeedsDocument =>
      'الإجازة المرضية تحتاج إلى مستند مرفق (تقرير طبي).';

  @override
  String annualLeaveLeft(String days) {
    return 'المتبقي من الإجازة السنوية: $days يوم';
  }

  @override
  String absencesWaiting(int count) {
    return 'غيابات بانتظار القرار ($count)';
  }

  @override
  String notifAbsenceAccepted(String name, String day, String leave) {
    return 'قبل $name غيابك يوم $day ك$leave';
  }

  @override
  String notifAbsenceRejected(String name, String day) {
    return 'لم يقبل $name غيابك يوم $day – يُحتسب يوم غياب';
  }

  @override
  String notifTeamOnLeave(String name, String dates) {
    return '$name في إجازة: $dates';
  }

  @override
  String get correctedByHr => 'صحّحته الموارد البشرية';

  @override
  String overtimeEndUnknown(String time) {
    return 'نهاية العمل الإضافي غير مؤكدة · آخر تواجد $time';
  }

  @override
  String get overtimeEndUnknownHelp =>
      'لم يُسجَّل خروج أو وصول ولم يؤكد الهاتف مكانه بعد ذلك، لذا يتوقف العمل الإضافي عند هذا الوقت. إذا عمل لوقت أطول، صحّح هذا اليوم.';

  @override
  String awayTime(String time) {
    return 'غائب $time (غير محتسب)';
  }

  @override
  String correctedBy(String name) {
    return 'صحّحه $name';
  }

  @override
  String get correctDay => 'تصحيح هذا اليوم';

  @override
  String get removeCorrection => 'إزالة التصحيح';

  @override
  String get openAbsence => 'فتح الغياب';

  @override
  String get openUser => 'فتح المستخدم';

  @override
  String get correctionNoteNeeded => 'اكتب سبب تصحيح اليوم';

  @override
  String correctDayOf(String name) {
    return 'تصحيح يوم $name';
  }

  @override
  String get correctDayHelp =>
      'يحل محل ما سجّله الهاتف. بدون وقت انصراف تبقى أحداث الهاتف اللاحقة محتسبة.';

  @override
  String get checkOutFromPhone => 'من الهاتف';

  @override
  String get add => 'إضافة';

  @override
  String get correctionNote => 'سبب التصحيح';

  @override
  String get identityReason => 'أكّد هويتك لتسجيل الحضور أو الانصراف';

  @override
  String get identityLocked =>
      'محاولات كثيرة – افتح الهاتف برمز PIN ثم حاول مجدداً.';

  @override
  String get absencesTab => 'الغيابات';

  @override
  String get absenceAcceptedFilter => 'مقبولة';

  @override
  String get absenceRejectedFilter => 'غير مقبولة';

  @override
  String get noAbsences => 'لا توجد غيابات هنا.';

  @override
  String transfersWaiting(int count) {
    return 'لم تتم زيارتها بعد ($count)';
  }

  @override
  String transfersArchived(int count) {
    return 'المؤرشفة ($count)';
  }

  @override
  String get transfersAllVisited =>
      'تمت زيارة كل العملاء المنقولين – راجع المؤرشفة.';

  @override
  String get transfersNoneArchived =>
      'لا شيء في الأرشيف بعد. ينتقل العميل إلى هنا بعد أن يزوره البائع الجديد أو يتصل به، أو عند نقله مرة أخرى.';

  @override
  String get deletedUser => 'مستخدم محذوف';

  @override
  String get emailOrUsername => 'البريد الإلكتروني أو اسم المستخدم';

  @override
  String get username => 'اسم المستخدم';

  @override
  String get signInWith => 'يسجّل الدخول باستخدام';

  @override
  String get usernameHelp =>
      'أحرف إنجليزية وأرقام و . _ - (من 3 إلى 30). يسجّل الدخول به دون حاجة إلى بريد إلكتروني.';

  @override
  String get invalidUsername => 'من 3 إلى 30 حرفًا (a–z) أو أرقامًا أو . _ -';

  @override
  String get usernameInUse => 'اسم المستخدم هذا مستخدم بالفعل. اختر اسمًا آخر.';

  @override
  String get setPassword => 'تعيين كلمة المرور';

  @override
  String setPasswordFor(String name) {
    return 'كلمة مرور جديدة لـ $name';
  }

  @override
  String passwordSetFor(String name) {
    return 'تم تغيير كلمة مرور $name. أخبره بكلمة المرور الجديدة.';
  }

  @override
  String get usernameResetByManager =>
      'لا يمكن إرسال رابط إعادة التعيين لحسابات اسم المستخدم. اطلب من مديرك تعيين كلمة مرور جديدة.';

  @override
  String get usernameAccountInfo =>
      'نسيت كلمة المرور؟ اطلب من مديرك تعيين كلمة مرور جديدة.';

  @override
  String get reservedEmail =>
      'لا يمكن استخدام هذا العنوان. أدخل بريدك الإلكتروني.';

  @override
  String get selectRole => 'اختر الدور';

  @override
  String get usernameAvailable => 'متاح';

  @override
  String get usernameTaken => 'مستخدم لحساب آخر';

  @override
  String get isManager => 'مدير';

  @override
  String get isManagerHelp =>
      'يمكن اختياره مديراً مباشراً لموظفين آخرين، مثل مدير الحسابات.';

  @override
  String get directManager => 'المدير المباشر';

  @override
  String directManagerAuto(String names) {
    return 'تلقائي ($names)';
  }

  @override
  String get directManagerHelp =>
      'يوافق على الانصراف المبكر ويُبلَّغ عند إجازة الموظف أو غيابه.';

  @override
  String get askLeaveEarly => 'طلب انصراف مبكر';

  @override
  String askLeaveEarlyHelp(String time, String names) {
    return 'ينتهي يوم عملك الساعة $time. يجب أن يوافق $names قبل أن تسجّل الانصراف.';
  }

  @override
  String earlyRequestSent(String names) {
    return 'أُرسل الطلب إلى $names';
  }

  @override
  String earlyWaiting(String names) {
    return 'طلبت الانصراف مبكراً – بانتظار $names';
  }

  @override
  String earlyApproved(String name) {
    return 'وافق $name – يمكنك تسجيل الانصراف';
  }

  @override
  String earlyRejected(String name) {
    return 'لم يوافق $name على الانصراف المبكر';
  }

  @override
  String get earlyAskAgain => 'اطلب مرة أخرى';

  @override
  String earlyRequestsWaiting(int count) {
    return 'طلبات انصراف مبكر ($count)';
  }

  @override
  String notifEarlyCheckoutRequested(String name) {
    return 'يطلب $name الانصراف مبكراً اليوم';
  }

  @override
  String notifEarlyCheckoutApproved(String name) {
    return 'وافق $name على انصرافك المبكر – يمكنك تسجيل الانصراف الآن';
  }

  @override
  String notifEarlyCheckoutRejected(String name) {
    return 'لم يوافق $name على انصرافك المبكر';
  }

  @override
  String get balanceColType => 'الإجازة';

  @override
  String get balanceColEntitled => 'المستحق';

  @override
  String get balanceColUsed => 'المستخدم';

  @override
  String get balanceColWaiting => 'بانتظار الموافقة';

  @override
  String get balanceColLeft => 'المتبقي';

  @override
  String get pageAccess => 'صلاحيات الصفحات';

  @override
  String get pageAccessSubtitle => 'الأدوار التي يمكنها فتح كل صفحة';

  @override
  String get pageAccessHelp =>
      'الصفحات المظللة متاحة للدور؛ اضغط على الصفحة للسماح بها أو إزالتها (يُحفظ فوراً). الصفحات الرمادية بقفل لا يمكن منحها لهذا الدور لأن بياناتها محمية عنه (مثلاً السائقون لا يرون العملاء).';

  @override
  String get pageAccessLocked =>
      'مفعّلة دائماً لمدير المبيعات والمدير العام، حتى لا يُمنع أحد من الإعدادات.';

  @override
  String get pageAccessMarkedManagers =>
      'من حُدّد كـ\"مدير\" يرى دائماً حضور فريقه.';

  @override
  String get settingsSectionAccess => 'الصلاحيات';

  @override
  String get pageNotForRole =>
      'غير متاحة لهذا الدور: بيانات هذه الصفحة محمية عنه.';

  @override
  String get showSalespeople => 'إظهار المندوبين';

  @override
  String get hideSalespeople => 'إخفاء المندوبين';

  @override
  String get searchAreaHint => 'منطقة، مثل الرياض، السلام';

  @override
  String get searchAreaHelp => 'اضغط إدخال للانتقال إليها';

  @override
  String get searchAreaGo => 'انتقال';

  @override
  String areaNotFound(String query) {
    return 'لم يُعثر على مكان باسم \"$query\"';
  }

  @override
  String get areaSearchFailed =>
      'تعذّر البحث عن المكان. تحقق من الإنترنت وحاول مرة أخرى.';

  @override
  String get searchArea => 'منطقة';

  @override
  String searchAsArea(String text) {
    return 'ابحث عن \"$text\" كمنطقة';
  }

  @override
  String get showPassword => 'إظهار كلمة المرور';

  @override
  String get hidePassword => 'إخفاء كلمة المرور';

  @override
  String get vehicles => 'المركبات';

  @override
  String get addVehicle => 'إضافة مركبة';

  @override
  String get editVehicle => 'تعديل المركبة';

  @override
  String get noVehicles =>
      'لا توجد مركبات بعد. أضف مركبات الشركة مع سائقيها ومواعيد التجديد.';

  @override
  String get vehiclePlate => 'رقم اللوحة';

  @override
  String get vehiclePlateRequired => 'أدخل رقم اللوحة';

  @override
  String get vehicleMake => 'الشركة المصنّعة';

  @override
  String get vehicleModel => 'الطراز';

  @override
  String get vehicleYear => 'سنة الصنع';

  @override
  String get vehicleColor => 'اللون';

  @override
  String get vehicleVin => 'رقم الهيكل';

  @override
  String get vehicleFirstReading => 'قراءة العداد الآن (كم، اختياري)';

  @override
  String get renewals => 'التجديدات';

  @override
  String get renewalRegistration => 'تسجيل المركبة (الاستمارة)';

  @override
  String get renewalInsurance => 'التأمين';

  @override
  String get renewalInspection => 'الفحص الدوري';

  @override
  String get renewalNotSet => 'غير محدد';

  @override
  String renewalDaysLeft(int days) {
    return 'متبقٍ $days يوم';
  }

  @override
  String get renewalExpiresToday => 'ينتهي اليوم';

  @override
  String renewalExpiredAgo(int days) {
    return 'منتهٍ منذ $days يوم';
  }

  @override
  String renewalUntil(String date) {
    return 'حتى $date';
  }

  @override
  String get renewalExpiry => 'تاريخ الانتهاء';

  @override
  String get markRenewed => 'تم التجديد';

  @override
  String renewDialogTitle(String item) {
    return 'تجديد $item';
  }

  @override
  String get renewDialogHint => 'تاريخ الانتهاء الجديد';

  @override
  String get changeDate => 'تغيير التاريخ';

  @override
  String get setDate => 'تحديد التاريخ';

  @override
  String get renewalHistory => 'سجل التجديد';

  @override
  String renewalHistoryRow(String item, String date) {
    return 'تجديد $item حتى $date';
  }

  @override
  String needsRenewalFilter(int count) {
    return 'تجديد أو زيت مستحق ($count)';
  }

  @override
  String get showInactiveVehicles => 'إظهار غير النشطة';

  @override
  String get mileage => 'المسافة المقطوعة';

  @override
  String kmValue(String km) {
    return '$km كم';
  }

  @override
  String odometerEstimate(String km) {
    return '≈ $km كم الآن';
  }

  @override
  String lastReading(String km, String date) {
    return 'آخر قراءة $km كم بتاريخ $date';
  }

  @override
  String gpsKmSince(String km) {
    return '+ $km كم منذ ذلك (من GPS السائقين)';
  }

  @override
  String gpsKmNoReading(String km) {
    return '$km كم قطعها سائقوها (GPS) منذ تعيينهم';
  }

  @override
  String get noReadingYet =>
      'لا توجد قراءة للعداد بعد – سجّل قراءة ليقدّر التطبيق المسافة.';

  @override
  String get gpsKmHelp =>
      'كيلومترات GPS خطوط مستقيمة بين مواقع السائقين، تُحسب من اليوم التالي لآخر قراءة، لذا تكون أقل قليلاً من العداد. سجّل قراءة من حين لآخر لتصحيحها.';

  @override
  String get recordReading => 'تسجيل قراءة';

  @override
  String get odometerKm => 'قراءة العداد (كم)';

  @override
  String get readingNote => 'ملاحظة (اختياري)';

  @override
  String readingLower(String km) {
    return 'هذه القراءة أقل من القراءة السابقة ($km كم). هل تريد الحفظ؟';
  }

  @override
  String get readings => 'القراءات';

  @override
  String deleteReadingConfirm(String km) {
    return 'حذف القراءة $km كم؟';
  }

  @override
  String get noDriverAssigned => 'لا يوجد سائق';

  @override
  String get changeDrivers => 'تغيير السائقين';

  @override
  String driverOnOtherVehicle(String plate) {
    return 'حالياً على $plate – سينتقل إلى هذه المركبة';
  }

  @override
  String get noDriverUsers => 'لا يوجد سائقون بعد – أضف مستخدمين بدور سائق.';

  @override
  String deleteVehicleConfirm(String plate) {
    return 'حذف المركبة $plate؟ ستُحذف قراءاتها وسجل تجديدها أيضاً.';
  }

  @override
  String vehicleRenewalsDue(int count) {
    return 'تجديدات وتغيير زيت مستحقة للمركبات ($count)';
  }

  @override
  String notifVehicleRenewalDue(
    String vehicle,
    String item,
    int days,
    String date,
  ) {
    return '$vehicle: ينتهي $item بعد $days يوم ($date)';
  }

  @override
  String notifVehicleRenewalExpired(String vehicle, String item, String date) {
    return '$vehicle: انتهى $item ($date)';
  }

  @override
  String get settingVehicleRenewal => 'تذكير تجديد المركبات';

  @override
  String get settingVehicleRenewalHelp =>
      'يتلقى المدير العام ومدير المبيعات ومدير الخدمات اللوجستية تذكيراً قبل هذا العدد من الأيام من انتهاء تسجيل المركبة أو تأمينها أو فحصها الدوري أو بطاقة التشغيل، ويبقى في صفحتهم الرئيسية حتى يُدخل التاريخ الجديد.';

  @override
  String get settingsSectionHr => 'الموارد البشرية';

  @override
  String get department => 'القسم';

  @override
  String get departments => 'الأقسام';

  @override
  String departmentAutomatic(String name) {
    return 'تلقائي ($name)';
  }

  @override
  String get noDepartment => 'بدون قسم';

  @override
  String get addDepartment => 'إضافة قسم';

  @override
  String get departmentsHelp =>
      'الأقسام التي ينتمي إليها الموظفون. تصفّي الموارد البشرية الموظفين حسبها، وإلى أن يُختار قسم يأخذ الموظف قسم دوره.';

  @override
  String deleteDepartmentBody(int count) {
    return '$count موظف في هذا القسم، وسيظهر كقسم محذوف. لا يمكن التراجع.';
  }

  @override
  String get joiningDate => 'تاريخ الالتحاق';

  @override
  String get joiningDateNotSet => 'لم يُحدد تاريخ الالتحاق';

  @override
  String joinedOn(String date) {
    return 'التحق في $date';
  }

  @override
  String get leaveYearCalendarHint =>
      'لا يوجد تاريخ التحاق: تُحسب أرصدة الإجازات حسب السنة الميلادية (1 يناير – 31 ديسمبر).';

  @override
  String get leaveYearJoiningHint =>
      'تبدأ أرصدة الإجازات من جديد كل سنة في تاريخ الالتحاق. الأيام السنوية المستهلكة بالزيادة تُخصم من السنة التالية، والأيام المتبقية تُرحّل فقط إذا سمحت الموارد البشرية بذلك.';

  @override
  String leaveBalancePeriod(String period) {
    return 'رصيد الإجازات $period';
  }

  @override
  String get balanceColCarried => 'مرحّل';

  @override
  String leaveCarriedDays(String days) {
    return '$days من السنة الماضية';
  }

  @override
  String get pastLeaveYears => 'سنوات الإجازة السابقة';

  @override
  String annualTaken(String used, String of) {
    return 'السنوية: $used من $of يوم';
  }

  @override
  String carriedToNextYear(String days) {
    return '$days للسنة التالية';
  }

  @override
  String pastYearRow(String used, String of, String left) {
    return '$used من $of · متبقٍ $left';
  }

  @override
  String get annualCarryOver => 'ترحيل الإجازة السنوية';

  @override
  String get annualCarryOverOn =>
      'الأيام المتبقية في نهاية سنة الإجازة تُرحّل إلى السنة التالية. الأيام المستهلكة بالزيادة تُخصم دائماً من السنة التالية.';

  @override
  String get annualCarryOverOff =>
      'الأيام المتبقية في نهاية سنة الإجازة تسقط (يُعاد ضبط الرصيد). الأيام المستهلكة بالزيادة تُخصم دائماً من السنة التالية.';

  @override
  String overtimeQuestion(String time) {
    return 'انتهى دوامك الساعة $time. هل ستعمل وقتاً إضافياً؟';
  }

  @override
  String overtimeQuestionHelp(String time) {
    return 'يُحتسب العمل الإضافي من $time عند بدئه وأنت في موقع العمل.';
  }

  @override
  String get overtimeDeclinedText => 'لا عمل إضافي اليوم – هل غيّرت رأيك؟';

  @override
  String get startOvertime => 'بدء العمل الإضافي';

  @override
  String get notToday => 'ليس اليوم';

  @override
  String get later => 'لاحقاً';

  @override
  String get overtimeNotAtSite =>
      'أنت لست في موقع العمل – لا يمكن بدء العمل الإضافي إلا هناك.';

  @override
  String overtimeStartedToast(String time) {
    return 'بدأ العمل الإضافي – يُحتسب من $time';
  }

  @override
  String overtimeSince(String time, String duration) {
    return 'عمل إضافي منذ $time · $duration';
  }

  @override
  String get driveOvertimeTitle => 'بدأ العمل الإضافي';

  @override
  String driveOvertimeRunning(String time) {
    return 'عمل إضافي منذ $time – ينتهي عند وصولك إلى المنزل أو موقع العمل.';
  }

  @override
  String overtimeWaiting(String duration) {
    return 'عمل إضافي $duration · بانتظار الاعتماد';
  }

  @override
  String overtimeApprovedText(String duration) {
    return 'العمل الإضافي المعتمد: $duration';
  }

  @override
  String overtimeApprovedBy(String duration, String name) {
    return 'اعتمد $name مدة $duration';
  }

  @override
  String get approveOvertime => 'اعتماد العمل الإضافي';

  @override
  String overtimeRecorded(String duration, String from, String to) {
    return 'المسجّل: $duration ($from – $to)';
  }

  @override
  String overtimeToApprove(int count) {
    return 'عمل إضافي بانتظار الاعتماد ($count)';
  }

  @override
  String get overtimeApprovedMinutes => 'العمل الإضافي المعتمد';

  @override
  String get rejectOvertime => 'رفض';

  @override
  String get overtimeRejectedText => 'لم يُعتمد العمل الإضافي';

  @override
  String overtimeRejectedBy(String name) {
    return 'رفض $name العمل الإضافي';
  }

  @override
  String get overtimeRejectHelp =>
      'الرفض لا يحتسب أي وقت من هذا العمل الإضافي. لاحتساب جزء منه غيّر المدة ثم اعتمده.';

  @override
  String get settingDriveHomeGrace =>
      'طريق العودة إلى المنزل بعد الدوام (السائقون)';

  @override
  String get settingDriveHomeGraceHelp =>
      'السائق الذي ما زال يقود عند نهاية الدوام ويصل إلى منزله خلال هذه المدة يكون في طريق العودة: لا عمل إضافي. إذا كان في موقع العمل أو المنزل عند النهاية: لا عمل إضافي. الوصول إلى موقع العمل بعد النهاية، أو إلى المنزل بعد هذه المدة، يُحتسب عملًا إضافيًا من نهاية الدوام.';

  @override
  String get setHomeLocationTitle => 'حدّد موقع منزلك';

  @override
  String get setHomeLocationText =>
      'مطلوب لحساب العمل الإضافي: طريق العودة إلى المنزل بعد الدوام ليس عملًا إضافيًا. وأنت في المنزل اضغط \"استخدام موقعي\"، أو اختره على الخريطة. بعد الحفظ لا يغيّره إلا مديرك.';

  @override
  String get homeLocationSaved => 'تم حفظ موقع المنزل';

  @override
  String get checkOutArrivedHome => 'وصل إلى المنزل (عمل إضافي أثناء القيادة)';

  @override
  String get checkOutArrivedSite =>
      'وصل إلى موقع العمل (عمل إضافي أثناء القيادة)';

  @override
  String get checkOutOvertimeCap => 'بلغ الحد الأقصى للعمل الإضافي';

  @override
  String get homeLocation => 'موقع المنزل';

  @override
  String get homeLocationHelp =>
      'ينتهي العمل الإضافي للسائق عند وصوله إلى هنا أو إلى موقع العمل؛ الوصول إلى المنزل بعد نهاية الدوام بقليل هو طريق العودة وليس عملًا إضافيًا.';

  @override
  String get homeLocationNotSet => 'غير محدد';

  @override
  String notifOvertimeAsk(String time, String site) {
    return 'انتهى دوامك الساعة $time وما زلت في $site. هل ستعمل وقتاً إضافياً؟ اضغط لبدئه.';
  }

  @override
  String notifOvertimeAskReminder(String time) {
    return 'تذكير: انتهى دوامك الساعة $time. هل ستعمل وقتاً إضافياً؟ اضغط لبدئه.';
  }

  @override
  String notifOvertimeConfirmed(String name, String site, String time) {
    return 'بدأ $name العمل الإضافي$site (من $time) – اعتمده من صفحة الحضور';
  }

  @override
  String notifDriveOvertime(String name, String time) {
    return '$name ما زال يقود بعد نهاية الدوام ($time) – بدأ العمل الإضافي';
  }

  @override
  String notifDriveOvertimeSelf(String time) {
    return 'انتهى دوامك الساعة $time وأنت في الطريق – بدأ العمل الإضافي. ينتهي عند وصولك إلى المنزل أو موقع العمل.';
  }

  @override
  String get renewalOperatingCard => 'بطاقة التشغيل';

  @override
  String get oilChange => 'تغيير الزيت';

  @override
  String get oilIntervalKm => 'تغيير الزيت كل (كم، اختياري)';

  @override
  String oilEvery(String km) {
    return 'كل $km كم';
  }

  @override
  String oilNextAt(String km) {
    return 'التالي عند $km كم';
  }

  @override
  String oilLastChange(String km, String date) {
    return 'آخر تغيير عند $km كم بتاريخ $date';
  }

  @override
  String oilKmLeft(String km) {
    return 'باقي $km كم';
  }

  @override
  String oilOverdue(String km) {
    return 'مستحق – تجاوز $km كم';
  }

  @override
  String get oilNoChangeYet => 'لم يُسجّل تغيير زيت';

  @override
  String get oilNotTracked =>
      'حدّد كل كم كيلومتر يُغيَّر الزيت، فيُذكَّر المدير العام ومدير المبيعات ومدير الخدمات اللوجستية قبل موعده.';

  @override
  String get setOilInterval => 'تحديد المسافة';

  @override
  String get recordOilChange => 'تم تغيير الزيت';

  @override
  String get recordOilChangeTitle => 'تسجيل تغيير الزيت';

  @override
  String deleteOilChangeConfirm(String km) {
    return 'حذف تغيير الزيت عند $km كم؟ تبقى قراءة العداد.';
  }

  @override
  String notifVehicleOilDueSoon(String vehicle, int km, String at) {
    return '$vehicle: تغيير الزيت بعد $km كم (عند $at كم)';
  }

  @override
  String notifVehicleOilDue(String vehicle, String at) {
    return '$vehicle: حان موعد تغيير الزيت (كان عند $at كم)';
  }

  @override
  String get settingOilDueSoon => 'تذكير تغيير الزيت';

  @override
  String get settingOilDueSoonHelp =>
      'يُذكَّر المدير العام ومدير المبيعات ومدير الخدمات اللوجستية قبل موعد تغيير زيت المركبة بهذا العدد من الكيلومترات (تقدير من آخر قراءة وكيلومترات GPS لسائقيها)، ومرة أخرى عند حلول الموعد؛ ويبقى في صفحتهم الرئيسية حتى يُسجَّل التغيير.';

  @override
  String get lastOilChangeKm => 'آخر تغيير زيت عند (كم، اختياري)';

  @override
  String get lastOilChangeDay => 'تاريخ آخر تغيير زيت';

  @override
  String oilOdometerHelp(String km) {
    return 'تقدير التطبيق الآن ≈ $km كم. أدخل قراءة العداد: إن اختلفت يُعتمد رقمك كعداد المركبة.';
  }

  @override
  String get oilOdometerHelpNoEstimate =>
      'أدخل قراءة العداد؛ وتُعتمد أيضاً كعداد المركبة.';

  @override
  String oilMileageCorrected(String km, String estimate) {
    return 'صُحّح العداد إلى $km كم (كان التقدير $estimate كم)';
  }

  @override
  String arrivedByGps(String time) {
    return 'محسوب من وقت الوصول إلى الموقع (GPS) · تم الضغط على تسجيل الحضور الساعة $time';
  }

  @override
  String get atSiteNotCheckedInTitle => 'أنت في موقع العمل';

  @override
  String atSiteNotCheckedIn(String site) {
    return 'أنت في $site ولم تسجّل حضورك. سجّل حضورك الآن.';
  }

  @override
  String notifAtSite(String site, String time) {
    return 'أنت في $site منذ الساعة $time ولم تسجّل حضورك – سجّل الحضور';
  }

  @override
  String get earlyCheckoutsTab => 'الخروج المبكر';

  @override
  String get noEarlyCheckouts => 'لا توجد طلبات خروج مبكر';

  @override
  String approvedByName(String name) {
    return 'وافق عليه $name';
  }

  @override
  String rejectedByName(String name) {
    return 'رفضه $name';
  }

  @override
  String get yourTurn => 'دورك';

  @override
  String get calIn => 'دخول';

  @override
  String get calOut => 'خروج';

  @override
  String get calWorked => 'العمل';

  @override
  String get calAway => 'خارج الموقع';

  @override
  String get calLate => 'تأخير';

  @override
  String get calOvertime => 'إضافي';

  @override
  String get calAfterHours => 'بعد الدوام';

  @override
  String calMore(int n) {
    return '+$n أخرى';
  }

  @override
  String get calOvertimeWaiting => 'بانتظار الموافقة';

  @override
  String calOvertimeApproved(String time) {
    return 'تمت الموافقة $time';
  }

  @override
  String get personMonthEmpty => 'لا يوجد حضور لهذا الشخص في هذا الشهر.';

  @override
  String leaveDocumentLater(String document) {
    return '$document – أرفقها الآن أو لاحقاً';
  }

  @override
  String leaveTicketMissingMine(String document) {
    return 'أرفق $document عندما تتوفر لديك.';
  }

  @override
  String leaveTicketMissing(String document) {
    return 'لم تُرفق $document بعد.';
  }

  @override
  String get documentCanComeLater =>
      'يمكن إرفاقه لاحقاً (غير مطلوب للإرسال أو الموافقة)';

  @override
  String departureTimeOn(String day) {
    return 'وقت المغادرة يوم $day';
  }

  @override
  String get setTime => 'حدد الوقت';

  @override
  String departureHelp(String end, String day) {
    return 'ستغادر بعد الدوام ($end) يوم $day؟ لا يُحسب ذلك اليوم.';
  }

  @override
  String departureAfterWork(String start) {
    return 'بعد ساعات العمل – تُحسب الإجازة من $start';
  }

  @override
  String departureDuringWork(String day) {
    return 'خلال ساعات العمل – يُحسب $day يوم إجازة';
  }

  @override
  String travelAfterWorkOn(String day, String time) {
    return 'المغادرة $day الساعة $time';
  }
}
