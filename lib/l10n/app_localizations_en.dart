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
  String get openClient => 'Open client';

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
}
