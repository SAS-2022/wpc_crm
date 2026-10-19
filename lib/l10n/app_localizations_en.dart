// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'WPC CRM';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get signIn => 'Sign in';

  @override
  String get signOut => 'Sign out';

  @override
  String get signInFailed => 'Wrong email or password';

  @override
  String get language => 'Language';

  @override
  String get noAccessTitle => 'No access';

  @override
  String get noAccessBody =>
      'Your account is not set up or has been deactivated. Contact your sales manager.';

  @override
  String welcome(String name) {
    return 'Welcome, $name';
  }

  @override
  String get roleSalesExec => 'Sales executive';

  @override
  String get roleKam => 'Key account manager';

  @override
  String get roleSalesManager => 'Sales manager';

  @override
  String get roleGm => 'General manager';

  @override
  String get clients => 'Clients';

  @override
  String get map => 'Map';

  @override
  String get visits => 'Visits';

  @override
  String get liveTracking => 'Live tracking';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get users => 'Users';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get addUser => 'Add user';

  @override
  String get editUser => 'Edit user';

  @override
  String get name => 'Name';

  @override
  String get phone => 'Phone';

  @override
  String get role => 'Role';

  @override
  String get keyAccountManager => 'Key account manager';

  @override
  String get none => 'None';

  @override
  String get active => 'Active';

  @override
  String get inactive => 'Inactive';

  @override
  String get save => 'Save';

  @override
  String get required => 'Required';

  @override
  String get invalidEmail => 'Invalid email';

  @override
  String get passwordTooShort => 'At least 6 characters';

  @override
  String get saved => 'Saved';

  @override
  String errorWithMessage(String message) {
    return 'Error: $message';
  }

  @override
  String get noUsers => 'No users yet';

  @override
  String clientsCount(int count, int green) {
    return '$count clients · $green visited recently';
  }

  @override
  String get allSalespeople => 'All sales executives';

  @override
  String get unassigned => 'Unassigned';

  @override
  String get search => 'Search';

  @override
  String get noClients => 'No clients';

  @override
  String get importClients => 'Import clients';

  @override
  String get importPickFile => 'Choose Odoo export (.xlsx or .csv)';

  @override
  String get importReading => 'Reading file…';

  @override
  String importResolving(int done, int total) {
    return 'Reading locations $done/$total';
  }

  @override
  String get importNew => 'New clients';

  @override
  String get importUpdated => 'Updated clients';

  @override
  String get importUnchanged => 'Unchanged';

  @override
  String get importNoLocation => 'New clients without location';

  @override
  String get importUnresolved =>
      'New clients – location link unreadable (saved without location)';

  @override
  String get importDuplicates => 'Same VAT number, merged';

  @override
  String get importUnknownSalespeople =>
      'Odoo salespeople not linked to a user';

  @override
  String get importConfirm => 'Import';

  @override
  String importDone(int added, int updated) {
    return 'Import complete: $added added, $updated updated';
  }

  @override
  String get importResolverUnavailable =>
      'Short location links could not be read (server function not available). Those clients are saved without a location.';

  @override
  String get latitude => 'Latitude';

  @override
  String get longitude => 'Longitude';

  @override
  String get address => 'Address';

  @override
  String get city => 'City';

  @override
  String get mobile => 'Mobile';

  @override
  String get salesExecutive => 'Sales executive';

  @override
  String get openInMaps => 'Open in Google Maps';

  @override
  String get editClient => 'Edit client';

  @override
  String get lastVisit => 'Last visit';

  @override
  String get never => 'Never';

  @override
  String get tags => 'Tags';

  @override
  String get vat => 'VAT number';

  @override
  String get odooSalesperson => 'Odoo salesperson';

  @override
  String get odooSalespersonName => 'Odoo salesperson name';

  @override
  String get odooSalespersonHelp =>
      'Exactly as in the Odoo export, e.g. Sami Mansour @ Sales';

  @override
  String get details => 'Details';

  @override
  String get invalidNumber => 'Invalid number';

  @override
  String get mergedContacts => 'Merged contacts';

  @override
  String get noLocation => 'No location';

  @override
  String get statusAll => 'All';

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get showAllClients => 'Show all clients';

  @override
  String get addVisit => 'Add visit';

  @override
  String get saveVisit => 'Save visit';

  @override
  String get visitNotes => 'What was done at the visit';

  @override
  String get visitNotesHint => 'Products discussed, orders, follow-ups…';

  @override
  String get visitNotesRequired => 'Write what was done at the visit';

  @override
  String get visitSaved => 'Visit saved';

  @override
  String get visitAlreadyTodayTitle => 'Already visited today';

  @override
  String visitAlreadyToday(String time) {
    return 'You already saved a visit to this client today at $time. Only one visit per client per day: open it to add photos or comments.';
  }

  @override
  String get openVisit => 'Open visit';

  @override
  String get gettingLocation => 'Getting your location…';

  @override
  String get locationUnavailable =>
      'Location unavailable. Turn on GPS and try again.';

  @override
  String get locationPermissionDenied =>
      'Location permission denied. Allow it in the phone settings.';

  @override
  String locationAccuracy(int meters) {
    return 'GPS accuracy ±$meters m';
  }

  @override
  String distanceFromClient(String distance) {
    return '$distance from the client';
  }

  @override
  String farFromClientWarning(String distance) {
    return 'You are $distance from this client. The visit will be flagged as far from the client. Save anyway?';
  }

  @override
  String get mockedLocationWarning =>
      'Fake GPS detected. This visit will be flagged.';

  @override
  String get setClientLocationHere =>
      'Set the client\'s location to my current position';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get saveAnyway => 'Save anyway';

  @override
  String get myLocation => 'My location';

  @override
  String get visitHistory => 'Visits';

  @override
  String get noVisits => 'No visits yet';

  @override
  String farFlag(String distance) {
    return 'Far from client ($distance)';
  }

  @override
  String get fakeGpsFlag => 'Fake GPS';

  @override
  String get emailInUse =>
      'This email already has an account. Enter the password used the first time, or delete the account in Firebase Console → Authentication and try again.';

  @override
  String get delete => 'Delete';

  @override
  String deleteUserTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get deleteUserBody =>
      'They will lose access to the app immediately. Their clients become unassigned, and their past visits are kept. To reuse the same email later, also delete the account in Firebase Console → Authentication.';

  @override
  String get userDeleted => 'User deleted';

  @override
  String savedWithClients(int count) {
    return 'Saved · $count clients from Odoo assigned';
  }

  @override
  String get pickOnMap => 'Pick on map';

  @override
  String get pickOnMapHint =>
      'Move the map so the pin is on the client\'s location';

  @override
  String get useThisLocation => 'Use this location';

  @override
  String get useMyLocation => 'Use my location';

  @override
  String get importLocationsOnly =>
      'Import locations only (client name + location)';

  @override
  String get chooseFile => 'Choose file';

  @override
  String get locationSheetColumns =>
      'The sheet needs a header row with:\n• Client name (\"Name\" or \"Complete Name\") or \"Tax ID\"\n• A location: a Google Maps link (\"Location\" or \"Google Pin\"), \"24.71, 46.67\" text, or \"Latitude\" + \"Longitude\" columns';

  @override
  String get shortLinksUnavailable =>
      'Short Google Maps links can\'t be read until the server function is deployed. Use full links or coordinates for now.';

  @override
  String get locationsToSet => 'Clients getting a location';

  @override
  String get locationsToReplace => 'Clients whose location will change';

  @override
  String get clientNotFound => 'No matching client';

  @override
  String get sameNameSeveralClients =>
      'Name matches several clients (add Tax ID)';

  @override
  String get locationUnreadable => 'Location couldn\'t be read';

  @override
  String get replaceExistingLocations =>
      'Also replace locations that are already set';

  @override
  String updateLocationsButton(int count) {
    return 'Update $count locations';
  }

  @override
  String locationsUpdated(int count) {
    return '$count locations updated';
  }

  @override
  String get everyone => 'Everyone';

  @override
  String withKam(String name) {
    return 'With KAM $name';
  }

  @override
  String kamWasThere(String name) {
    return '$name (KAM) was at this visit';
  }

  @override
  String markedHoursLater(int hours) {
    return 'Marked $hours h after the visit';
  }

  @override
  String get iWasThere => 'I was at this visit';

  @override
  String get remove => 'Remove';

  @override
  String visitedBy(String name) {
    return 'Visited by $name';
  }

  @override
  String get openClient => 'Open';

  @override
  String get comments => 'Comments';

  @override
  String get noComments => 'No comments yet';

  @override
  String get writeComment => 'Write a comment…';

  @override
  String get send => 'Send';

  @override
  String get pasteMapsLink => 'Paste Google Maps link';

  @override
  String get pasteMapsLinkHint => 'https://maps.app.goo.gl/… or 24.63, 46.80';

  @override
  String get linkUnreadable =>
      'Couldn\'t read a location from this link. Open it in Google Maps, tap Share → Copy link, and paste that.';

  @override
  String get justNow => 'just now';

  @override
  String minutesAgo(int m) {
    return '$m min ago';
  }

  @override
  String hoursAgo(int h) {
    return '$h h ago';
  }

  @override
  String liveUpdated(String ago) {
    return 'Live · updated $ago';
  }

  @override
  String get liveGpsOff => 'Online, but GPS is turned off';

  @override
  String liveNoFix(String ago) {
    return 'Online, no new location since $ago';
  }

  @override
  String liveOffline(String ago) {
    return 'Offline · last seen $ago';
  }

  @override
  String get liveNotAlways =>
      'Location is not set to \"Allow all the time\" on this phone';

  @override
  String get noTrackedStaff => 'No sales staff to show';

  @override
  String get noLocationYet => 'No location received yet';

  @override
  String get showEveryone => 'Show everyone';

  @override
  String get callPhone => 'Call';

  @override
  String get sharingOn => 'Location sharing is on';

  @override
  String get sharingIncomplete => 'Location sharing is on, but needs attention';

  @override
  String get sharingOff => 'Location sharing is off';

  @override
  String get issueGpsOff => 'GPS is turned off';

  @override
  String get issueLocationDenied => 'Location permission is not allowed';

  @override
  String get issueNotAlways => 'Set location to \"Allow all the time\"';

  @override
  String get issueNotifications =>
      'Allow notifications (keeps sharing running)';

  @override
  String get issueBattery => 'Turn off battery optimization for this app';

  @override
  String get fix => 'Fix';

  @override
  String get xiaomiHint =>
      'On Xiaomi, Huawei or Oppo phones also open App settings → turn on Autostart and set Battery saver to \"No restrictions\".';

  @override
  String get appSettings => 'App settings';

  @override
  String get home => 'Home';

  @override
  String get more => 'More';

  @override
  String get myPlan => 'My plan';

  @override
  String planOf(String name) {
    return '$name\'s plan';
  }

  @override
  String get addToTodaysPlan => 'Add to today\'s plan';

  @override
  String get onTodaysPlan => 'On today\'s plan';

  @override
  String get moveToSalesperson => 'Move to another salesperson';

  @override
  String get clientType => 'Type';

  @override
  String get clientTypeCompany => 'Company';

  @override
  String get clientTypeIndividual => 'Individual';

  @override
  String get companyId => 'Company ID (CR)';

  @override
  String get notSet => 'Not set';

  @override
  String get importFillOnly => 'Only fill missing fields';

  @override
  String get importFillOnlyHint =>
      'Contact person, Company / Individual and Company ID of existing clients, only where empty. Nothing else changes and no clients are added.';

  @override
  String get filters => 'Filters';

  @override
  String get clearFilters => 'Clear all';

  @override
  String get clientTags => 'Client tags';

  @override
  String get tagFilterAny => 'Shows clients with any of the selected tags.';

  @override
  String tagClientsTitle(int count) {
    return 'Tags for $count clients';
  }

  @override
  String get tagClientsHelp =>
      'Tap a tag once to add it, twice to remove it. Other tags stay as they are.';

  @override
  String get tagWillAdd => 'Will be added';

  @override
  String get tagWillRemove => 'Will be removed';

  @override
  String tagsUpdatedCount(int count) {
    return 'Tags updated for $count clients';
  }

  @override
  String get addTag => 'Add tag';

  @override
  String get editTag => 'Edit tag';

  @override
  String get tagNameEn => 'Name (English)';

  @override
  String get tagNameAr => 'Name (Arabic)';

  @override
  String get tagDuplicate => 'A tag with this name already exists';

  @override
  String deleteTagTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String deleteTagBody(int count) {
    return 'It is removed from $count clients. This cannot be undone.';
  }

  @override
  String get clientTagsHelp =>
      'Tags describe the client\'s business (factory, showroom, …). Use them to filter the client list and map. Tag clients on their edit screen, or select several in the client list.';

  @override
  String clientsCountShort(int count) {
    return '$count clients';
  }

  @override
  String get addToPlan => 'Add to plan';

  @override
  String get today => 'Today';

  @override
  String get nothingPlanned => 'Nothing planned for this day';

  @override
  String planSummary(int done, int total, int pending) {
    return '$done of $total done · $pending waiting for approval';
  }

  @override
  String get waitingApproval => 'Waiting for approval';

  @override
  String get rejected => 'Rejected';

  @override
  String get done => 'Done';

  @override
  String get toDo => 'To do';

  @override
  String get approve => 'Approve';

  @override
  String get reject => 'Reject';

  @override
  String get chooseClient => 'Choose a client';

  @override
  String get clientVisit => 'Client visit';

  @override
  String get task => 'Task';

  @override
  String get noteOptional => 'Note (optional)';

  @override
  String get taskDescription => 'What needs to be done';

  @override
  String get needsApprovalHint =>
      'Your KAM will approve this before it counts in your plan.';

  @override
  String get todaysPlan => 'Today\'s plan';

  @override
  String get openPlan => 'Open plan';

  @override
  String monthProgress(String month) {
    return 'Progress · $month';
  }

  @override
  String visitsOfTarget(int count, int target) {
    return '$count of $target visits';
  }

  @override
  String visitsThisMonth(int count) {
    return '$count visits this month';
  }

  @override
  String get planTasksDone => 'Planned tasks done';

  @override
  String get missedTasks => 'Missed tasks';

  @override
  String get rideAlongs => 'Visits with KAM';

  @override
  String get flaggedVisits => 'Flagged visits';

  @override
  String get coverage => 'Clients covered';

  @override
  String waitingForYourApproval(int count) {
    return 'Waiting for your approval ($count)';
  }

  @override
  String get myTeam => 'My team';

  @override
  String teamLine(int done, int total, String visits) {
    return 'Today $done/$total done · Month visits $visits';
  }

  @override
  String get noKamHint =>
      'You have no KAM assigned yet, so your sales manager approves your plan.';

  @override
  String get monthlyVisitTarget => 'Monthly visit target';

  @override
  String get monthlyVisitTargetHelp => 'Leave empty for no target';

  @override
  String get paceOnTrack => 'On track';

  @override
  String get paceSlightlyBehind => 'Slightly behind';

  @override
  String get paceBehind => 'Behind';

  @override
  String get completedVisits => 'Completed visits';

  @override
  String get target => 'Target';

  @override
  String get targetPace => 'Target pace';

  @override
  String barTooltip(String name, int done, int target, int expected) {
    return '$name: $done visits · target $target · expected by today $expected';
  }

  @override
  String get thisMonth => 'This month';

  @override
  String get lastMonth => 'Last month';

  @override
  String get customRange => 'Custom dates';

  @override
  String get noTargetSet => 'No target set';

  @override
  String coverageDetail(int green, int total) {
    return '$green of $total clients visited recently';
  }

  @override
  String get planCompletion => 'Plan completion';

  @override
  String tasksDetail(int done, int total) {
    return '$done of $total planned tasks';
  }

  @override
  String get flaggedDetail => 'Far from client or fake GPS';

  @override
  String get visitsVsTarget => 'Visits vs target';

  @override
  String get progressVsTarget => 'Progress vs target pace';

  @override
  String get statusRecent => 'Visited recently';

  @override
  String get statusDueSoon => 'Due soon';

  @override
  String get statusOverdue => 'Overdue';

  @override
  String get plannedToday => 'Planned today';

  @override
  String get category => 'Category';

  @override
  String categoryName(String c) {
    return 'Category $c';
  }

  @override
  String categoryRule(String c, int green, int yellow) {
    return '$c · green up to $green days, yellow up to $yellow days';
  }

  @override
  String get visitStatus => 'Visit status';

  @override
  String get visitFrequency => 'Visit frequency';

  @override
  String get visitFrequencyHelp =>
      'Days since the last visit before a client turns yellow, then red. Clients never visited are red.';

  @override
  String get greenUpTo => 'Green up to (days)';

  @override
  String get yellowUpTo => 'Yellow up to (days)';

  @override
  String get yellowAfterGreen => 'Must be more than green';

  @override
  String get redAfter => 'Red after that';

  @override
  String get importDefaultCategory =>
      'Category for new clients (when the sheet has no Category column)';

  @override
  String get notifications => 'Notifications';

  @override
  String get noNotifications => 'No notifications';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String notifPlanSubmitted(String name, int count, String day) {
    return '$name added $count items to their plan for $day – waiting for your approval';
  }

  @override
  String notifPlanApproved(String name, String day) {
    return '$name approved your plan for $day';
  }

  @override
  String notifPlanRejected(String name, String day) {
    return '$name rejected an item in your plan for $day';
  }

  @override
  String notifPlanChanged(String name, String day) {
    return '$name changed your plan for $day';
  }

  @override
  String planUpdated(int count) {
    return '$count added to the plan';
  }

  @override
  String planSentForApproval(int count) {
    return '$count added and sent for approval';
  }

  @override
  String saveCount(int count) {
    return 'Save ($count)';
  }

  @override
  String get showOnMap => 'Show on map';

  @override
  String get share => 'Share';

  @override
  String shareTitle(String name, String day) {
    return '$name – plan for $day';
  }

  @override
  String get tasks => 'Tasks';

  @override
  String get route => 'Route';

  @override
  String approveAll(int count) {
    return 'Approve all ($count)';
  }

  @override
  String get removeFromPlan => 'Remove from plan';

  @override
  String planClientsWithoutLocation(int count) {
    return '$count planned clients have no location and are not on the map';
  }

  @override
  String get clear => 'Clear';

  @override
  String get clearPlanTitle => 'Clear plan?';

  @override
  String clearPlanUnapproved(int count) {
    return 'Remove the $count items that are not approved yet?';
  }

  @override
  String clearPlanAll(int count) {
    return 'Remove all $count items from this day\'s plan? The sales executive will be notified.';
  }

  @override
  String get addClient => 'Add client';

  @override
  String get clientName => 'Client name';

  @override
  String get clientAdded => 'Client added';

  @override
  String get possibleDuplicate => 'Client may already exist';

  @override
  String possibleDuplicateBody(String name) {
    return '\"$name\" is already in the app with the same name or VAT number. Add a new client anyway?';
  }

  @override
  String get addAnyway => 'Add anyway';

  @override
  String get contact => 'Contact';

  @override
  String get contactPerson => 'Contact person';

  @override
  String get locationSection => 'Location';

  @override
  String get salesSection => 'Sales';

  @override
  String get notes => 'Notes';

  @override
  String get directions => 'Directions';

  @override
  String get addedInApp => 'Added in app';

  @override
  String get noContactDetails => 'No contact details yet';

  @override
  String get coordinates => 'Coordinates';

  @override
  String daysAgo(int days) {
    return '$days days ago';
  }

  @override
  String get importLinkedContacts => 'Contact people linked to a company';

  @override
  String get accountSection => 'Account';

  @override
  String get receivable => 'Receivable (owed to us)';

  @override
  String get payable => 'Payable (we owe)';

  @override
  String get street => 'Street';

  @override
  String get region => 'Region';

  @override
  String get country => 'Country';

  @override
  String get teamPlansToday => 'Team plans today';

  @override
  String get attachments => 'Photos & files';

  @override
  String get noAttachments => 'No photos or files yet';

  @override
  String get addAttachment => 'Add photo or file';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get chooseFromGallery => 'Choose from gallery';

  @override
  String get uploading => 'Uploading…';

  @override
  String deleteAttachmentConfirm(String name) {
    return 'Delete $name?';
  }

  @override
  String fileTooLarge(String name) {
    return '$name is larger than 20 MB';
  }

  @override
  String visitPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos or files',
      one: '1 photo or file',
      zero: 'No photos',
    );
    return '$_temp0';
  }

  @override
  String addUnmatchedClients(int count) {
    return 'Add $count unmatched rows as new clients';
  }

  @override
  String newClientsAssignedTo(String name, int noLocation) {
    return 'Assigned to $name · $noLocation without location';
  }

  @override
  String importApplyButton(int added, int updated) {
    return 'Add $added clients · update $updated locations';
  }

  @override
  String importApplyDone(int added, int updated) {
    return '$added clients added · $updated locations updated';
  }

  @override
  String get newVisit => 'New visit';

  @override
  String get searchVisits => 'Search client or notes';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get thisWeek => 'This week';

  @override
  String get allTime => 'All';

  @override
  String get visitsTotal => 'Visits';

  @override
  String get withKamCount => 'With KAM';

  @override
  String get noVisitsHint => 'Tap \"New visit\" to check in at a client';

  @override
  String get noMatchingVisits => 'No visits match these filters';

  @override
  String get planProgress => 'Plan progress';

  @override
  String get missed => 'Missed';

  @override
  String get noPlanItems => 'No plan items in this period';

  @override
  String get clientVisitsCard => 'Client visits';

  @override
  String get visitedLabel => 'Visited';

  @override
  String get notVisitedYet => 'Not visited yet';

  @override
  String get noAssignedClients => 'No clients assigned';

  @override
  String ofTotal(int total) {
    return 'of $total';
  }

  @override
  String visitedOfClients(int visited, int total, int pending) {
    return '$visited of $total clients visited · $pending still pending';
  }

  @override
  String get reports => 'Reports';

  @override
  String get tripDetails => 'Trip details';

  @override
  String get routeHistory => 'Route history';

  @override
  String get teamPerformance => 'Team performance';

  @override
  String get person => 'Person';

  @override
  String get clientsVisitedColumn => 'Clients visited';

  @override
  String get ownClientsVisited => 'Own clients visited';

  @override
  String get onSchedule => 'On schedule';

  @override
  String unvisitedInPeriod(int count) {
    return 'Not visited in this period ($count)';
  }

  @override
  String get allClientsVisited => 'Every client was visited in this period';

  @override
  String showAllCount(int count) {
    return 'Show all ($count)';
  }

  @override
  String get importHistory => 'Imports';

  @override
  String get noImports => 'No imports yet';

  @override
  String importBatchLine(int added, int updated, int unchanged) {
    return '$added new · $updated updated · $unchanged unchanged';
  }

  @override
  String importedByName(String name) {
    return 'by $name';
  }

  @override
  String get distance => 'Distance';

  @override
  String get firstLocation => 'First location';

  @override
  String get lastLocation => 'Last location';

  @override
  String locationPointsCount(int count) {
    return '$count points';
  }

  @override
  String fakeGpsPoints(int count) {
    return '$count fake GPS points';
  }

  @override
  String get noRouteData => 'No locations recorded for this day';

  @override
  String get choosePerson => 'Choose a person';

  @override
  String get previousDay => 'Previous day';

  @override
  String get nextDay => 'Next day';

  @override
  String trackingGaps(int count) {
    return '$count gaps in tracking';
  }

  @override
  String get hiddenClients => 'Hidden clients';

  @override
  String get hideClient => 'Hide client';

  @override
  String get unhideClient => 'Show again';

  @override
  String get hideClientTitle => 'Hide this client?';

  @override
  String get hideClientBody =>
      'They will be left out of client lists, the map, plans, visits and all statistics, for everyone. Their visits and data are kept. To show them again, use the \"Hidden\" filter in Clients.';

  @override
  String get clientHiddenBanner => 'Hidden: left out of lists and statistics';

  @override
  String get clientHidden => 'Client hidden';

  @override
  String get clientUnhidden => 'Client shown again';

  @override
  String get selectClients => 'Select clients';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get selectAll => 'Select all';

  @override
  String hideClientsTitle(int count) {
    return 'Hide $count clients?';
  }

  @override
  String clientsHiddenCount(int count) {
    return '$count clients hidden';
  }

  @override
  String clientsUnhiddenCount(int count) {
    return '$count clients shown again';
  }

  @override
  String get liveOffDuty =>
      'Off duty · outside work hours, location not shared';

  @override
  String get workHours => 'Work hours';

  @override
  String get workHoursHelp =>
      'Field staff locations are shared only on these days and hours (Saudi time). Outside them nothing is sent and people show as off duty.';

  @override
  String get workDays => 'Work days';

  @override
  String get startTime => 'Start';

  @override
  String get endTime => 'End';

  @override
  String get endAfterStart => 'End time must be after start time';

  @override
  String get transferClients => 'Transfer';

  @override
  String transferClientsTitle(int count) {
    return 'Transfer $count clients to';
  }

  @override
  String get transferClientTitle => 'Transfer client to';

  @override
  String get transferPlanNote =>
      'Open plan items for these clients from today on are removed from the current salesperson\'s plan. Past plans and visits are kept.';

  @override
  String transferSkipped(int count) {
    return '$count selected clients are not in your team and will be skipped.';
  }

  @override
  String get transferNoneAllowed =>
      'None of the selected clients belong to your team.';

  @override
  String get noTransferTargets => 'No sales executives to transfer to';

  @override
  String clientsTransferredCount(int count, String name) {
    return '$count clients moved to $name';
  }

  @override
  String get transferHistory => 'Transfer history';

  @override
  String transferBy(String name, String when) {
    return 'by $name · $when';
  }

  @override
  String notifClientsTransferredIn(String name, int count) {
    return '$name moved $count clients to you';
  }

  @override
  String notifClientsTransferredOut(String name, int count, String other) {
    return '$name moved $count of your clients to $other';
  }

  @override
  String get teamPlans => 'Team plans';

  @override
  String get noTeamMembers => 'No team members yet';

  @override
  String get viewAll => 'View all';

  @override
  String notifGpsOff(String name) {
    return '$name turned off location (GPS)';
  }

  @override
  String notifLocationDenied(String name) {
    return '$name removed the app\'s location permission';
  }

  @override
  String notifLocationNotAlways(String name) {
    return '$name allowed location only while using the app – tracking stops in the background';
  }

  @override
  String get visitDetails => 'Visit details';

  @override
  String get otherPhoneTitle => 'Your location is shared from another phone';

  @override
  String get otherPhoneBody =>
      'Another phone signed in to your account shares your location, so this phone sends nothing. If this is the phone you work with, tap \"Use this phone\".';

  @override
  String get useThisPhone => 'Use this phone';

  @override
  String otherTrackIgnored(int count) {
    return '$count points from another phone ignored';
  }

  @override
  String reportNewClients(int count) {
    return 'New clients ($count)';
  }

  @override
  String get reportNoNewClients => 'No clients were added in this period.';

  @override
  String get reportAddedInApp => 'Added in the app';

  @override
  String get reportImported => 'Imported';

  @override
  String reportAddedBy(String name) {
    return 'added by $name';
  }

  @override
  String get reportRouting => 'Routing performance & efficiency';

  @override
  String get reportNoRoutingDays =>
      'No day with two or more visits in this period.';

  @override
  String get reportAvgEfficiency => 'Average efficiency';

  @override
  String get reportDaysCounted => 'Days';

  @override
  String get reportVisitsPerDay => 'Visits / day';

  @override
  String get reportShortestOrderDays => 'Shortest order';

  @override
  String get reportExtraDistance => 'Extra distance';

  @override
  String get reportNeededTook => 'Needed / took';

  @override
  String get reportLowestDays => 'Lowest days';

  @override
  String get reportRoutingHelp =>
      'Counts days with two or more visits. Efficiency = time needed (shortest route through the same clients + 30 min per visit) ÷ time from the first to the last visit, at most 100%. Extra distance = straight-line km more than the shortest order between the visits.';

  @override
  String get reportCatalogs => 'Catalog distribution';

  @override
  String get reportNoCatalogs =>
      'No catalogs or stands were handed over in this period.';

  @override
  String get reportTotal => 'Total';

  @override
  String get reportClientsReached => 'Clients';

  @override
  String get reportCatalogsDue => 'Clients due for a new one';

  @override
  String reportDueNever(String item, int due, int never) {
    return '$item: $due due · $never never given';
  }

  @override
  String get reportCatalogsHelp =>
      'From hand-overs at visits and recorded on client pages, counted for the person who gave them. Tap an item to see its due clients.';

  @override
  String get givenSwitchCatalog => 'Swatch catalog';

  @override
  String get givenBookletCatalog => 'Booklet catalog';

  @override
  String get givenDisplayStand => 'Display stand';

  @override
  String get givenA4Samples => 'A4 samples';

  @override
  String get itemsGiven => 'Catalogs & stands given';

  @override
  String get givenNever => 'Never given';

  @override
  String givenLast(int qty, String date) {
    return 'Last: $qty on $date';
  }

  @override
  String givenTotal(int count) {
    return '$count in all';
  }

  @override
  String givenDueOn(String date) {
    return 'new one due $date';
  }

  @override
  String get givenDue => 'Due';

  @override
  String get givenDueSoon => 'Due soon';

  @override
  String get givenItemsSettings => 'Catalogs & stands';

  @override
  String get givenItemsHelp =>
      'After how many days a client should get a new one. Clients past this show \"Due\" on their page, at check-in and in the filter.';

  @override
  String get givenEveryDaysSuffix => 'days';

  @override
  String get givenDueFilter => 'New catalog / stand due';

  @override
  String get givenHistory => 'History';

  @override
  String get givenRecord => 'Record catalog / stand given';

  @override
  String get givenRecordedByHand => 'recorded';

  @override
  String get givenAtVisit => 'at a visit';

  @override
  String get givenOn => 'Given on';

  @override
  String get quantity => 'Quantity';

  @override
  String get notAssignedTitle => 'Not assigned to a sales executive';

  @override
  String notAssignedBody(int count, String names) {
    return '$count of the selected clients have no sales executive, so they can\'t go on a plan: $names. Move them to someone first.';
  }

  @override
  String get moveThemFirst => 'Move them';

  @override
  String planTheOthers(int count) {
    return 'Plan the other $count';
  }

  @override
  String planNotAllowed(int count) {
    return '$count clients belong to people outside your team and are left out.';
  }

  @override
  String planSelectedTitle(int count) {
    return 'Add $count clients to plans';
  }

  @override
  String get planSelectedHint =>
      'Each client goes on the plan of the salesperson it belongs to, approved; they are notified.';

  @override
  String plannedFromSelection(int count, int plans) {
    return 'Added $count clients to $plans plans';
  }

  @override
  String alreadyOnPlanCount(int count) {
    return '$count already on the plan';
  }

  @override
  String get dupSameCompanyId => 'Same CR number';

  @override
  String get duplicatesFoundBody =>
      'These clients look like the one you are adding:';

  @override
  String get duplicateOverrideHint =>
      'If you checked and it is a different client, you can add it.';

  @override
  String get duplicateAskManager =>
      'If it is a different client, ask a sales manager to add it.';

  @override
  String get notDuplicateAdd => 'Not a duplicate – add';

  @override
  String get useThisClient => 'Use this client';

  @override
  String addNewClientNamed(String name) {
    return 'Add \"$name\" as a new client';
  }

  @override
  String get selectClientsToMove => 'Select clients to plan or move';

  @override
  String get tapPinsToSelect => 'Tap pins to select clients';

  @override
  String get selectSeveralToMove => 'Select several clients to plan or move';

  @override
  String get showRouteMap => 'Show on route map';

  @override
  String get shortestOrderHint => 'Numbers follow the shortest route';

  @override
  String get efficiency => 'Efficiency';

  @override
  String efficiencyDetail(String needed, String took) {
    return 'Needed about $needed (shortest route + 30 min per visit), took $took from the first to the last visit';
  }

  @override
  String get efficiencyBestOrder => 'Visits made in the shortest order';

  @override
  String efficiencyOtherOrder(String shortest, String taken) {
    return 'Shortest order: $shortest between visits instead of $taken';
  }

  @override
  String notifNotificationsOff(String name) {
    return '$name turned off notifications for WPC CRM';
  }

  @override
  String get logNotificationsOff => 'Notifications turned off';

  @override
  String get logNotificationsOn => 'Notifications turned on';

  @override
  String notifBatteryOptimized(String name) {
    return '$name turned on battery optimization for WPC CRM – tracking may stop';
  }

  @override
  String get close => 'Close';

  @override
  String get showLocation => 'Show location';

  @override
  String get deleteVisitTitle => 'Delete visit';

  @override
  String get deleteVisitBody =>
      'The visit, its comments, photos and files are deleted for everyone. Plan items it completed become open again. This can\'t be undone.';

  @override
  String get visitDeleted => 'Visit deleted';

  @override
  String get colourBy => 'Colour by';

  @override
  String get salesperson => 'Salesperson';

  @override
  String notifPlanItemsAdded(String name, int count, String day) {
    return '$name added $count item(s) to your plan for $day';
  }

  @override
  String notifTrackingOffline(String name) {
    return '$name has been offline for over 30 minutes during work hours';
  }

  @override
  String get trackingLog => 'Tracking log';

  @override
  String get trackingLogEmpty => 'No changes recorded for this day';

  @override
  String get logOffline => 'Lost connection';

  @override
  String get logOnline => 'Back online';

  @override
  String get logGpsOff => 'GPS turned off';

  @override
  String get logGpsOn => 'GPS turned on';

  @override
  String get logOnDuty => 'Work hours started';

  @override
  String get logOffDuty => 'Work hours ended';

  @override
  String get logBatteryOn => 'Battery optimization turned on';

  @override
  String get logBatteryOff => 'Battery optimization turned off';

  @override
  String logPermission(String value) {
    return 'Location permission: $value';
  }

  @override
  String get permissionAlways => 'Allow all the time';

  @override
  String get permissionWhileInUse => 'Only while using the app';

  @override
  String get permissionDenied => 'Denied';

  @override
  String logLasted(String duration) {
    return 'for $duration';
  }

  @override
  String durationMinutes(int m) {
    return '$m min';
  }

  @override
  String durationHoursMinutes(int h, int m) {
    return '$h h $m min';
  }

  @override
  String get addTask => 'Add task';

  @override
  String get commentOptional => 'Comment (optional)';

  @override
  String get markDone => 'Mark done';

  @override
  String get markNotDone => 'Not done';

  @override
  String get visitTasksLabel => 'Tasks at the client';

  @override
  String checklistProgress(int done, int total) {
    return '$done/$total tasks';
  }

  @override
  String get possibleDuplicates => 'Possible duplicates';

  @override
  String get dupSameVat => 'Same Tax ID';

  @override
  String get dupSameName => 'Same name';

  @override
  String get dupSamePhone => 'Same phone';

  @override
  String get dupSimilarName => 'Similar name';

  @override
  String get dupNearby => 'Same place';

  @override
  String get noDuplicates => 'No possible duplicates';

  @override
  String get notDuplicates => 'Not duplicates';

  @override
  String get markedNotDuplicates => 'Marked as different clients';

  @override
  String get mergeClients => 'Merge';

  @override
  String get mergeClientsTitle => 'Merge clients';

  @override
  String get mergeHint =>
      'Choose the client to keep. The others are deleted: their visits, plan items, files, contacts and names move to the kept client, and its empty details are filled from them. The kept client\'s name, category and salesperson stay. This can\'t be undone.';

  @override
  String get mergeKeep => 'Keep this client';

  @override
  String mergeCount(int count) {
    return 'Merge $count';
  }

  @override
  String clientsMerged(int count) {
    return '$count clients merged into one';
  }

  @override
  String get profile => 'Profile';

  @override
  String get personalInfo => 'Personal info';

  @override
  String get emailChangeByAdmin =>
      'To change your email or role, ask a sales manager.';

  @override
  String get changePassword => 'Change password';

  @override
  String get currentPassword => 'Current password';

  @override
  String get newPassword => 'New password';

  @override
  String get confirmNewPassword => 'Confirm new password';

  @override
  String get passwordsDontMatch => 'Passwords don\'t match';

  @override
  String get wrongCurrentPassword => 'Current password is wrong';

  @override
  String get passwordChanged => 'Password changed';

  @override
  String get resetPasswordByEmail => 'Reset password by email';

  @override
  String get resetPasswordInfo =>
      'Forgot your current password? We\'ll email you a link to set a new one.';

  @override
  String get sendResetLink => 'Send link';

  @override
  String resetEmailSent(String email) {
    return 'Reset link sent to $email';
  }

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get resetEmailSentIfExists =>
      'If this email has an account, a reset link was sent to it.';

  @override
  String get tooManyAttempts => 'Too many attempts. Try again later.';

  @override
  String get updateRequiredTitle => 'Update required';

  @override
  String get updateRequiredBody =>
      'A new version of WPC CRM is available. Please update the app to continue.';

  @override
  String get updateNow => 'Update now';

  @override
  String get exportClients => 'Export to Excel';

  @override
  String get exportClientsTitle => 'Export clients to Excel';

  @override
  String exportClientsBody(int count) {
    return '$count clients (the current list with its search and filters). Choose the columns:';
  }

  @override
  String exportColumnsCount(int selected, int total) {
    return '$selected of $total columns';
  }

  @override
  String get exportSelectNone => 'Clear';

  @override
  String get exportButton => 'Export';

  @override
  String get exportLegalName => 'Legal name';

  @override
  String get exportVisitStatus => 'Visit status';

  @override
  String get exportDaysSinceVisit => 'Days since last visit';

  @override
  String get exportOtherContacts => 'Other contacts';

  @override
  String get exportMapsLink => 'Google Maps link';

  @override
  String get exportGooglePin => 'Odoo Google Pin';

  @override
  String get exportOdooTags => 'Odoo tags';

  @override
  String get exportCurrency => 'Currency';

  @override
  String get exportSource => 'Source';

  @override
  String get exportSourceImport => 'Odoo import';

  @override
  String get exportHidden => 'Hidden';

  @override
  String get exportAddedOn => 'Added on';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get call => 'Call';

  @override
  String get calls => 'Calls';

  @override
  String get logCall => 'Log call';

  @override
  String get saveCall => 'Save call';

  @override
  String get callSaved => 'Call saved';

  @override
  String get callNotes => 'What was discussed on the call';

  @override
  String get callNotesHint => 'Orders, follow-ups, next visit…';

  @override
  String get callNotesRequired => 'Write what was discussed on the call';

  @override
  String get callFromApp => 'Called from the app';

  @override
  String get callLoggedByHand => 'Logged by hand';

  @override
  String callDuration(String duration) {
    return 'About $duration away from the app';
  }

  @override
  String get notThisCall => 'Not this call';

  @override
  String logThisCall(String duration) {
    return 'Back from a call ($duration). Log it?';
  }

  @override
  String calledBy(String name) {
    return 'Call by $name';
  }

  @override
  String get visitsAndCalls => 'Visits and calls';

  @override
  String get visitsPlusCalls => 'Visits + calls';

  @override
  String visitsAndCallsDetail(int visits, int calls) {
    return '$visits visits + $calls calls';
  }

  @override
  String barTooltipCalls(
    String name,
    int done,
    int calls,
    int target,
    int expected,
  ) {
    return '$name: $done visits + $calls calls · target $target · expected by today $expected';
  }

  @override
  String get roleHr => 'HR';

  @override
  String get roleAccounting => 'Accounting';

  @override
  String get roleProcurement => 'Procurement';

  @override
  String get roleUnknown => 'Unknown role';

  @override
  String get updateAppForRole =>
      'Your account uses a role this version of the app doesn\'t know yet. Please update the app (Google Play / TestFlight) or reload the web page.';

  @override
  String get backOfficeHomeBody =>
      'Your attendance and leave requests will appear here.';

  @override
  String get hrArea => 'HR';

  @override
  String get myLeave => 'My leave';

  @override
  String get myLeaveHint => 'Balances and requests';

  @override
  String get myRequests => 'My requests';

  @override
  String get newLeaveRequest => 'New request';

  @override
  String get noLeaveRequests => 'No requests';

  @override
  String get leaveRequests => 'Requests';

  @override
  String get leaveBalances => 'Balances';

  @override
  String get leaveTypesAndHolidays => 'Leave types & holidays';

  @override
  String leaveBalanceYear(int year) {
    return 'Leave balance $year';
  }

  @override
  String leavePendingDays(String days) {
    return '$days days waiting for approval';
  }

  @override
  String leaveRemainingOf(String left, String total) {
    return '$left of $total left';
  }

  @override
  String leaveDaysCount(String days) {
    return '$days days';
  }

  @override
  String leaveLeftAfter(String days) {
    return '$days left after this';
  }

  @override
  String get leaveOverBalance =>
      'This is more than the days left. HR decides whether it is allowed.';

  @override
  String waitingFor(String who) {
    return 'Waiting for $who';
  }

  @override
  String get waitingForMe => 'Waiting for me';

  @override
  String get pendingStatus => 'Pending';

  @override
  String get leaveApprovedStatus => 'Approved';

  @override
  String get leaveCancelledStatus => 'Cancelled';

  @override
  String leaveWaitingForYou(int count) {
    return 'Requests waiting for your approval ($count)';
  }

  @override
  String get requestType => 'Type';

  @override
  String get pickLeaveDates => 'Choose the dates';

  @override
  String get halfDay => 'Half day';

  @override
  String get countsCalendarDays => 'Counts every calendar day';

  @override
  String get countsWorkDays => 'Counts work days only';

  @override
  String get leaveReasonOptional => 'Reason (optional)';

  @override
  String get leaveRequestDetails => 'What do you need?';

  @override
  String get leaveReasonRequired => 'Write what you need';

  @override
  String leaveDocumentRequired(String document) {
    return 'Required: $document';
  }

  @override
  String get approvalOrder => 'Approval order';

  @override
  String get noApproverYet =>
      'Nobody can approve this request yet. Ask the GM to add an HR user.';

  @override
  String get leaveAcrossYears =>
      'A request can\'t cross the new year. Send one request per year.';

  @override
  String get leaveNoWorkDays => 'These dates have no work days.';

  @override
  String get sendRequest => 'Send request';

  @override
  String get leaveRequestSent => 'Request sent';

  @override
  String get approveRequest => 'Approve request';

  @override
  String get rejectRequest => 'Reject request';

  @override
  String get rejectReason => 'Reason';

  @override
  String get cancelRequest => 'Cancel request';

  @override
  String get leaveAlreadyDecided => 'Someone already decided this step.';

  @override
  String get leaveTypesHint =>
      'Starting values follow Saudi labour law – HR should check them. Tap a type to edit it.';

  @override
  String get noYearlyLimit => 'No yearly limit';

  @override
  String daysPerYear(int days) {
    return '$days days a year';
  }

  @override
  String get unpaid => 'Unpaid';

  @override
  String get otherRequest => 'Request (no days)';

  @override
  String needsDocumentNamed(String document) {
    return 'Needs: $document';
  }

  @override
  String get addLeaveType => 'Add type';

  @override
  String get editLeaveType => 'Edit type';

  @override
  String get nameEnglish => 'Name (English)';

  @override
  String get nameArabic => 'Name (Arabic)';

  @override
  String get isLeaveType => 'Leave (has dates)';

  @override
  String get isLeaveTypeHint => 'Off for requests like a salary certificate';

  @override
  String get daysPerYearLabel => 'Days per year';

  @override
  String get daysPerYearHelper => 'Empty = no limit';

  @override
  String get paidLeave => 'Paid';

  @override
  String get needsDocument => 'Needs a document';

  @override
  String get documentNameEnglish => 'Document (English)';

  @override
  String get documentNameArabic => 'Document (Arabic)';

  @override
  String get publicHolidays => 'Public holidays';

  @override
  String get publicHolidaysHint => 'These days don\'t count as leave days.';

  @override
  String get addHoliday => 'Add holiday';

  @override
  String get tapTypeToEdit =>
      'Tap a type to set this person\'s days or add an adjustment.';

  @override
  String get daysThisYear => 'Days this year for this person';

  @override
  String daysThisYearHelper(int days) {
    return 'Empty = the type\'s $days days';
  }

  @override
  String get adjustDays => 'Add or remove days';

  @override
  String get adjustDaysHelper => 'e.g. 5 carried over, or -2';

  @override
  String get adjustNote => 'Note';

  @override
  String get adjustments => 'Adjustments';

  @override
  String notifLeaveRequested(String owner) {
    return 'Request from $owner – waiting for your approval';
  }

  @override
  String notifLeaveApproved(String name) {
    return '$name approved your request';
  }

  @override
  String notifLeaveRejected(String name) {
    return '$name rejected your request';
  }

  @override
  String get addLocation => 'Add location';

  @override
  String get editLocation => 'Edit location';

  @override
  String get locationType => 'Label';

  @override
  String get noLocationType => 'No label';

  @override
  String get mainLocationType => 'Main location label';

  @override
  String get moreLocationsOnClientPage =>
      'Add more locations (factory, showroom, …) on the client page';

  @override
  String get mainLocation => 'Main';

  @override
  String get makeMainLocation => 'Make main location';

  @override
  String locationNumber(int n) {
    return 'Location $n';
  }

  @override
  String deleteLocationTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get visitLocation => 'Visit location';

  @override
  String get nearestLocation => 'nearest';

  @override
  String get locationTypes => 'Location types';

  @override
  String get locationTypesHelp =>
      'Labels for a client\'s locations, e.g. Office, Factory, Showroom. Deleting one leaves those locations unlabelled.';

  @override
  String get otherLocations => 'Other locations';

  @override
  String get saveClientFirstForLocations =>
      'Save the client first, then add more locations here.';

  @override
  String get setMainLocationFirst =>
      'Set and save the main location first, then add more locations.';

  @override
  String visitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count visits',
      one: '1 visit',
    );
    return '$_temp0';
  }

  @override
  String callsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count calls',
      one: '1 call',
    );
    return '$_temp0';
  }

  @override
  String get deleteClient => 'Delete client';

  @override
  String deleteClientTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get deleteClientBody =>
      'The client, its plan items and its photos / files will be deleted. This can\'t be undone.';

  @override
  String deleteClientWithVisits(int count) {
    return 'This client has $count visits. The visits stay in the visits list and reports; the client, its plan items and its photos / files are deleted. This can\'t be undone.\n\nEnter your password to confirm.';
  }

  @override
  String get yourPassword => 'Your password';

  @override
  String get wrongPassword => 'Wrong password';

  @override
  String clientDeleted(String name) {
    return '$name deleted';
  }

  @override
  String get documents => 'Documents';

  @override
  String get docCr => 'Commercial Registration (CR)';

  @override
  String get docVat => 'VAT certificate';

  @override
  String get docNationalAddress => 'National Address';

  @override
  String get docsHelp =>
      'Upload the PDF from the portal (best) or a clear photo. The app reads the numbers and the address and offers to fill the fields.';

  @override
  String get docNotAdded => 'Not added';

  @override
  String docWillUpload(String name) {
    return '$name – uploaded when you save';
  }

  @override
  String get upload => 'Upload';

  @override
  String get replace => 'Replace';

  @override
  String get docUnreadable =>
      'The document was attached, but no text could be read from it. Fill the fields by hand.';

  @override
  String get docPhotoOnWeb =>
      'The document was attached. Photos are read only in the phone app; on the web upload the PDF to fill the fields.';

  @override
  String get docNothingFound =>
      'The document was attached, but no CR / VAT number or address was found in it.';

  @override
  String docFoundTitle(String document) {
    return 'Found in the $document';
  }

  @override
  String get docFoundHelp =>
      'Check the values before filling them in. Ticked fields replace what is in the form.';

  @override
  String docCurrentValue(String value) {
    return 'Now: $value';
  }

  @override
  String get docFill => 'Fill in';

  @override
  String get clientStatus => 'Client status';

  @override
  String get clientStatusActive => 'Active';

  @override
  String get clientStatusClosed => 'Closed';

  @override
  String get clientStatusNotWorking => 'Not working';

  @override
  String get changeClientStatus => 'Change client status';

  @override
  String get clientStatusReason => 'Reason (optional)';

  @override
  String get clientStatusNeedsApproval =>
      'Your KAM, the sales manager or the GM will approve the change.';

  @override
  String get sendForApproval => 'Send for approval';

  @override
  String get clientStatusChanged => 'Client status changed';

  @override
  String get clientStatusRequestSent => 'Sent for approval';

  @override
  String get clientStatusRequestCancelled => 'Request cancelled';

  @override
  String get clientStatusApproved => 'Approved';

  @override
  String get clientStatusRejected => 'Rejected';

  @override
  String clientStatusSince(String status, String date) {
    return '$status since $date';
  }

  @override
  String clientStatusWaiting(String status) {
    return 'Waiting for approval: $status';
  }

  @override
  String clientStatusAsked(String name, String status) {
    return '$name asked to mark this client as $status';
  }

  @override
  String clientStatusRejectedEntry(String status) {
    return '$status – rejected';
  }

  @override
  String clientStatusRequestedBy(String name) {
    return 'asked by $name';
  }

  @override
  String clientStatusDecidedBy(String name) {
    return 'by $name';
  }

  @override
  String get clientStatusHistory => 'Status history';

  @override
  String get clientStatusRequests => 'Status requests';

  @override
  String get clientStatusFilterHelp =>
      'Closed and not working clients show only when ticked here.';

  @override
  String notifClientStatusRequested(String name, String client, String status) {
    return '$name asked to mark $client as $status – waiting for your approval';
  }

  @override
  String notifClientStatusApproved(String name, String client, String status) {
    return '$name approved: $client is now $status';
  }

  @override
  String notifClientStatusRejected(String name, String client, String status) {
    return '$name rejected marking $client as $status';
  }

  @override
  String get transferredClients => 'Transferred clients';

  @override
  String get transfersHelp =>
      'Clients moved from one salesperson to another, and whether the new salesperson has visited or called them since.';

  @override
  String lastNDays(int n) {
    return 'Last $n days';
  }

  @override
  String get transfersNotVisitedOnly => 'Not visited yet';

  @override
  String transfersSummary(int total, int visited, int waiting) {
    return '$total moved · $visited visited · $waiting not yet';
  }

  @override
  String get transfersNone => 'No clients were moved in this period.';

  @override
  String transferMovedBy(String name, String date) {
    return 'Moved by $name · $date';
  }

  @override
  String transferVisitedAfter(String date, int days) {
    return 'Visited $date · $days days after the move';
  }

  @override
  String transferCalledAfter(String date, int days) {
    return 'Called $date · $days days after the move';
  }

  @override
  String transferNotVisited(int days) {
    return 'Not visited · $days days since the move';
  }

  @override
  String get transferMovedAgain => 'Moved again later';

  @override
  String get newSalesperson => 'New salesperson';

  @override
  String get motionDriving => 'Driving';

  @override
  String get motionWalking => 'Walking';

  @override
  String get motionStopped => 'Stopped';

  @override
  String motionIdleFor(String time) {
    return 'Idle for $time';
  }
}
