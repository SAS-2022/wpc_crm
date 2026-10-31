import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'WPC CRM'**
  String get appTitle;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password'**
  String get signInFailed;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @noAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'No access'**
  String get noAccessTitle;

  /// No description provided for @noAccessBody.
  ///
  /// In en, this message translates to:
  /// **'Your account is not set up or has been deactivated. Contact your sales manager.'**
  String get noAccessBody;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}'**
  String welcome(String name);

  /// No description provided for @roleSalesExec.
  ///
  /// In en, this message translates to:
  /// **'Sales executive'**
  String get roleSalesExec;

  /// No description provided for @roleKam.
  ///
  /// In en, this message translates to:
  /// **'Key account manager'**
  String get roleKam;

  /// No description provided for @roleSalesManager.
  ///
  /// In en, this message translates to:
  /// **'Sales manager'**
  String get roleSalesManager;

  /// No description provided for @roleGm.
  ///
  /// In en, this message translates to:
  /// **'General manager'**
  String get roleGm;

  /// No description provided for @clients.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get clients;

  /// No description provided for @map.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map;

  /// No description provided for @visits.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get visits;

  /// No description provided for @liveTracking.
  ///
  /// In en, this message translates to:
  /// **'Live tracking'**
  String get liveTracking;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @users.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get users;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @addUser.
  ///
  /// In en, this message translates to:
  /// **'Add user'**
  String get addUser;

  /// No description provided for @editUser.
  ///
  /// In en, this message translates to:
  /// **'Edit user'**
  String get editUser;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @keyAccountManager.
  ///
  /// In en, this message translates to:
  /// **'Key account manager'**
  String get keyAccountManager;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email'**
  String get invalidEmail;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get passwordTooShort;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @errorWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorWithMessage(String message);

  /// No description provided for @noUsers.
  ///
  /// In en, this message translates to:
  /// **'No users yet'**
  String get noUsers;

  /// No description provided for @clientsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} clients · {green} visited recently'**
  String clientsCount(int count, int green);

  /// No description provided for @allSalespeople.
  ///
  /// In en, this message translates to:
  /// **'All sales executives'**
  String get allSalespeople;

  /// No description provided for @unassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get unassigned;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @noClients.
  ///
  /// In en, this message translates to:
  /// **'No clients'**
  String get noClients;

  /// No description provided for @importClients.
  ///
  /// In en, this message translates to:
  /// **'Import clients'**
  String get importClients;

  /// No description provided for @importPickFile.
  ///
  /// In en, this message translates to:
  /// **'Choose Odoo export (.xlsx or .csv)'**
  String get importPickFile;

  /// No description provided for @importReading.
  ///
  /// In en, this message translates to:
  /// **'Reading file…'**
  String get importReading;

  /// No description provided for @importResolving.
  ///
  /// In en, this message translates to:
  /// **'Reading locations {done}/{total}'**
  String importResolving(int done, int total);

  /// No description provided for @importNew.
  ///
  /// In en, this message translates to:
  /// **'New clients'**
  String get importNew;

  /// No description provided for @importUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated clients'**
  String get importUpdated;

  /// No description provided for @importUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Unchanged'**
  String get importUnchanged;

  /// No description provided for @importNoLocation.
  ///
  /// In en, this message translates to:
  /// **'New clients without location'**
  String get importNoLocation;

  /// No description provided for @importUnresolved.
  ///
  /// In en, this message translates to:
  /// **'New clients – location link unreadable (saved without location)'**
  String get importUnresolved;

  /// No description provided for @importDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Same VAT number, merged'**
  String get importDuplicates;

  /// No description provided for @importUnknownSalespeople.
  ///
  /// In en, this message translates to:
  /// **'Odoo salespeople not linked to a user'**
  String get importUnknownSalespeople;

  /// No description provided for @importConfirm.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importConfirm;

  /// No description provided for @importDone.
  ///
  /// In en, this message translates to:
  /// **'Import complete: {added} added, {updated} updated'**
  String importDone(int added, int updated);

  /// No description provided for @importResolverUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Short location links could not be read (server function not available). Those clients are saved without a location.'**
  String get importResolverUnavailable;

  /// No description provided for @latitude.
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get latitude;

  /// No description provided for @longitude.
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get longitude;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @mobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get mobile;

  /// No description provided for @salesExecutive.
  ///
  /// In en, this message translates to:
  /// **'Sales executive'**
  String get salesExecutive;

  /// No description provided for @openInMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Google Maps'**
  String get openInMaps;

  /// No description provided for @editClient.
  ///
  /// In en, this message translates to:
  /// **'Edit client'**
  String get editClient;

  /// No description provided for @lastVisit.
  ///
  /// In en, this message translates to:
  /// **'Last visit'**
  String get lastVisit;

  /// No description provided for @never.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never;

  /// No description provided for @tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @vat.
  ///
  /// In en, this message translates to:
  /// **'VAT number'**
  String get vat;

  /// No description provided for @odooSalesperson.
  ///
  /// In en, this message translates to:
  /// **'Odoo salesperson'**
  String get odooSalesperson;

  /// No description provided for @odooSalespersonName.
  ///
  /// In en, this message translates to:
  /// **'Odoo salesperson name'**
  String get odooSalespersonName;

  /// No description provided for @odooSalespersonHelp.
  ///
  /// In en, this message translates to:
  /// **'Exactly as in the Odoo export, e.g. Sami Mansour @ Sales'**
  String get odooSalespersonHelp;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @invalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Invalid number'**
  String get invalidNumber;

  /// No description provided for @mergedContacts.
  ///
  /// In en, this message translates to:
  /// **'Merged contacts'**
  String get mergedContacts;

  /// No description provided for @noLocation.
  ///
  /// In en, this message translates to:
  /// **'No location'**
  String get noLocation;

  /// No description provided for @statusAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get statusAll;

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// No description provided for @showAllClients.
  ///
  /// In en, this message translates to:
  /// **'Show all clients'**
  String get showAllClients;

  /// No description provided for @addVisit.
  ///
  /// In en, this message translates to:
  /// **'Add visit'**
  String get addVisit;

  /// No description provided for @saveVisit.
  ///
  /// In en, this message translates to:
  /// **'Save visit'**
  String get saveVisit;

  /// No description provided for @visitNotes.
  ///
  /// In en, this message translates to:
  /// **'What was done at the visit'**
  String get visitNotes;

  /// No description provided for @visitNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Products discussed, orders, follow-ups…'**
  String get visitNotesHint;

  /// No description provided for @visitNotesRequired.
  ///
  /// In en, this message translates to:
  /// **'Write what was done at the visit'**
  String get visitNotesRequired;

  /// No description provided for @visitSaved.
  ///
  /// In en, this message translates to:
  /// **'Visit saved'**
  String get visitSaved;

  /// No description provided for @visitAlreadyTodayTitle.
  ///
  /// In en, this message translates to:
  /// **'Already visited today'**
  String get visitAlreadyTodayTitle;

  /// No description provided for @visitAlreadyToday.
  ///
  /// In en, this message translates to:
  /// **'You already saved a visit to this client today at {time}. Only one visit per client per day: open it to add photos or comments.'**
  String visitAlreadyToday(String time);

  /// No description provided for @openVisit.
  ///
  /// In en, this message translates to:
  /// **'Open visit'**
  String get openVisit;

  /// No description provided for @gettingLocation.
  ///
  /// In en, this message translates to:
  /// **'Getting your location…'**
  String get gettingLocation;

  /// No description provided for @locationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Location unavailable. Turn on GPS and try again.'**
  String get locationUnavailable;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied. Allow it in the phone settings.'**
  String get locationPermissionDenied;

  /// No description provided for @locationAccuracy.
  ///
  /// In en, this message translates to:
  /// **'GPS accuracy ±{meters} m'**
  String locationAccuracy(int meters);

  /// No description provided for @distanceFromClient.
  ///
  /// In en, this message translates to:
  /// **'{distance} from the client'**
  String distanceFromClient(String distance);

  /// No description provided for @farFromClientWarning.
  ///
  /// In en, this message translates to:
  /// **'You are {distance} from this client. The visit will be flagged as far from the client. Save anyway?'**
  String farFromClientWarning(String distance);

  /// No description provided for @mockedLocationWarning.
  ///
  /// In en, this message translates to:
  /// **'Fake GPS detected. This visit will be flagged.'**
  String get mockedLocationWarning;

  /// No description provided for @setClientLocationHere.
  ///
  /// In en, this message translates to:
  /// **'Set the client\'s location to my current position'**
  String get setClientLocationHere;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @saveAnyway.
  ///
  /// In en, this message translates to:
  /// **'Save anyway'**
  String get saveAnyway;

  /// No description provided for @myLocation.
  ///
  /// In en, this message translates to:
  /// **'My location'**
  String get myLocation;

  /// No description provided for @visitHistory.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get visitHistory;

  /// No description provided for @noVisits.
  ///
  /// In en, this message translates to:
  /// **'No visits yet'**
  String get noVisits;

  /// No description provided for @farFlag.
  ///
  /// In en, this message translates to:
  /// **'Far from client ({distance})'**
  String farFlag(String distance);

  /// No description provided for @fakeGpsFlag.
  ///
  /// In en, this message translates to:
  /// **'Fake GPS'**
  String get fakeGpsFlag;

  /// No description provided for @emailInUse.
  ///
  /// In en, this message translates to:
  /// **'This email already has an account. Enter the password used the first time, or delete the account in Firebase Console → Authentication and try again.'**
  String get emailInUse;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteUserTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deleteUserTitle(String name);

  /// No description provided for @deleteUserBody.
  ///
  /// In en, this message translates to:
  /// **'The user is deleted for good: their login account (the email can be used again), profile and location data. Their clients become unassigned and their team loses its KAM. Their visits, plans, attendance and leave are kept.'**
  String get deleteUserBody;

  /// No description provided for @userDeleted.
  ///
  /// In en, this message translates to:
  /// **'User deleted'**
  String get userDeleted;

  /// No description provided for @savedWithClients.
  ///
  /// In en, this message translates to:
  /// **'Saved · {count} clients from Odoo assigned'**
  String savedWithClients(int count);

  /// No description provided for @pickOnMap.
  ///
  /// In en, this message translates to:
  /// **'Pick on map'**
  String get pickOnMap;

  /// No description provided for @pickOnMapHint.
  ///
  /// In en, this message translates to:
  /// **'Move the map so the pin is on the client\'s location'**
  String get pickOnMapHint;

  /// No description provided for @useThisLocation.
  ///
  /// In en, this message translates to:
  /// **'Use this location'**
  String get useThisLocation;

  /// No description provided for @useMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get useMyLocation;

  /// No description provided for @importLocationsOnly.
  ///
  /// In en, this message translates to:
  /// **'Import locations only (client name + location)'**
  String get importLocationsOnly;

  /// No description provided for @chooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get chooseFile;

  /// No description provided for @locationSheetColumns.
  ///
  /// In en, this message translates to:
  /// **'The sheet needs a header row with:\n• Client name (\"Name\" or \"Complete Name\") or \"Tax ID\"\n• A location: a Google Maps link (\"Location\" or \"Google Pin\"), \"24.71, 46.67\" text, or \"Latitude\" + \"Longitude\" columns'**
  String get locationSheetColumns;

  /// No description provided for @shortLinksUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Short Google Maps links can\'t be read until the server function is deployed. Use full links or coordinates for now.'**
  String get shortLinksUnavailable;

  /// No description provided for @locationsToSet.
  ///
  /// In en, this message translates to:
  /// **'Clients getting a location'**
  String get locationsToSet;

  /// No description provided for @locationsToReplace.
  ///
  /// In en, this message translates to:
  /// **'Clients whose location will change'**
  String get locationsToReplace;

  /// No description provided for @clientNotFound.
  ///
  /// In en, this message translates to:
  /// **'No matching client'**
  String get clientNotFound;

  /// No description provided for @sameNameSeveralClients.
  ///
  /// In en, this message translates to:
  /// **'Name matches several clients (add Tax ID)'**
  String get sameNameSeveralClients;

  /// No description provided for @locationUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Location couldn\'t be read'**
  String get locationUnreadable;

  /// No description provided for @replaceExistingLocations.
  ///
  /// In en, this message translates to:
  /// **'Also replace locations that are already set'**
  String get replaceExistingLocations;

  /// No description provided for @updateLocationsButton.
  ///
  /// In en, this message translates to:
  /// **'Update {count} locations'**
  String updateLocationsButton(int count);

  /// No description provided for @locationsUpdated.
  ///
  /// In en, this message translates to:
  /// **'{count} locations updated'**
  String locationsUpdated(int count);

  /// No description provided for @everyone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get everyone;

  /// No description provided for @withKam.
  ///
  /// In en, this message translates to:
  /// **'With KAM {name}'**
  String withKam(String name);

  /// No description provided for @kamWasThere.
  ///
  /// In en, this message translates to:
  /// **'{name} (KAM) was at this visit'**
  String kamWasThere(String name);

  /// No description provided for @markedHoursLater.
  ///
  /// In en, this message translates to:
  /// **'Marked {hours} h after the visit'**
  String markedHoursLater(int hours);

  /// No description provided for @iWasThere.
  ///
  /// In en, this message translates to:
  /// **'I was at this visit'**
  String get iWasThere;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @visitedBy.
  ///
  /// In en, this message translates to:
  /// **'Visited by {name}'**
  String visitedBy(String name);

  /// No description provided for @openClient.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openClient;

  /// No description provided for @comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comments;

  /// No description provided for @noComments.
  ///
  /// In en, this message translates to:
  /// **'No comments yet'**
  String get noComments;

  /// No description provided for @writeComment.
  ///
  /// In en, this message translates to:
  /// **'Write a comment…'**
  String get writeComment;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @pasteMapsLink.
  ///
  /// In en, this message translates to:
  /// **'Paste Google Maps link'**
  String get pasteMapsLink;

  /// No description provided for @pasteMapsLinkHint.
  ///
  /// In en, this message translates to:
  /// **'https://maps.app.goo.gl/… or 24.63, 46.80'**
  String get pasteMapsLinkHint;

  /// No description provided for @linkUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read a location from this link. Open it in Google Maps, tap Share → Copy link, and paste that.'**
  String get linkUnreadable;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{m} min ago'**
  String minutesAgo(int m);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{h} h ago'**
  String hoursAgo(int h);

  /// No description provided for @liveUpdated.
  ///
  /// In en, this message translates to:
  /// **'Live · updated {ago}'**
  String liveUpdated(String ago);

  /// No description provided for @liveGpsOff.
  ///
  /// In en, this message translates to:
  /// **'Online, but GPS is turned off'**
  String get liveGpsOff;

  /// No description provided for @liveNoFix.
  ///
  /// In en, this message translates to:
  /// **'Online, no new location since {ago}'**
  String liveNoFix(String ago);

  /// No description provided for @liveOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline · last seen {ago}'**
  String liveOffline(String ago);

  /// No description provided for @liveNotAlways.
  ///
  /// In en, this message translates to:
  /// **'Location is not set to \"Allow all the time\" on this phone'**
  String get liveNotAlways;

  /// No description provided for @noTrackedStaff.
  ///
  /// In en, this message translates to:
  /// **'No sales staff to show'**
  String get noTrackedStaff;

  /// No description provided for @noLocationYet.
  ///
  /// In en, this message translates to:
  /// **'No location received yet'**
  String get noLocationYet;

  /// No description provided for @showEveryone.
  ///
  /// In en, this message translates to:
  /// **'Show everyone'**
  String get showEveryone;

  /// No description provided for @callPhone.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get callPhone;

  /// No description provided for @sharingOn.
  ///
  /// In en, this message translates to:
  /// **'Location sharing is on'**
  String get sharingOn;

  /// No description provided for @sharingIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Location sharing is on, but needs attention'**
  String get sharingIncomplete;

  /// No description provided for @sharingOff.
  ///
  /// In en, this message translates to:
  /// **'Location sharing is off'**
  String get sharingOff;

  /// No description provided for @issueGpsOff.
  ///
  /// In en, this message translates to:
  /// **'GPS is turned off'**
  String get issueGpsOff;

  /// No description provided for @issueLocationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission is not allowed'**
  String get issueLocationDenied;

  /// No description provided for @issueNotAlways.
  ///
  /// In en, this message translates to:
  /// **'Set location to \"Allow all the time\"'**
  String get issueNotAlways;

  /// No description provided for @issueNotifications.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications (keeps sharing running)'**
  String get issueNotifications;

  /// No description provided for @issueBattery.
  ///
  /// In en, this message translates to:
  /// **'Turn off battery optimization for this app'**
  String get issueBattery;

  /// No description provided for @fix.
  ///
  /// In en, this message translates to:
  /// **'Fix'**
  String get fix;

  /// No description provided for @xiaomiHint.
  ///
  /// In en, this message translates to:
  /// **'On Xiaomi, Huawei or Oppo phones also open App settings → turn on Autostart and set Battery saver to \"No restrictions\".'**
  String get xiaomiHint;

  /// No description provided for @appSettings.
  ///
  /// In en, this message translates to:
  /// **'App settings'**
  String get appSettings;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @myPlan.
  ///
  /// In en, this message translates to:
  /// **'My plan'**
  String get myPlan;

  /// No description provided for @planOf.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s plan'**
  String planOf(String name);

  /// No description provided for @addToTodaysPlan.
  ///
  /// In en, this message translates to:
  /// **'Add to today\'s plan'**
  String get addToTodaysPlan;

  /// No description provided for @onTodaysPlan.
  ///
  /// In en, this message translates to:
  /// **'On today\'s plan'**
  String get onTodaysPlan;

  /// No description provided for @moveToSalesperson.
  ///
  /// In en, this message translates to:
  /// **'Move to another salesperson'**
  String get moveToSalesperson;

  /// No description provided for @clientType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get clientType;

  /// No description provided for @clientTypeCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get clientTypeCompany;

  /// No description provided for @clientTypeIndividual.
  ///
  /// In en, this message translates to:
  /// **'Individual'**
  String get clientTypeIndividual;

  /// No description provided for @companyId.
  ///
  /// In en, this message translates to:
  /// **'Company ID (CR)'**
  String get companyId;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @importFillOnly.
  ///
  /// In en, this message translates to:
  /// **'Only fill missing fields'**
  String get importFillOnly;

  /// No description provided for @importFillOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'Contact person, Company / Individual and Company ID of existing clients, only where empty. Nothing else changes and no clients are added.'**
  String get importFillOnlyHint;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearFilters;

  /// No description provided for @clientTags.
  ///
  /// In en, this message translates to:
  /// **'Client tags'**
  String get clientTags;

  /// No description provided for @tagFilterAny.
  ///
  /// In en, this message translates to:
  /// **'Shows clients with any of the selected tags.'**
  String get tagFilterAny;

  /// No description provided for @tagClientsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tags for {count} clients'**
  String tagClientsTitle(int count);

  /// No description provided for @tagClientsHelp.
  ///
  /// In en, this message translates to:
  /// **'Tap a tag once to add it, twice to remove it. Other tags stay as they are.'**
  String get tagClientsHelp;

  /// No description provided for @tagWillAdd.
  ///
  /// In en, this message translates to:
  /// **'Will be added'**
  String get tagWillAdd;

  /// No description provided for @tagWillRemove.
  ///
  /// In en, this message translates to:
  /// **'Will be removed'**
  String get tagWillRemove;

  /// No description provided for @tagsUpdatedCount.
  ///
  /// In en, this message translates to:
  /// **'Tags updated for {count} clients'**
  String tagsUpdatedCount(int count);

  /// No description provided for @addTag.
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get addTag;

  /// No description provided for @editTag.
  ///
  /// In en, this message translates to:
  /// **'Edit tag'**
  String get editTag;

  /// No description provided for @tagNameEn.
  ///
  /// In en, this message translates to:
  /// **'Name (English)'**
  String get tagNameEn;

  /// No description provided for @tagNameAr.
  ///
  /// In en, this message translates to:
  /// **'Name (Arabic)'**
  String get tagNameAr;

  /// No description provided for @tagDuplicate.
  ///
  /// In en, this message translates to:
  /// **'A tag with this name already exists'**
  String get tagDuplicate;

  /// No description provided for @deleteTagTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteTagTitle(String name);

  /// No description provided for @deleteTagBody.
  ///
  /// In en, this message translates to:
  /// **'It is removed from {count} clients. This cannot be undone.'**
  String deleteTagBody(int count);

  /// No description provided for @clientTagsHelp.
  ///
  /// In en, this message translates to:
  /// **'Tags describe the client\'s business (factory, showroom, …). Use them to filter the client list and map. Tag clients on their edit screen, or select several in the client list.'**
  String get clientTagsHelp;

  /// No description provided for @clientsCountShort.
  ///
  /// In en, this message translates to:
  /// **'{count} clients'**
  String clientsCountShort(int count);

  /// No description provided for @addToPlan.
  ///
  /// In en, this message translates to:
  /// **'Add to plan'**
  String get addToPlan;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @nothingPlanned.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned for this day'**
  String get nothingPlanned;

  /// No description provided for @planSummary.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} done · {pending} waiting for approval'**
  String planSummary(int done, int total, int pending);

  /// No description provided for @waitingApproval.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval'**
  String get waitingApproval;

  /// No description provided for @rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @toDo.
  ///
  /// In en, this message translates to:
  /// **'To do'**
  String get toDo;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @chooseClient.
  ///
  /// In en, this message translates to:
  /// **'Choose a client'**
  String get chooseClient;

  /// No description provided for @clientVisit.
  ///
  /// In en, this message translates to:
  /// **'Client visit'**
  String get clientVisit;

  /// No description provided for @task.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get task;

  /// No description provided for @noteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get noteOptional;

  /// No description provided for @taskDescription.
  ///
  /// In en, this message translates to:
  /// **'What needs to be done'**
  String get taskDescription;

  /// No description provided for @needsApprovalHint.
  ///
  /// In en, this message translates to:
  /// **'Your KAM will approve this before it counts in your plan.'**
  String get needsApprovalHint;

  /// No description provided for @todaysPlan.
  ///
  /// In en, this message translates to:
  /// **'Today\'s plan'**
  String get todaysPlan;

  /// No description provided for @openPlan.
  ///
  /// In en, this message translates to:
  /// **'Open plan'**
  String get openPlan;

  /// No description provided for @monthProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress · {month}'**
  String monthProgress(String month);

  /// No description provided for @visitsOfTarget.
  ///
  /// In en, this message translates to:
  /// **'{count} of {target} visits'**
  String visitsOfTarget(int count, int target);

  /// No description provided for @visitsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'{count} visits this month'**
  String visitsThisMonth(int count);

  /// No description provided for @planTasksDone.
  ///
  /// In en, this message translates to:
  /// **'Planned tasks done'**
  String get planTasksDone;

  /// No description provided for @missedTasks.
  ///
  /// In en, this message translates to:
  /// **'Missed tasks'**
  String get missedTasks;

  /// No description provided for @rideAlongs.
  ///
  /// In en, this message translates to:
  /// **'Visits with KAM'**
  String get rideAlongs;

  /// No description provided for @flaggedVisits.
  ///
  /// In en, this message translates to:
  /// **'Flagged visits'**
  String get flaggedVisits;

  /// No description provided for @coverage.
  ///
  /// In en, this message translates to:
  /// **'Clients covered'**
  String get coverage;

  /// No description provided for @waitingForYourApproval.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your approval ({count})'**
  String waitingForYourApproval(int count);

  /// No description provided for @myTeam.
  ///
  /// In en, this message translates to:
  /// **'My team'**
  String get myTeam;

  /// No description provided for @teamLine.
  ///
  /// In en, this message translates to:
  /// **'Today {done}/{total} done · Month visits {visits}'**
  String teamLine(int done, int total, String visits);

  /// No description provided for @noKamHint.
  ///
  /// In en, this message translates to:
  /// **'You have no KAM assigned yet, so your sales manager approves your plan.'**
  String get noKamHint;

  /// No description provided for @monthlyVisitTarget.
  ///
  /// In en, this message translates to:
  /// **'Monthly visit target'**
  String get monthlyVisitTarget;

  /// No description provided for @monthlyVisitTargetHelp.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for no target'**
  String get monthlyVisitTargetHelp;

  /// No description provided for @paceOnTrack.
  ///
  /// In en, this message translates to:
  /// **'On track'**
  String get paceOnTrack;

  /// No description provided for @paceSlightlyBehind.
  ///
  /// In en, this message translates to:
  /// **'Slightly behind'**
  String get paceSlightlyBehind;

  /// No description provided for @paceBehind.
  ///
  /// In en, this message translates to:
  /// **'Behind'**
  String get paceBehind;

  /// No description provided for @completedVisits.
  ///
  /// In en, this message translates to:
  /// **'Completed visits'**
  String get completedVisits;

  /// No description provided for @target.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get target;

  /// No description provided for @targetPace.
  ///
  /// In en, this message translates to:
  /// **'Target pace'**
  String get targetPace;

  /// No description provided for @barTooltip.
  ///
  /// In en, this message translates to:
  /// **'{name}: {done} visits · target {target} · expected by today {expected}'**
  String barTooltip(String name, int done, int target, int expected);

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get thisMonth;

  /// No description provided for @lastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get lastMonth;

  /// No description provided for @customRange.
  ///
  /// In en, this message translates to:
  /// **'Custom dates'**
  String get customRange;

  /// No description provided for @noTargetSet.
  ///
  /// In en, this message translates to:
  /// **'No target set'**
  String get noTargetSet;

  /// No description provided for @coverageDetail.
  ///
  /// In en, this message translates to:
  /// **'{green} of {total} clients visited recently'**
  String coverageDetail(int green, int total);

  /// No description provided for @planCompletion.
  ///
  /// In en, this message translates to:
  /// **'Plan completion'**
  String get planCompletion;

  /// No description provided for @tasksDetail.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} planned tasks'**
  String tasksDetail(int done, int total);

  /// No description provided for @flaggedDetail.
  ///
  /// In en, this message translates to:
  /// **'Far from client or fake GPS'**
  String get flaggedDetail;

  /// No description provided for @visitsVsTarget.
  ///
  /// In en, this message translates to:
  /// **'Visits vs target'**
  String get visitsVsTarget;

  /// No description provided for @progressVsTarget.
  ///
  /// In en, this message translates to:
  /// **'Progress vs target pace'**
  String get progressVsTarget;

  /// No description provided for @statusRecent.
  ///
  /// In en, this message translates to:
  /// **'Visited recently'**
  String get statusRecent;

  /// No description provided for @statusDueSoon.
  ///
  /// In en, this message translates to:
  /// **'Due soon'**
  String get statusDueSoon;

  /// No description provided for @statusOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get statusOverdue;

  /// No description provided for @plannedToday.
  ///
  /// In en, this message translates to:
  /// **'Planned today'**
  String get plannedToday;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @categoryName.
  ///
  /// In en, this message translates to:
  /// **'Category {c}'**
  String categoryName(String c);

  /// No description provided for @categoryRule.
  ///
  /// In en, this message translates to:
  /// **'{c} · green up to {green} days, yellow up to {yellow} days'**
  String categoryRule(String c, int green, int yellow);

  /// No description provided for @visitStatus.
  ///
  /// In en, this message translates to:
  /// **'Visit status'**
  String get visitStatus;

  /// No description provided for @visitFrequency.
  ///
  /// In en, this message translates to:
  /// **'Visit frequency'**
  String get visitFrequency;

  /// No description provided for @visitFrequencyHelp.
  ///
  /// In en, this message translates to:
  /// **'Days since the last visit before a client turns yellow, then red. Clients never visited are red.'**
  String get visitFrequencyHelp;

  /// No description provided for @greenUpTo.
  ///
  /// In en, this message translates to:
  /// **'Green up to (days)'**
  String get greenUpTo;

  /// No description provided for @yellowUpTo.
  ///
  /// In en, this message translates to:
  /// **'Yellow up to (days)'**
  String get yellowUpTo;

  /// No description provided for @yellowAfterGreen.
  ///
  /// In en, this message translates to:
  /// **'Must be more than green'**
  String get yellowAfterGreen;

  /// No description provided for @redAfter.
  ///
  /// In en, this message translates to:
  /// **'Red after that'**
  String get redAfter;

  /// No description provided for @importDefaultCategory.
  ///
  /// In en, this message translates to:
  /// **'Category for new clients (when the sheet has no Category column)'**
  String get importDefaultCategory;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get noNotifications;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @notifPlanSubmitted.
  ///
  /// In en, this message translates to:
  /// **'{name} added {count} items to their plan for {day} – waiting for your approval'**
  String notifPlanSubmitted(String name, int count, String day);

  /// No description provided for @notifPlanApproved.
  ///
  /// In en, this message translates to:
  /// **'{name} approved your plan for {day}'**
  String notifPlanApproved(String name, String day);

  /// No description provided for @notifPlanRejected.
  ///
  /// In en, this message translates to:
  /// **'{name} rejected an item in your plan for {day}'**
  String notifPlanRejected(String name, String day);

  /// No description provided for @notifPlanChanged.
  ///
  /// In en, this message translates to:
  /// **'{name} changed your plan for {day}'**
  String notifPlanChanged(String name, String day);

  /// No description provided for @planUpdated.
  ///
  /// In en, this message translates to:
  /// **'{count} added to the plan'**
  String planUpdated(int count);

  /// No description provided for @planSentForApproval.
  ///
  /// In en, this message translates to:
  /// **'{count} added and sent for approval'**
  String planSentForApproval(int count);

  /// No description provided for @saveCount.
  ///
  /// In en, this message translates to:
  /// **'Save ({count})'**
  String saveCount(int count);

  /// No description provided for @showOnMap.
  ///
  /// In en, this message translates to:
  /// **'Show on map'**
  String get showOnMap;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @shareTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} – plan for {day}'**
  String shareTitle(String name, String day);

  /// No description provided for @tasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasks;

  /// No description provided for @route.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get route;

  /// No description provided for @approveAll.
  ///
  /// In en, this message translates to:
  /// **'Approve all ({count})'**
  String approveAll(int count);

  /// No description provided for @removeFromPlan.
  ///
  /// In en, this message translates to:
  /// **'Remove from plan'**
  String get removeFromPlan;

  /// No description provided for @planClientsWithoutLocation.
  ///
  /// In en, this message translates to:
  /// **'{count} planned clients have no location and are not on the map'**
  String planClientsWithoutLocation(int count);

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @clearPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear plan?'**
  String get clearPlanTitle;

  /// No description provided for @clearPlanUnapproved.
  ///
  /// In en, this message translates to:
  /// **'Remove the {count} items that are not approved yet?'**
  String clearPlanUnapproved(int count);

  /// No description provided for @clearPlanAll.
  ///
  /// In en, this message translates to:
  /// **'Remove all {count} items from this day\'s plan? The sales executive will be notified.'**
  String clearPlanAll(int count);

  /// No description provided for @addClient.
  ///
  /// In en, this message translates to:
  /// **'Add client'**
  String get addClient;

  /// No description provided for @clientName.
  ///
  /// In en, this message translates to:
  /// **'Client name'**
  String get clientName;

  /// No description provided for @clientAdded.
  ///
  /// In en, this message translates to:
  /// **'Client added'**
  String get clientAdded;

  /// No description provided for @possibleDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Client may already exist'**
  String get possibleDuplicate;

  /// No description provided for @possibleDuplicateBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" is already in the app with the same name or VAT number. Add a new client anyway?'**
  String possibleDuplicateBody(String name);

  /// No description provided for @addAnyway.
  ///
  /// In en, this message translates to:
  /// **'Add anyway'**
  String get addAnyway;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contact;

  /// No description provided for @addPhoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a contact number'**
  String get addPhoneTitle;

  /// No description provided for @addPhoneMessage.
  ///
  /// In en, this message translates to:
  /// **'{client} has no phone number. Add one to save this visit.'**
  String addPhoneMessage(String client);

  /// No description provided for @addPhoneMessageCall.
  ///
  /// In en, this message translates to:
  /// **'{client} has no phone number. Add one to save this call.'**
  String addPhoneMessageCall(String client);

  /// No description provided for @pickFromContacts.
  ///
  /// In en, this message translates to:
  /// **'Choose from phone contacts'**
  String get pickFromContacts;

  /// No description provided for @phoneNumberInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a phone number (7 to 15 digits)'**
  String get phoneNumberInvalid;

  /// No description provided for @saudiPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a Saudi mobile number: 05X XXX XXXX (10 digits)'**
  String get saudiPhoneInvalid;

  /// No description provided for @phoneNumberSaved.
  ///
  /// In en, this message translates to:
  /// **'Contact number saved'**
  String get phoneNumberSaved;

  /// No description provided for @saveAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Save and continue'**
  String get saveAndContinue;

  /// No description provided for @contactPerson.
  ///
  /// In en, this message translates to:
  /// **'Contact person'**
  String get contactPerson;

  /// No description provided for @locationSection.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationSection;

  /// No description provided for @salesSection.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get salesSection;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @directions.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get directions;

  /// No description provided for @addedInApp.
  ///
  /// In en, this message translates to:
  /// **'Added in app'**
  String get addedInApp;

  /// No description provided for @noContactDetails.
  ///
  /// In en, this message translates to:
  /// **'No contact details yet'**
  String get noContactDetails;

  /// No description provided for @coordinates.
  ///
  /// In en, this message translates to:
  /// **'Coordinates'**
  String get coordinates;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days} days ago'**
  String daysAgo(int days);

  /// No description provided for @importLinkedContacts.
  ///
  /// In en, this message translates to:
  /// **'Contact people linked to a company'**
  String get importLinkedContacts;

  /// No description provided for @accountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountSection;

  /// No description provided for @receivable.
  ///
  /// In en, this message translates to:
  /// **'Receivable (owed to us)'**
  String get receivable;

  /// No description provided for @payable.
  ///
  /// In en, this message translates to:
  /// **'Payable (we owe)'**
  String get payable;

  /// No description provided for @street.
  ///
  /// In en, this message translates to:
  /// **'Street'**
  String get street;

  /// No description provided for @region.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get region;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @teamPlansToday.
  ///
  /// In en, this message translates to:
  /// **'Team plans today'**
  String get teamPlansToday;

  /// No description provided for @attachments.
  ///
  /// In en, this message translates to:
  /// **'Photos & files'**
  String get attachments;

  /// No description provided for @noAttachments.
  ///
  /// In en, this message translates to:
  /// **'No photos or files yet'**
  String get noAttachments;

  /// No description provided for @addAttachment.
  ///
  /// In en, this message translates to:
  /// **'Add photo or file'**
  String get addAttachment;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chooseFromGallery;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get uploading;

  /// No description provided for @deleteAttachmentConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deleteAttachmentConfirm(String name);

  /// No description provided for @fileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'{name} is larger than 20 MB'**
  String fileTooLarge(String name);

  /// No description provided for @visitPhotos.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No photos} =1{1 photo or file} other{{count} photos or files}}'**
  String visitPhotos(int count);

  /// No description provided for @addUnmatchedClients.
  ///
  /// In en, this message translates to:
  /// **'Add {count} unmatched rows as new clients'**
  String addUnmatchedClients(int count);

  /// No description provided for @newClientsAssignedTo.
  ///
  /// In en, this message translates to:
  /// **'Assigned to {name} · {noLocation} without location'**
  String newClientsAssignedTo(String name, int noLocation);

  /// No description provided for @importApplyButton.
  ///
  /// In en, this message translates to:
  /// **'Add {added} clients · update {updated} locations'**
  String importApplyButton(int added, int updated);

  /// No description provided for @importApplyDone.
  ///
  /// In en, this message translates to:
  /// **'{added} clients added · {updated} locations updated'**
  String importApplyDone(int added, int updated);

  /// No description provided for @newVisit.
  ///
  /// In en, this message translates to:
  /// **'New visit'**
  String get newVisit;

  /// No description provided for @searchVisits.
  ///
  /// In en, this message translates to:
  /// **'Search client or notes'**
  String get searchVisits;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allTime;

  /// No description provided for @visitsTotal.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get visitsTotal;

  /// No description provided for @withKamCount.
  ///
  /// In en, this message translates to:
  /// **'With KAM'**
  String get withKamCount;

  /// No description provided for @noVisitsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap \"New visit\" to check in at a client'**
  String get noVisitsHint;

  /// No description provided for @noMatchingVisits.
  ///
  /// In en, this message translates to:
  /// **'No visits match these filters'**
  String get noMatchingVisits;

  /// No description provided for @planProgress.
  ///
  /// In en, this message translates to:
  /// **'Plan progress'**
  String get planProgress;

  /// No description provided for @missed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get missed;

  /// No description provided for @noPlanItems.
  ///
  /// In en, this message translates to:
  /// **'No plan items in this period'**
  String get noPlanItems;

  /// No description provided for @clientVisitsCard.
  ///
  /// In en, this message translates to:
  /// **'Client visits'**
  String get clientVisitsCard;

  /// No description provided for @visitedLabel.
  ///
  /// In en, this message translates to:
  /// **'Visited'**
  String get visitedLabel;

  /// No description provided for @notVisitedYet.
  ///
  /// In en, this message translates to:
  /// **'Not visited yet'**
  String get notVisitedYet;

  /// No description provided for @noAssignedClients.
  ///
  /// In en, this message translates to:
  /// **'No clients assigned'**
  String get noAssignedClients;

  /// No description provided for @ofTotal.
  ///
  /// In en, this message translates to:
  /// **'of {total}'**
  String ofTotal(int total);

  /// No description provided for @visitedOfClients.
  ///
  /// In en, this message translates to:
  /// **'{visited} of {total} clients visited · {pending} still pending'**
  String visitedOfClients(int visited, int total, int pending);

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @tripDetails.
  ///
  /// In en, this message translates to:
  /// **'Trip details'**
  String get tripDetails;

  /// No description provided for @routeHistory.
  ///
  /// In en, this message translates to:
  /// **'Route history'**
  String get routeHistory;

  /// No description provided for @person.
  ///
  /// In en, this message translates to:
  /// **'Person'**
  String get person;

  /// No description provided for @clientsVisitedColumn.
  ///
  /// In en, this message translates to:
  /// **'Clients visited'**
  String get clientsVisitedColumn;

  /// No description provided for @ownClientsVisited.
  ///
  /// In en, this message translates to:
  /// **'Own clients visited'**
  String get ownClientsVisited;

  /// No description provided for @onSchedule.
  ///
  /// In en, this message translates to:
  /// **'On schedule'**
  String get onSchedule;

  /// No description provided for @unvisitedInPeriod.
  ///
  /// In en, this message translates to:
  /// **'Not visited in this period ({count})'**
  String unvisitedInPeriod(int count);

  /// No description provided for @allClientsVisited.
  ///
  /// In en, this message translates to:
  /// **'Every client was visited in this period'**
  String get allClientsVisited;

  /// No description provided for @showAllCount.
  ///
  /// In en, this message translates to:
  /// **'Show all ({count})'**
  String showAllCount(int count);

  /// No description provided for @importHistory.
  ///
  /// In en, this message translates to:
  /// **'Imports'**
  String get importHistory;

  /// No description provided for @noImports.
  ///
  /// In en, this message translates to:
  /// **'No imports yet'**
  String get noImports;

  /// No description provided for @importBatchLine.
  ///
  /// In en, this message translates to:
  /// **'{added} new · {updated} updated · {unchanged} unchanged'**
  String importBatchLine(int added, int updated, int unchanged);

  /// No description provided for @importedByName.
  ///
  /// In en, this message translates to:
  /// **'by {name}'**
  String importedByName(String name);

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @firstLocation.
  ///
  /// In en, this message translates to:
  /// **'First location'**
  String get firstLocation;

  /// No description provided for @lastLocation.
  ///
  /// In en, this message translates to:
  /// **'Last location'**
  String get lastLocation;

  /// No description provided for @locationPointsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} points'**
  String locationPointsCount(int count);

  /// No description provided for @fakeGpsPoints.
  ///
  /// In en, this message translates to:
  /// **'{count} fake GPS points'**
  String fakeGpsPoints(int count);

  /// No description provided for @noRouteData.
  ///
  /// In en, this message translates to:
  /// **'No locations recorded for this day'**
  String get noRouteData;

  /// No description provided for @choosePerson.
  ///
  /// In en, this message translates to:
  /// **'Choose a person'**
  String get choosePerson;

  /// No description provided for @previousDay.
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get previousDay;

  /// No description provided for @nextDay.
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get nextDay;

  /// No description provided for @trackingGaps.
  ///
  /// In en, this message translates to:
  /// **'{count} gaps in tracking'**
  String trackingGaps(int count);

  /// No description provided for @hiddenClients.
  ///
  /// In en, this message translates to:
  /// **'Hidden clients'**
  String get hiddenClients;

  /// No description provided for @hideClient.
  ///
  /// In en, this message translates to:
  /// **'Hide client'**
  String get hideClient;

  /// No description provided for @unhideClient.
  ///
  /// In en, this message translates to:
  /// **'Show again'**
  String get unhideClient;

  /// No description provided for @hideClientTitle.
  ///
  /// In en, this message translates to:
  /// **'Hide this client?'**
  String get hideClientTitle;

  /// No description provided for @hideClientBody.
  ///
  /// In en, this message translates to:
  /// **'They will be left out of client lists, the map, plans, visits and all statistics, for everyone. Their visits and data are kept. To show them again, use the \"Hidden\" filter in Clients.'**
  String get hideClientBody;

  /// No description provided for @clientHiddenBanner.
  ///
  /// In en, this message translates to:
  /// **'Hidden: left out of lists and statistics'**
  String get clientHiddenBanner;

  /// No description provided for @clientHidden.
  ///
  /// In en, this message translates to:
  /// **'Client hidden'**
  String get clientHidden;

  /// No description provided for @clientUnhidden.
  ///
  /// In en, this message translates to:
  /// **'Client shown again'**
  String get clientUnhidden;

  /// No description provided for @selectClients.
  ///
  /// In en, this message translates to:
  /// **'Select clients'**
  String get selectClients;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @hideClientsTitle.
  ///
  /// In en, this message translates to:
  /// **'Hide {count} clients?'**
  String hideClientsTitle(int count);

  /// No description provided for @clientsHiddenCount.
  ///
  /// In en, this message translates to:
  /// **'{count} clients hidden'**
  String clientsHiddenCount(int count);

  /// No description provided for @clientsUnhiddenCount.
  ///
  /// In en, this message translates to:
  /// **'{count} clients shown again'**
  String clientsUnhiddenCount(int count);

  /// No description provided for @liveOffDuty.
  ///
  /// In en, this message translates to:
  /// **'Off duty · outside work hours, location not shared'**
  String get liveOffDuty;

  /// No description provided for @workHours.
  ///
  /// In en, this message translates to:
  /// **'Work hours'**
  String get workHours;

  /// No description provided for @workHoursHelp.
  ///
  /// In en, this message translates to:
  /// **'Field staff locations are shared only on these days and hours (Saudi time). Outside them nothing is sent and people show as off duty.'**
  String get workHoursHelp;

  /// No description provided for @workDays.
  ///
  /// In en, this message translates to:
  /// **'Work days'**
  String get workDays;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startTime;

  /// No description provided for @endTime.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get endTime;

  /// No description provided for @endAfterStart.
  ///
  /// In en, this message translates to:
  /// **'End time must be after start time'**
  String get endAfterStart;

  /// No description provided for @transferClients.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transferClients;

  /// No description provided for @transferClientsTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer {count} clients to'**
  String transferClientsTitle(int count);

  /// No description provided for @transferClientTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer client to'**
  String get transferClientTitle;

  /// No description provided for @transferPlanNote.
  ///
  /// In en, this message translates to:
  /// **'Open plan items for these clients from today on are removed from the current salesperson\'s plan. Past plans and visits are kept.'**
  String get transferPlanNote;

  /// No description provided for @transferSkipped.
  ///
  /// In en, this message translates to:
  /// **'{count} selected clients are not in your team and will be skipped.'**
  String transferSkipped(int count);

  /// No description provided for @transferNoneAllowed.
  ///
  /// In en, this message translates to:
  /// **'None of the selected clients belong to your team.'**
  String get transferNoneAllowed;

  /// No description provided for @noTransferTargets.
  ///
  /// In en, this message translates to:
  /// **'No sales executives to transfer to'**
  String get noTransferTargets;

  /// No description provided for @clientsTransferredCount.
  ///
  /// In en, this message translates to:
  /// **'{count} clients moved to {name}'**
  String clientsTransferredCount(int count, String name);

  /// No description provided for @transferHistory.
  ///
  /// In en, this message translates to:
  /// **'Transfer history'**
  String get transferHistory;

  /// No description provided for @transferBy.
  ///
  /// In en, this message translates to:
  /// **'by {name} · {when}'**
  String transferBy(String name, String when);

  /// No description provided for @notifClientsTransferredIn.
  ///
  /// In en, this message translates to:
  /// **'{name} moved {count} clients to you'**
  String notifClientsTransferredIn(String name, int count);

  /// No description provided for @notifClientsTransferredOut.
  ///
  /// In en, this message translates to:
  /// **'{name} moved {count} of your clients to {other}'**
  String notifClientsTransferredOut(String name, int count, String other);

  /// No description provided for @teamPlans.
  ///
  /// In en, this message translates to:
  /// **'Team plans'**
  String get teamPlans;

  /// No description provided for @noTeamMembers.
  ///
  /// In en, this message translates to:
  /// **'No team members yet'**
  String get noTeamMembers;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @notifGpsOff.
  ///
  /// In en, this message translates to:
  /// **'{name} turned off location (GPS)'**
  String notifGpsOff(String name);

  /// No description provided for @notifLocationDenied.
  ///
  /// In en, this message translates to:
  /// **'{name} removed the app\'s location permission'**
  String notifLocationDenied(String name);

  /// No description provided for @notifLocationNotAlways.
  ///
  /// In en, this message translates to:
  /// **'{name} allowed location only while using the app – tracking stops in the background'**
  String notifLocationNotAlways(String name);

  /// No description provided for @visitDetails.
  ///
  /// In en, this message translates to:
  /// **'Visit details'**
  String get visitDetails;

  /// No description provided for @otherPhoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Your location is shared from another phone'**
  String get otherPhoneTitle;

  /// No description provided for @otherPhoneBody.
  ///
  /// In en, this message translates to:
  /// **'Another phone signed in to your account shares your location, so this phone sends nothing. If this is the phone you work with, tap \"Use this phone\".'**
  String get otherPhoneBody;

  /// No description provided for @useThisPhone.
  ///
  /// In en, this message translates to:
  /// **'Use this phone'**
  String get useThisPhone;

  /// No description provided for @otherTrackIgnored.
  ///
  /// In en, this message translates to:
  /// **'{count} points from another phone ignored'**
  String otherTrackIgnored(int count);

  /// No description provided for @reportNewClients.
  ///
  /// In en, this message translates to:
  /// **'New clients ({count})'**
  String reportNewClients(int count);

  /// No description provided for @reportNoNewClients.
  ///
  /// In en, this message translates to:
  /// **'No clients were added in this period.'**
  String get reportNoNewClients;

  /// No description provided for @reportAddedInApp.
  ///
  /// In en, this message translates to:
  /// **'Added in the app'**
  String get reportAddedInApp;

  /// No description provided for @reportImported.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get reportImported;

  /// No description provided for @reportAddedBy.
  ///
  /// In en, this message translates to:
  /// **'added by {name}'**
  String reportAddedBy(String name);

  /// No description provided for @reportRouting.
  ///
  /// In en, this message translates to:
  /// **'Routing performance & efficiency'**
  String get reportRouting;

  /// No description provided for @reportNoRoutingDays.
  ///
  /// In en, this message translates to:
  /// **'No day with two or more visits in this period.'**
  String get reportNoRoutingDays;

  /// No description provided for @reportAvgEfficiency.
  ///
  /// In en, this message translates to:
  /// **'Average efficiency'**
  String get reportAvgEfficiency;

  /// No description provided for @reportDaysCounted.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get reportDaysCounted;

  /// No description provided for @reportVisitsPerDay.
  ///
  /// In en, this message translates to:
  /// **'Visits / day'**
  String get reportVisitsPerDay;

  /// No description provided for @reportShortestOrderDays.
  ///
  /// In en, this message translates to:
  /// **'Shortest order'**
  String get reportShortestOrderDays;

  /// No description provided for @reportExtraDistance.
  ///
  /// In en, this message translates to:
  /// **'Extra distance'**
  String get reportExtraDistance;

  /// No description provided for @reportNeededTook.
  ///
  /// In en, this message translates to:
  /// **'Needed / took'**
  String get reportNeededTook;

  /// No description provided for @reportLowestDays.
  ///
  /// In en, this message translates to:
  /// **'Lowest days'**
  String get reportLowestDays;

  /// No description provided for @reportRoutingHelp.
  ///
  /// In en, this message translates to:
  /// **'Days with two or more visits. Each day\'s GPS is split into time at clients, driving, office, lunch (up to 60 min around midday), stopped elsewhere (15+ min) and no GPS data. The team benchmark is the median of the salespeople\'s own averages: time per visit, driving speed, and how much longer the roads are than a straight line. Efficiency = needed (visits × time per visit + shortest route at that speed) ÷ took (first client arrival to last client departure, without lunch and office), at most 100%. Days without GPS use the check-in times.'**
  String get reportRoutingHelp;

  /// No description provided for @reportCatalogs.
  ///
  /// In en, this message translates to:
  /// **'Catalog distribution'**
  String get reportCatalogs;

  /// No description provided for @reportNoCatalogs.
  ///
  /// In en, this message translates to:
  /// **'No catalogs or stands were handed over in this period.'**
  String get reportNoCatalogs;

  /// No description provided for @reportTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get reportTotal;

  /// No description provided for @reportClientsReached.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get reportClientsReached;

  /// No description provided for @reportCatalogsDue.
  ///
  /// In en, this message translates to:
  /// **'Clients due for a new one'**
  String get reportCatalogsDue;

  /// No description provided for @reportDueNever.
  ///
  /// In en, this message translates to:
  /// **'{item}: {due} due · {never} never given'**
  String reportDueNever(String item, int due, int never);

  /// No description provided for @reportCatalogsHelp.
  ///
  /// In en, this message translates to:
  /// **'From hand-overs at visits and recorded on client pages, counted for the person who gave them. Tap an item to see its due clients.'**
  String get reportCatalogsHelp;

  /// No description provided for @givenSwitchCatalog.
  ///
  /// In en, this message translates to:
  /// **'Swatch catalog'**
  String get givenSwitchCatalog;

  /// No description provided for @givenBookletCatalog.
  ///
  /// In en, this message translates to:
  /// **'Booklet catalog'**
  String get givenBookletCatalog;

  /// No description provided for @givenDisplayStand.
  ///
  /// In en, this message translates to:
  /// **'Display stand'**
  String get givenDisplayStand;

  /// No description provided for @givenA4Samples.
  ///
  /// In en, this message translates to:
  /// **'A4 samples'**
  String get givenA4Samples;

  /// No description provided for @itemsGiven.
  ///
  /// In en, this message translates to:
  /// **'Catalogs & stands given'**
  String get itemsGiven;

  /// No description provided for @givenNever.
  ///
  /// In en, this message translates to:
  /// **'Never given'**
  String get givenNever;

  /// No description provided for @givenLast.
  ///
  /// In en, this message translates to:
  /// **'Last: {qty} on {date}'**
  String givenLast(int qty, String date);

  /// No description provided for @givenTotal.
  ///
  /// In en, this message translates to:
  /// **'{count} in all'**
  String givenTotal(int count);

  /// No description provided for @givenDueOn.
  ///
  /// In en, this message translates to:
  /// **'new one due {date}'**
  String givenDueOn(String date);

  /// No description provided for @givenDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get givenDue;

  /// No description provided for @givenDueSoon.
  ///
  /// In en, this message translates to:
  /// **'Due soon'**
  String get givenDueSoon;

  /// No description provided for @givenItemsSettings.
  ///
  /// In en, this message translates to:
  /// **'Catalogs & stands'**
  String get givenItemsSettings;

  /// No description provided for @givenItemsHelp.
  ///
  /// In en, this message translates to:
  /// **'After how many days a client should get a new one. Clients past this show \"Due\" on their page, at check-in and in the filter.'**
  String get givenItemsHelp;

  /// No description provided for @givenEveryDaysSuffix.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get givenEveryDaysSuffix;

  /// No description provided for @givenDueFilter.
  ///
  /// In en, this message translates to:
  /// **'New catalog / stand due'**
  String get givenDueFilter;

  /// No description provided for @givenHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get givenHistory;

  /// No description provided for @givenRecord.
  ///
  /// In en, this message translates to:
  /// **'Record catalog / stand given'**
  String get givenRecord;

  /// No description provided for @givenRecordedByHand.
  ///
  /// In en, this message translates to:
  /// **'recorded'**
  String get givenRecordedByHand;

  /// No description provided for @givenAtVisit.
  ///
  /// In en, this message translates to:
  /// **'at a visit'**
  String get givenAtVisit;

  /// No description provided for @givenOn.
  ///
  /// In en, this message translates to:
  /// **'Given on'**
  String get givenOn;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @notAssignedTitle.
  ///
  /// In en, this message translates to:
  /// **'Not assigned to a sales executive'**
  String get notAssignedTitle;

  /// No description provided for @notAssignedBody.
  ///
  /// In en, this message translates to:
  /// **'{count} of the selected clients have no sales executive, so they can\'t go on a plan: {names}. Move them to someone first.'**
  String notAssignedBody(int count, String names);

  /// No description provided for @moveThemFirst.
  ///
  /// In en, this message translates to:
  /// **'Move them'**
  String get moveThemFirst;

  /// No description provided for @planTheOthers.
  ///
  /// In en, this message translates to:
  /// **'Plan the other {count}'**
  String planTheOthers(int count);

  /// No description provided for @planNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'{count} clients belong to people outside your team and are left out.'**
  String planNotAllowed(int count);

  /// No description provided for @planSelectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Add {count} clients to plans'**
  String planSelectedTitle(int count);

  /// No description provided for @planSelectedHint.
  ///
  /// In en, this message translates to:
  /// **'Each client goes on the plan of the salesperson it belongs to, approved; they are notified.'**
  String get planSelectedHint;

  /// No description provided for @plannedFromSelection.
  ///
  /// In en, this message translates to:
  /// **'Added {count} clients to {plans} plans'**
  String plannedFromSelection(int count, int plans);

  /// No description provided for @alreadyOnPlanCount.
  ///
  /// In en, this message translates to:
  /// **'{count} already on the plan'**
  String alreadyOnPlanCount(int count);

  /// No description provided for @dupSameCompanyId.
  ///
  /// In en, this message translates to:
  /// **'Same CR number'**
  String get dupSameCompanyId;

  /// No description provided for @duplicatesFoundBody.
  ///
  /// In en, this message translates to:
  /// **'These clients look like the one you are adding:'**
  String get duplicatesFoundBody;

  /// No description provided for @duplicateOverrideHint.
  ///
  /// In en, this message translates to:
  /// **'If you checked and it is a different client, you can add it.'**
  String get duplicateOverrideHint;

  /// No description provided for @duplicateAskManager.
  ///
  /// In en, this message translates to:
  /// **'If it is a different client, ask a sales manager to add it.'**
  String get duplicateAskManager;

  /// No description provided for @notDuplicateAdd.
  ///
  /// In en, this message translates to:
  /// **'Not a duplicate – add'**
  String get notDuplicateAdd;

  /// No description provided for @useThisClient.
  ///
  /// In en, this message translates to:
  /// **'Use this client'**
  String get useThisClient;

  /// No description provided for @addNewClientNamed.
  ///
  /// In en, this message translates to:
  /// **'Add \"{name}\" as a new client'**
  String addNewClientNamed(String name);

  /// No description provided for @selectClientsToMove.
  ///
  /// In en, this message translates to:
  /// **'Select clients to plan or move'**
  String get selectClientsToMove;

  /// No description provided for @tapPinsToSelect.
  ///
  /// In en, this message translates to:
  /// **'Tap pins to select clients'**
  String get tapPinsToSelect;

  /// No description provided for @selectSeveralToMove.
  ///
  /// In en, this message translates to:
  /// **'Select several clients to plan or move'**
  String get selectSeveralToMove;

  /// No description provided for @showRouteMap.
  ///
  /// In en, this message translates to:
  /// **'Show on route map'**
  String get showRouteMap;

  /// No description provided for @shortestOrderHint.
  ///
  /// In en, this message translates to:
  /// **'Numbers follow the shortest route'**
  String get shortestOrderHint;

  /// No description provided for @efficiency.
  ///
  /// In en, this message translates to:
  /// **'Efficiency'**
  String get efficiency;

  /// No description provided for @efficiencyDetail.
  ///
  /// In en, this message translates to:
  /// **'Needed about {needed} at the team\'s pace (median visit length + shortest route at the median driving speed), took {took} from arriving at the first client to leaving the last, without lunch and office time'**
  String efficiencyDetail(String needed, String took);

  /// No description provided for @efficiencyBestOrder.
  ///
  /// In en, this message translates to:
  /// **'Visits made in the shortest order'**
  String get efficiencyBestOrder;

  /// No description provided for @efficiencyOtherOrder.
  ///
  /// In en, this message translates to:
  /// **'Shortest order: {shortest} between visits instead of {taken}'**
  String efficiencyOtherOrder(String shortest, String taken);

  /// No description provided for @notifNotificationsOff.
  ///
  /// In en, this message translates to:
  /// **'{name} turned off notifications for WPC CRM'**
  String notifNotificationsOff(String name);

  /// No description provided for @logNotificationsOff.
  ///
  /// In en, this message translates to:
  /// **'Notifications turned off'**
  String get logNotificationsOff;

  /// No description provided for @logNotificationsOn.
  ///
  /// In en, this message translates to:
  /// **'Notifications turned on'**
  String get logNotificationsOn;

  /// No description provided for @notifBatteryOptimized.
  ///
  /// In en, this message translates to:
  /// **'{name} turned on battery optimization for WPC CRM – tracking may stop'**
  String notifBatteryOptimized(String name);

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @showLocation.
  ///
  /// In en, this message translates to:
  /// **'Show location'**
  String get showLocation;

  /// No description provided for @deleteVisitTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete visit'**
  String get deleteVisitTitle;

  /// No description provided for @deleteVisitBody.
  ///
  /// In en, this message translates to:
  /// **'The visit, its comments, photos and files are deleted for everyone. Plan items it completed become open again. This can\'t be undone.'**
  String get deleteVisitBody;

  /// No description provided for @visitDeleted.
  ///
  /// In en, this message translates to:
  /// **'Visit deleted'**
  String get visitDeleted;

  /// No description provided for @colourBy.
  ///
  /// In en, this message translates to:
  /// **'Colour by'**
  String get colourBy;

  /// No description provided for @salesperson.
  ///
  /// In en, this message translates to:
  /// **'Salesperson'**
  String get salesperson;

  /// No description provided for @notifPlanItemsAdded.
  ///
  /// In en, this message translates to:
  /// **'{name} added {count} item(s) to your plan for {day}'**
  String notifPlanItemsAdded(String name, int count, String day);

  /// No description provided for @notifTrackingOffline.
  ///
  /// In en, this message translates to:
  /// **'{name} has been offline for over 30 minutes during work hours'**
  String notifTrackingOffline(String name);

  /// No description provided for @trackingLog.
  ///
  /// In en, this message translates to:
  /// **'Tracking log'**
  String get trackingLog;

  /// No description provided for @trackingLogEmpty.
  ///
  /// In en, this message translates to:
  /// **'No changes recorded for this day'**
  String get trackingLogEmpty;

  /// No description provided for @logOffline.
  ///
  /// In en, this message translates to:
  /// **'Lost connection'**
  String get logOffline;

  /// No description provided for @logQuiet.
  ///
  /// In en, this message translates to:
  /// **'Phone stopped sending'**
  String get logQuiet;

  /// No description provided for @logWoken.
  ///
  /// In en, this message translates to:
  /// **'Woken by the wake-up check – sending again'**
  String get logWoken;

  /// No description provided for @logResumed.
  ///
  /// In en, this message translates to:
  /// **'Sending again'**
  String get logResumed;

  /// No description provided for @logNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'No answer to the wake-up check – managers told'**
  String get logNoAnswer;

  /// No description provided for @notifPhoneNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s phone has sent nothing since {time} ({minutes} min) and didn\'t answer a wake-up check – the app may be closed, or the phone off or without signal'**
  String notifPhoneNoAnswer(String name, String time, int minutes);

  /// No description provided for @logOnline.
  ///
  /// In en, this message translates to:
  /// **'Back online'**
  String get logOnline;

  /// No description provided for @logGpsOff.
  ///
  /// In en, this message translates to:
  /// **'GPS turned off'**
  String get logGpsOff;

  /// No description provided for @logGpsOn.
  ///
  /// In en, this message translates to:
  /// **'GPS turned on'**
  String get logGpsOn;

  /// No description provided for @logOnDuty.
  ///
  /// In en, this message translates to:
  /// **'Work hours started'**
  String get logOnDuty;

  /// No description provided for @logOffDuty.
  ///
  /// In en, this message translates to:
  /// **'Work hours ended'**
  String get logOffDuty;

  /// No description provided for @logBatteryOn.
  ///
  /// In en, this message translates to:
  /// **'Battery optimization turned on'**
  String get logBatteryOn;

  /// No description provided for @logBatteryOff.
  ///
  /// In en, this message translates to:
  /// **'Battery optimization turned off'**
  String get logBatteryOff;

  /// No description provided for @logPermission.
  ///
  /// In en, this message translates to:
  /// **'Location permission: {value}'**
  String logPermission(String value);

  /// No description provided for @permissionAlways.
  ///
  /// In en, this message translates to:
  /// **'Allow all the time'**
  String get permissionAlways;

  /// No description provided for @permissionWhileInUse.
  ///
  /// In en, this message translates to:
  /// **'Only while using the app'**
  String get permissionWhileInUse;

  /// No description provided for @permissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Denied'**
  String get permissionDenied;

  /// No description provided for @logLasted.
  ///
  /// In en, this message translates to:
  /// **'for {duration}'**
  String logLasted(String duration);

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{m} min'**
  String durationMinutes(int m);

  /// No description provided for @durationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{h} h {m} min'**
  String durationHoursMinutes(int h, int m);

  /// No description provided for @addTask.
  ///
  /// In en, this message translates to:
  /// **'Add task'**
  String get addTask;

  /// No description provided for @commentOptional.
  ///
  /// In en, this message translates to:
  /// **'Comment (optional)'**
  String get commentOptional;

  /// No description provided for @markDone.
  ///
  /// In en, this message translates to:
  /// **'Mark done'**
  String get markDone;

  /// No description provided for @markNotDone.
  ///
  /// In en, this message translates to:
  /// **'Not done'**
  String get markNotDone;

  /// No description provided for @visitTasksLabel.
  ///
  /// In en, this message translates to:
  /// **'Tasks at the client'**
  String get visitTasksLabel;

  /// No description provided for @checklistProgress.
  ///
  /// In en, this message translates to:
  /// **'{done}/{total} tasks'**
  String checklistProgress(int done, int total);

  /// No description provided for @possibleDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Possible duplicates'**
  String get possibleDuplicates;

  /// No description provided for @dupSameVat.
  ///
  /// In en, this message translates to:
  /// **'Same Tax ID'**
  String get dupSameVat;

  /// No description provided for @dupSameName.
  ///
  /// In en, this message translates to:
  /// **'Same name'**
  String get dupSameName;

  /// No description provided for @dupSamePhone.
  ///
  /// In en, this message translates to:
  /// **'Same phone'**
  String get dupSamePhone;

  /// No description provided for @dupSimilarName.
  ///
  /// In en, this message translates to:
  /// **'Similar name'**
  String get dupSimilarName;

  /// No description provided for @dupNearby.
  ///
  /// In en, this message translates to:
  /// **'Same place'**
  String get dupNearby;

  /// No description provided for @noDuplicates.
  ///
  /// In en, this message translates to:
  /// **'No possible duplicates'**
  String get noDuplicates;

  /// No description provided for @notDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Not duplicates'**
  String get notDuplicates;

  /// No description provided for @markedNotDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Marked as different clients'**
  String get markedNotDuplicates;

  /// No description provided for @mergeClients.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get mergeClients;

  /// No description provided for @mergeClientsTitle.
  ///
  /// In en, this message translates to:
  /// **'Merge clients'**
  String get mergeClientsTitle;

  /// No description provided for @mergeHint.
  ///
  /// In en, this message translates to:
  /// **'Choose the client to keep. The others are deleted: their visits, plan items, files, contacts and names move to the kept client, and its empty details are filled from them. The kept client\'s name, category and salesperson stay. This can\'t be undone.'**
  String get mergeHint;

  /// No description provided for @mergeKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep this client'**
  String get mergeKeep;

  /// No description provided for @mergeCount.
  ///
  /// In en, this message translates to:
  /// **'Merge {count}'**
  String mergeCount(int count);

  /// No description provided for @clientsMerged.
  ///
  /// In en, this message translates to:
  /// **'{count} clients merged into one'**
  String clientsMerged(int count);

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @personalInfo.
  ///
  /// In en, this message translates to:
  /// **'Personal info'**
  String get personalInfo;

  /// No description provided for @emailChangeByAdmin.
  ///
  /// In en, this message translates to:
  /// **'To change your email or role, ask a sales manager.'**
  String get emailChangeByAdmin;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmNewPassword;

  /// No description provided for @passwordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get passwordsDontMatch;

  /// No description provided for @wrongCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password is wrong'**
  String get wrongCurrentPassword;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get passwordChanged;

  /// No description provided for @resetPasswordByEmail.
  ///
  /// In en, this message translates to:
  /// **'Reset password by email'**
  String get resetPasswordByEmail;

  /// No description provided for @resetPasswordInfo.
  ///
  /// In en, this message translates to:
  /// **'Forgot your current password? We\'ll email you a link to set a new one.'**
  String get resetPasswordInfo;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send link'**
  String get sendResetLink;

  /// No description provided for @resetEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Reset link sent to {email}'**
  String resetEmailSent(String email);

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @resetEmailSentIfExists.
  ///
  /// In en, this message translates to:
  /// **'If this email has an account, a reset link was sent to it.'**
  String get resetEmailSentIfExists;

  /// No description provided for @tooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again later.'**
  String get tooManyAttempts;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateRequiredTitle;

  /// No description provided for @updateRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'A new version of WPC CRM is available. Please update the app to continue.'**
  String get updateRequiredBody;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get updateNow;

  /// No description provided for @exportClients.
  ///
  /// In en, this message translates to:
  /// **'Export to Excel'**
  String get exportClients;

  /// No description provided for @exportClientsTitle.
  ///
  /// In en, this message translates to:
  /// **'Export clients to Excel'**
  String get exportClientsTitle;

  /// No description provided for @exportClientsBody.
  ///
  /// In en, this message translates to:
  /// **'{count} clients (the current list with its search and filters). Choose the columns:'**
  String exportClientsBody(int count);

  /// No description provided for @exportColumnsCount.
  ///
  /// In en, this message translates to:
  /// **'{selected} of {total} columns'**
  String exportColumnsCount(int selected, int total);

  /// No description provided for @exportSelectNone.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get exportSelectNone;

  /// No description provided for @exportButton.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportButton;

  /// No description provided for @exportLegalName.
  ///
  /// In en, this message translates to:
  /// **'Legal name'**
  String get exportLegalName;

  /// No description provided for @exportVisitStatus.
  ///
  /// In en, this message translates to:
  /// **'Visit status'**
  String get exportVisitStatus;

  /// No description provided for @exportDaysSinceVisit.
  ///
  /// In en, this message translates to:
  /// **'Days since last visit'**
  String get exportDaysSinceVisit;

  /// No description provided for @exportOtherContacts.
  ///
  /// In en, this message translates to:
  /// **'Other contacts'**
  String get exportOtherContacts;

  /// No description provided for @exportMapsLink.
  ///
  /// In en, this message translates to:
  /// **'Google Maps link'**
  String get exportMapsLink;

  /// No description provided for @exportGooglePin.
  ///
  /// In en, this message translates to:
  /// **'Odoo Google Pin'**
  String get exportGooglePin;

  /// No description provided for @exportOdooTags.
  ///
  /// In en, this message translates to:
  /// **'Odoo tags'**
  String get exportOdooTags;

  /// No description provided for @exportCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get exportCurrency;

  /// No description provided for @exportSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get exportSource;

  /// No description provided for @exportSourceImport.
  ///
  /// In en, this message translates to:
  /// **'Odoo import'**
  String get exportSourceImport;

  /// No description provided for @exportHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get exportHidden;

  /// No description provided for @exportAddedOn.
  ///
  /// In en, this message translates to:
  /// **'Added on'**
  String get exportAddedOn;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @calls.
  ///
  /// In en, this message translates to:
  /// **'Calls'**
  String get calls;

  /// No description provided for @logCall.
  ///
  /// In en, this message translates to:
  /// **'Log call'**
  String get logCall;

  /// No description provided for @saveCall.
  ///
  /// In en, this message translates to:
  /// **'Save call'**
  String get saveCall;

  /// No description provided for @callSaved.
  ///
  /// In en, this message translates to:
  /// **'Call saved'**
  String get callSaved;

  /// No description provided for @callNotes.
  ///
  /// In en, this message translates to:
  /// **'What was discussed on the call'**
  String get callNotes;

  /// No description provided for @callNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Orders, follow-ups, next visit…'**
  String get callNotesHint;

  /// No description provided for @callNotesRequired.
  ///
  /// In en, this message translates to:
  /// **'Write what was discussed on the call'**
  String get callNotesRequired;

  /// No description provided for @callFromApp.
  ///
  /// In en, this message translates to:
  /// **'Called from the app'**
  String get callFromApp;

  /// No description provided for @callLoggedByHand.
  ///
  /// In en, this message translates to:
  /// **'Logged by hand'**
  String get callLoggedByHand;

  /// No description provided for @callDuration.
  ///
  /// In en, this message translates to:
  /// **'About {duration} away from the app'**
  String callDuration(String duration);

  /// No description provided for @notThisCall.
  ///
  /// In en, this message translates to:
  /// **'Not this call'**
  String get notThisCall;

  /// No description provided for @logThisCall.
  ///
  /// In en, this message translates to:
  /// **'Back from a call ({duration}). Log it?'**
  String logThisCall(String duration);

  /// No description provided for @calledBy.
  ///
  /// In en, this message translates to:
  /// **'Call by {name}'**
  String calledBy(String name);

  /// No description provided for @visitsAndCalls.
  ///
  /// In en, this message translates to:
  /// **'Visits and calls'**
  String get visitsAndCalls;

  /// No description provided for @visitsPlusCalls.
  ///
  /// In en, this message translates to:
  /// **'Visits + calls'**
  String get visitsPlusCalls;

  /// No description provided for @visitsAndCallsDetail.
  ///
  /// In en, this message translates to:
  /// **'{visits} visits + {calls} calls'**
  String visitsAndCallsDetail(int visits, int calls);

  /// No description provided for @barTooltipCalls.
  ///
  /// In en, this message translates to:
  /// **'{name}: {done} visits + {calls} calls · target {target} · expected by today {expected}'**
  String barTooltipCalls(
    String name,
    int done,
    int calls,
    int target,
    int expected,
  );

  /// No description provided for @roleHr.
  ///
  /// In en, this message translates to:
  /// **'HR'**
  String get roleHr;

  /// No description provided for @roleAccounting.
  ///
  /// In en, this message translates to:
  /// **'Accounting'**
  String get roleAccounting;

  /// No description provided for @roleProcurement.
  ///
  /// In en, this message translates to:
  /// **'Procurement'**
  String get roleProcurement;

  /// No description provided for @roleUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown role'**
  String get roleUnknown;

  /// No description provided for @updateAppForRole.
  ///
  /// In en, this message translates to:
  /// **'Your account uses a role this version of the app doesn\'t know yet. Please update the app (Google Play / TestFlight) or reload the web page.'**
  String get updateAppForRole;

  /// No description provided for @backOfficeHomeBody.
  ///
  /// In en, this message translates to:
  /// **'Your attendance and leave requests will appear here.'**
  String get backOfficeHomeBody;

  /// No description provided for @hrArea.
  ///
  /// In en, this message translates to:
  /// **'HR'**
  String get hrArea;

  /// No description provided for @myLeave.
  ///
  /// In en, this message translates to:
  /// **'My leave'**
  String get myLeave;

  /// No description provided for @myLeaveHint.
  ///
  /// In en, this message translates to:
  /// **'Balances and requests'**
  String get myLeaveHint;

  /// No description provided for @myRequests.
  ///
  /// In en, this message translates to:
  /// **'My requests'**
  String get myRequests;

  /// No description provided for @newLeaveRequest.
  ///
  /// In en, this message translates to:
  /// **'New request'**
  String get newLeaveRequest;

  /// No description provided for @noLeaveRequests.
  ///
  /// In en, this message translates to:
  /// **'No requests'**
  String get noLeaveRequests;

  /// No description provided for @leaveRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get leaveRequests;

  /// No description provided for @leaveBalances.
  ///
  /// In en, this message translates to:
  /// **'Balances'**
  String get leaveBalances;

  /// No description provided for @leaveTypesAndHolidays.
  ///
  /// In en, this message translates to:
  /// **'Leave types & holidays'**
  String get leaveTypesAndHolidays;

  /// No description provided for @leaveBalanceYear.
  ///
  /// In en, this message translates to:
  /// **'Leave balance {year}'**
  String leaveBalanceYear(int year);

  /// No description provided for @leavePendingDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days waiting for approval'**
  String leavePendingDays(String days);

  /// No description provided for @leaveRemainingOf.
  ///
  /// In en, this message translates to:
  /// **'{left} of {total} left'**
  String leaveRemainingOf(String left, String total);

  /// No description provided for @leaveDaysCount.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String leaveDaysCount(String days);

  /// No description provided for @leaveLeftAfter.
  ///
  /// In en, this message translates to:
  /// **'{days} left after this'**
  String leaveLeftAfter(String days);

  /// No description provided for @leaveOverBalance.
  ///
  /// In en, this message translates to:
  /// **'This is more than the days left. HR decides whether it is allowed.'**
  String get leaveOverBalance;

  /// No description provided for @waitingFor.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {who}'**
  String waitingFor(String who);

  /// No description provided for @waitingForMe.
  ///
  /// In en, this message translates to:
  /// **'Waiting for me'**
  String get waitingForMe;

  /// No description provided for @pendingStatus.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pendingStatus;

  /// No description provided for @leaveApprovedStatus.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get leaveApprovedStatus;

  /// No description provided for @leaveCancelledStatus.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get leaveCancelledStatus;

  /// No description provided for @leaveWaitingForYou.
  ///
  /// In en, this message translates to:
  /// **'Requests waiting for your approval ({count})'**
  String leaveWaitingForYou(int count);

  /// No description provided for @requestType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get requestType;

  /// No description provided for @pickLeaveDates.
  ///
  /// In en, this message translates to:
  /// **'Choose the dates'**
  String get pickLeaveDates;

  /// No description provided for @halfDay.
  ///
  /// In en, this message translates to:
  /// **'Half day'**
  String get halfDay;

  /// No description provided for @countsCalendarDays.
  ///
  /// In en, this message translates to:
  /// **'Counts every calendar day'**
  String get countsCalendarDays;

  /// No description provided for @countsWorkDays.
  ///
  /// In en, this message translates to:
  /// **'Counts work days only'**
  String get countsWorkDays;

  /// No description provided for @leaveReasonOptional.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get leaveReasonOptional;

  /// No description provided for @leaveRequestDetails.
  ///
  /// In en, this message translates to:
  /// **'What do you need?'**
  String get leaveRequestDetails;

  /// No description provided for @leaveReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Write what you need'**
  String get leaveReasonRequired;

  /// No description provided for @leaveDocumentRequired.
  ///
  /// In en, this message translates to:
  /// **'Required: {document}'**
  String leaveDocumentRequired(String document);

  /// No description provided for @approvalOrder.
  ///
  /// In en, this message translates to:
  /// **'Approval order'**
  String get approvalOrder;

  /// No description provided for @noApproverYet.
  ///
  /// In en, this message translates to:
  /// **'Nobody can approve this request yet. Ask the GM to add an HR user.'**
  String get noApproverYet;

  /// No description provided for @leaveAcrossYears.
  ///
  /// In en, this message translates to:
  /// **'A request can\'t cross the new year. Send one request per year.'**
  String get leaveAcrossYears;

  /// No description provided for @leaveNoWorkDays.
  ///
  /// In en, this message translates to:
  /// **'These dates have no work days.'**
  String get leaveNoWorkDays;

  /// No description provided for @sendRequest.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get sendRequest;

  /// No description provided for @leaveRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get leaveRequestSent;

  /// No description provided for @approveRequest.
  ///
  /// In en, this message translates to:
  /// **'Approve request'**
  String get approveRequest;

  /// No description provided for @rejectRequest.
  ///
  /// In en, this message translates to:
  /// **'Reject request'**
  String get rejectRequest;

  /// No description provided for @rejectReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get rejectReason;

  /// No description provided for @cancelRequest.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get cancelRequest;

  /// No description provided for @leaveAlreadyDecided.
  ///
  /// In en, this message translates to:
  /// **'Someone already decided this step.'**
  String get leaveAlreadyDecided;

  /// No description provided for @leaveTypesHint.
  ///
  /// In en, this message translates to:
  /// **'Starting values follow Saudi labour law – HR should check them. Tap a type to edit it.'**
  String get leaveTypesHint;

  /// No description provided for @noYearlyLimit.
  ///
  /// In en, this message translates to:
  /// **'No yearly limit'**
  String get noYearlyLimit;

  /// No description provided for @daysPerYear.
  ///
  /// In en, this message translates to:
  /// **'{days} days a year'**
  String daysPerYear(int days);

  /// No description provided for @unpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get unpaid;

  /// No description provided for @otherRequest.
  ///
  /// In en, this message translates to:
  /// **'Request (no days)'**
  String get otherRequest;

  /// No description provided for @needsDocumentNamed.
  ///
  /// In en, this message translates to:
  /// **'Needs: {document}'**
  String needsDocumentNamed(String document);

  /// No description provided for @addLeaveType.
  ///
  /// In en, this message translates to:
  /// **'Add type'**
  String get addLeaveType;

  /// No description provided for @editLeaveType.
  ///
  /// In en, this message translates to:
  /// **'Edit type'**
  String get editLeaveType;

  /// No description provided for @nameEnglish.
  ///
  /// In en, this message translates to:
  /// **'Name (English)'**
  String get nameEnglish;

  /// No description provided for @nameArabic.
  ///
  /// In en, this message translates to:
  /// **'Name (Arabic)'**
  String get nameArabic;

  /// No description provided for @isLeaveType.
  ///
  /// In en, this message translates to:
  /// **'Leave (has dates)'**
  String get isLeaveType;

  /// No description provided for @isLeaveTypeHint.
  ///
  /// In en, this message translates to:
  /// **'Off for requests like a salary certificate'**
  String get isLeaveTypeHint;

  /// No description provided for @daysPerYearLabel.
  ///
  /// In en, this message translates to:
  /// **'Days per year'**
  String get daysPerYearLabel;

  /// No description provided for @daysPerYearHelper.
  ///
  /// In en, this message translates to:
  /// **'Empty = no limit'**
  String get daysPerYearHelper;

  /// No description provided for @paidLeave.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paidLeave;

  /// No description provided for @needsDocument.
  ///
  /// In en, this message translates to:
  /// **'Needs a document'**
  String get needsDocument;

  /// No description provided for @documentNameEnglish.
  ///
  /// In en, this message translates to:
  /// **'Document (English)'**
  String get documentNameEnglish;

  /// No description provided for @documentNameArabic.
  ///
  /// In en, this message translates to:
  /// **'Document (Arabic)'**
  String get documentNameArabic;

  /// No description provided for @publicHolidays.
  ///
  /// In en, this message translates to:
  /// **'Public holidays'**
  String get publicHolidays;

  /// No description provided for @publicHolidaysHint.
  ///
  /// In en, this message translates to:
  /// **'These days don\'t count as leave days.'**
  String get publicHolidaysHint;

  /// No description provided for @addHoliday.
  ///
  /// In en, this message translates to:
  /// **'Add holiday'**
  String get addHoliday;

  /// No description provided for @tapTypeToEdit.
  ///
  /// In en, this message translates to:
  /// **'Tap a type to set this person\'s days or add an adjustment.'**
  String get tapTypeToEdit;

  /// No description provided for @daysThisYear.
  ///
  /// In en, this message translates to:
  /// **'Days this year for this person'**
  String get daysThisYear;

  /// No description provided for @daysThisYearHelper.
  ///
  /// In en, this message translates to:
  /// **'Empty = the type\'s {days} days'**
  String daysThisYearHelper(int days);

  /// No description provided for @adjustDays.
  ///
  /// In en, this message translates to:
  /// **'Add or remove days'**
  String get adjustDays;

  /// No description provided for @adjustDaysHelper.
  ///
  /// In en, this message translates to:
  /// **'e.g. 5 carried over, or -2'**
  String get adjustDaysHelper;

  /// No description provided for @adjustNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get adjustNote;

  /// No description provided for @adjustments.
  ///
  /// In en, this message translates to:
  /// **'Adjustments'**
  String get adjustments;

  /// No description provided for @notifLeaveRequested.
  ///
  /// In en, this message translates to:
  /// **'Request from {owner} – waiting for your approval'**
  String notifLeaveRequested(String owner);

  /// No description provided for @notifLeaveApproved.
  ///
  /// In en, this message translates to:
  /// **'{name} approved your request'**
  String notifLeaveApproved(String name);

  /// No description provided for @notifLeaveStepApproved.
  ///
  /// In en, this message translates to:
  /// **'{name} approved your request – now waiting for the final approval'**
  String notifLeaveStepApproved(String name);

  /// No description provided for @notifLeaveReminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder: {owner}\'s request has been waiting {days, plural, =1{1 day} other{{days} days}} for your approval'**
  String notifLeaveReminder(String owner, int days);

  /// No description provided for @notifLeaveUpdateSent.
  ///
  /// In en, this message translates to:
  /// **'{owner} sent a leave request – for your information'**
  String notifLeaveUpdateSent(String owner);

  /// No description provided for @notifLeaveUpdateStepApproved.
  ///
  /// In en, this message translates to:
  /// **'{name} approved {owner}\'s request – now waiting for the final approval'**
  String notifLeaveUpdateStepApproved(String name, String owner);

  /// No description provided for @notifLeaveUpdateApproved.
  ///
  /// In en, this message translates to:
  /// **'{name} gave the final approval to {owner}\'s request'**
  String notifLeaveUpdateApproved(String name, String owner);

  /// No description provided for @notifLeaveUpdateRejected.
  ///
  /// In en, this message translates to:
  /// **'{name} rejected {owner}\'s request'**
  String notifLeaveUpdateRejected(String name, String owner);

  /// No description provided for @notifLeaveUpdateCancelled.
  ///
  /// In en, this message translates to:
  /// **'{owner} cancelled their request'**
  String notifLeaveUpdateCancelled(String owner);

  /// No description provided for @notifLeaveRejected.
  ///
  /// In en, this message translates to:
  /// **'{name} rejected your request'**
  String notifLeaveRejected(String name);

  /// No description provided for @addLocation.
  ///
  /// In en, this message translates to:
  /// **'Add location'**
  String get addLocation;

  /// No description provided for @editLocation.
  ///
  /// In en, this message translates to:
  /// **'Edit location'**
  String get editLocation;

  /// No description provided for @locationType.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get locationType;

  /// No description provided for @noLocationType.
  ///
  /// In en, this message translates to:
  /// **'No label'**
  String get noLocationType;

  /// No description provided for @mainLocationType.
  ///
  /// In en, this message translates to:
  /// **'Main location label'**
  String get mainLocationType;

  /// No description provided for @moreLocationsOnClientPage.
  ///
  /// In en, this message translates to:
  /// **'Add more locations (factory, showroom, …) on the client page'**
  String get moreLocationsOnClientPage;

  /// No description provided for @mainLocation.
  ///
  /// In en, this message translates to:
  /// **'Main'**
  String get mainLocation;

  /// No description provided for @makeMainLocation.
  ///
  /// In en, this message translates to:
  /// **'Make main location'**
  String get makeMainLocation;

  /// No description provided for @locationNumber.
  ///
  /// In en, this message translates to:
  /// **'Location {n}'**
  String locationNumber(int n);

  /// No description provided for @deleteLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteLocationTitle(String name);

  /// No description provided for @visitLocation.
  ///
  /// In en, this message translates to:
  /// **'Visit location'**
  String get visitLocation;

  /// No description provided for @nearestLocation.
  ///
  /// In en, this message translates to:
  /// **'nearest'**
  String get nearestLocation;

  /// No description provided for @locationTypes.
  ///
  /// In en, this message translates to:
  /// **'Location types'**
  String get locationTypes;

  /// No description provided for @locationTypesHelp.
  ///
  /// In en, this message translates to:
  /// **'Labels for a client\'s locations, e.g. Office, Factory, Showroom. Deleting one leaves those locations unlabelled.'**
  String get locationTypesHelp;

  /// No description provided for @otherLocations.
  ///
  /// In en, this message translates to:
  /// **'Other locations'**
  String get otherLocations;

  /// No description provided for @saveClientFirstForLocations.
  ///
  /// In en, this message translates to:
  /// **'Save the client first, then add more locations here.'**
  String get saveClientFirstForLocations;

  /// No description provided for @setMainLocationFirst.
  ///
  /// In en, this message translates to:
  /// **'Set and save the main location first, then add more locations.'**
  String get setMainLocationFirst;

  /// No description provided for @visitsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 visit} other{{count} visits}}'**
  String visitsCount(int count);

  /// No description provided for @callsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 call} other{{count} calls}}'**
  String callsCount(int count);

  /// No description provided for @deleteClient.
  ///
  /// In en, this message translates to:
  /// **'Delete client'**
  String get deleteClient;

  /// No description provided for @deleteClientTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deleteClientTitle(String name);

  /// No description provided for @deleteClientBody.
  ///
  /// In en, this message translates to:
  /// **'The client, its plan items and its photos / files will be deleted. This can\'t be undone.'**
  String get deleteClientBody;

  /// No description provided for @deleteClientWithVisits.
  ///
  /// In en, this message translates to:
  /// **'This client has {count} visits. The visits stay in the visits list and reports; the client, its plan items and its photos / files are deleted. This can\'t be undone.\n\nEnter your password to confirm.'**
  String deleteClientWithVisits(int count);

  /// No description provided for @yourPassword.
  ///
  /// In en, this message translates to:
  /// **'Your password'**
  String get yourPassword;

  /// No description provided for @wrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong password'**
  String get wrongPassword;

  /// No description provided for @clientDeleted.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted'**
  String clientDeleted(String name);

  /// No description provided for @documents.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents;

  /// No description provided for @docCr.
  ///
  /// In en, this message translates to:
  /// **'Commercial Registration (CR)'**
  String get docCr;

  /// No description provided for @docVat.
  ///
  /// In en, this message translates to:
  /// **'VAT certificate'**
  String get docVat;

  /// No description provided for @docNationalAddress.
  ///
  /// In en, this message translates to:
  /// **'National Address'**
  String get docNationalAddress;

  /// No description provided for @docsHelp.
  ///
  /// In en, this message translates to:
  /// **'Upload the PDF from the portal (best) or a clear photo. The app reads the numbers and the address and offers to fill the fields.'**
  String get docsHelp;

  /// No description provided for @docNotAdded.
  ///
  /// In en, this message translates to:
  /// **'Not added'**
  String get docNotAdded;

  /// No description provided for @docWillUpload.
  ///
  /// In en, this message translates to:
  /// **'{name} – uploaded when you save'**
  String docWillUpload(String name);

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @replace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replace;

  /// No description provided for @docUnreadable.
  ///
  /// In en, this message translates to:
  /// **'The document was attached, but no text could be read from it. Fill the fields by hand.'**
  String get docUnreadable;

  /// No description provided for @docPhotoOnWeb.
  ///
  /// In en, this message translates to:
  /// **'The document was attached. Photos are read only in the phone app; on the web upload the PDF to fill the fields.'**
  String get docPhotoOnWeb;

  /// No description provided for @docNothingFound.
  ///
  /// In en, this message translates to:
  /// **'The document was attached, but no CR / VAT number or address was found in it.'**
  String get docNothingFound;

  /// No description provided for @docFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Found in the {document}'**
  String docFoundTitle(String document);

  /// No description provided for @docFoundHelp.
  ///
  /// In en, this message translates to:
  /// **'Check the values before filling them in. Ticked fields replace what is in the form.'**
  String get docFoundHelp;

  /// No description provided for @docCurrentValue.
  ///
  /// In en, this message translates to:
  /// **'Now: {value}'**
  String docCurrentValue(String value);

  /// No description provided for @docFill.
  ///
  /// In en, this message translates to:
  /// **'Fill in'**
  String get docFill;

  /// No description provided for @clientStatus.
  ///
  /// In en, this message translates to:
  /// **'Client status'**
  String get clientStatus;

  /// No description provided for @clientStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get clientStatusActive;

  /// No description provided for @clientStatusClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get clientStatusClosed;

  /// No description provided for @clientStatusNotWorking.
  ///
  /// In en, this message translates to:
  /// **'Not working'**
  String get clientStatusNotWorking;

  /// No description provided for @changeClientStatus.
  ///
  /// In en, this message translates to:
  /// **'Change client status'**
  String get changeClientStatus;

  /// No description provided for @clientStatusReason.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get clientStatusReason;

  /// No description provided for @clientStatusNeedsApproval.
  ///
  /// In en, this message translates to:
  /// **'Your KAM, the sales manager or the GM will approve the change.'**
  String get clientStatusNeedsApproval;

  /// No description provided for @sendForApproval.
  ///
  /// In en, this message translates to:
  /// **'Send for approval'**
  String get sendForApproval;

  /// No description provided for @clientStatusChanged.
  ///
  /// In en, this message translates to:
  /// **'Client status changed'**
  String get clientStatusChanged;

  /// No description provided for @clientStatusRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Sent for approval'**
  String get clientStatusRequestSent;

  /// No description provided for @clientStatusRequestCancelled.
  ///
  /// In en, this message translates to:
  /// **'Request cancelled'**
  String get clientStatusRequestCancelled;

  /// No description provided for @clientStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get clientStatusApproved;

  /// No description provided for @clientStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get clientStatusRejected;

  /// No description provided for @clientStatusSince.
  ///
  /// In en, this message translates to:
  /// **'{status} since {date}'**
  String clientStatusSince(String status, String date);

  /// No description provided for @clientStatusWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval: {status}'**
  String clientStatusWaiting(String status);

  /// No description provided for @clientStatusAsked.
  ///
  /// In en, this message translates to:
  /// **'{name} asked to mark this client as {status}'**
  String clientStatusAsked(String name, String status);

  /// No description provided for @clientStatusRejectedEntry.
  ///
  /// In en, this message translates to:
  /// **'{status} – rejected'**
  String clientStatusRejectedEntry(String status);

  /// No description provided for @clientStatusRequestedBy.
  ///
  /// In en, this message translates to:
  /// **'asked by {name}'**
  String clientStatusRequestedBy(String name);

  /// No description provided for @clientStatusDecidedBy.
  ///
  /// In en, this message translates to:
  /// **'by {name}'**
  String clientStatusDecidedBy(String name);

  /// No description provided for @clientStatusHistory.
  ///
  /// In en, this message translates to:
  /// **'Status history'**
  String get clientStatusHistory;

  /// No description provided for @clientStatusRequests.
  ///
  /// In en, this message translates to:
  /// **'Status requests'**
  String get clientStatusRequests;

  /// No description provided for @clientStatusFilterHelp.
  ///
  /// In en, this message translates to:
  /// **'Closed and not working clients show only when ticked here.'**
  String get clientStatusFilterHelp;

  /// No description provided for @notifClientStatusRequested.
  ///
  /// In en, this message translates to:
  /// **'{name} asked to mark {client} as {status} – waiting for your approval'**
  String notifClientStatusRequested(String name, String client, String status);

  /// No description provided for @notifClientStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'{name} approved: {client} is now {status}'**
  String notifClientStatusApproved(String name, String client, String status);

  /// No description provided for @notifClientStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'{name} rejected marking {client} as {status}'**
  String notifClientStatusRejected(String name, String client, String status);

  /// No description provided for @transferredClients.
  ///
  /// In en, this message translates to:
  /// **'Transferred clients'**
  String get transferredClients;

  /// No description provided for @transfersHelp.
  ///
  /// In en, this message translates to:
  /// **'Clients moved from one salesperson to another, and whether the new salesperson has visited or called them since.'**
  String get transfersHelp;

  /// No description provided for @lastNDays.
  ///
  /// In en, this message translates to:
  /// **'Last {n} days'**
  String lastNDays(int n);

  /// No description provided for @transfersNotVisitedOnly.
  ///
  /// In en, this message translates to:
  /// **'Not visited yet'**
  String get transfersNotVisitedOnly;

  /// No description provided for @transfersSummary.
  ///
  /// In en, this message translates to:
  /// **'{total} moved · {visited} visited · {waiting} not yet'**
  String transfersSummary(int total, int visited, int waiting);

  /// No description provided for @transfersNone.
  ///
  /// In en, this message translates to:
  /// **'No clients were moved in this period.'**
  String get transfersNone;

  /// No description provided for @transferMovedBy.
  ///
  /// In en, this message translates to:
  /// **'Moved by {name} · {date}'**
  String transferMovedBy(String name, String date);

  /// No description provided for @transferVisitedAfter.
  ///
  /// In en, this message translates to:
  /// **'Visited {date} · {days} days after the move'**
  String transferVisitedAfter(String date, int days);

  /// No description provided for @transferCalledAfter.
  ///
  /// In en, this message translates to:
  /// **'Called {date} · {days} days after the move'**
  String transferCalledAfter(String date, int days);

  /// No description provided for @transferNotVisited.
  ///
  /// In en, this message translates to:
  /// **'Not visited · {days} days since the move'**
  String transferNotVisited(int days);

  /// No description provided for @transferMovedAgain.
  ///
  /// In en, this message translates to:
  /// **'Moved again later'**
  String get transferMovedAgain;

  /// No description provided for @newSalesperson.
  ///
  /// In en, this message translates to:
  /// **'New salesperson'**
  String get newSalesperson;

  /// No description provided for @movedBy.
  ///
  /// In en, this message translates to:
  /// **'Moved by'**
  String get movedBy;

  /// No description provided for @movedByName.
  ///
  /// In en, this message translates to:
  /// **'Moved by: {name}'**
  String movedByName(String name);

  /// No description provided for @motionDriving.
  ///
  /// In en, this message translates to:
  /// **'Driving'**
  String get motionDriving;

  /// No description provided for @motionWalking.
  ///
  /// In en, this message translates to:
  /// **'Walking'**
  String get motionWalking;

  /// No description provided for @motionStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get motionStopped;

  /// No description provided for @motionIdleFor.
  ///
  /// In en, this message translates to:
  /// **'Idle for {time}'**
  String motionIdleFor(String time);

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get appVersion;

  /// No description provided for @newerVersionAvailable.
  ///
  /// In en, this message translates to:
  /// **'A newer version is available'**
  String get newerVersionAvailable;

  /// No description provided for @updateApp.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateApp;

  /// No description provided for @latestAppVersion.
  ///
  /// In en, this message translates to:
  /// **'Latest version: {version}'**
  String latestAppVersion(String version);

  /// No description provided for @everyoneUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Everyone\'s phone is on the latest version'**
  String get everyoneUpToDate;

  /// No description provided for @peopleOnOlderVersion.
  ///
  /// In en, this message translates to:
  /// **'{n} people on an older version'**
  String peopleOnOlderVersion(int n);

  /// No description provided for @remindAll.
  ///
  /// In en, this message translates to:
  /// **'Remind ({n})'**
  String remindAll(int n);

  /// No description provided for @remindToUpdate.
  ///
  /// In en, this message translates to:
  /// **'Remind to update'**
  String get remindToUpdate;

  /// No description provided for @remindedWait.
  ///
  /// In en, this message translates to:
  /// **'Reminded – wait {seconds} s'**
  String remindedWait(int seconds);

  /// No description provided for @noAppVersion.
  ///
  /// In en, this message translates to:
  /// **'App version not reported yet'**
  String get noAppVersion;

  /// No description provided for @updateRemindersSent.
  ///
  /// In en, this message translates to:
  /// **'Reminder sent to {n}'**
  String updateRemindersSent(int n);

  /// No description provided for @notifUpdateReminder.
  ///
  /// In en, this message translates to:
  /// **'{name} asks you to update WPC CRM to the latest version – tap to update'**
  String notifUpdateReminder(String name);

  /// No description provided for @linkedClients.
  ///
  /// In en, this message translates to:
  /// **'Linked clients'**
  String get linkedClients;

  /// No description provided for @mainCompany.
  ///
  /// In en, this message translates to:
  /// **'Main company'**
  String get mainCompany;

  /// No description provided for @branch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get branch;

  /// No description provided for @linkToMainCompany.
  ///
  /// In en, this message translates to:
  /// **'Link to a main company'**
  String get linkToMainCompany;

  /// No description provided for @addBranch.
  ///
  /// In en, this message translates to:
  /// **'Add branch'**
  String get addBranch;

  /// No description provided for @unlinkClient.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get unlinkClient;

  /// No description provided for @moveBranchConfirm.
  ///
  /// In en, this message translates to:
  /// **'{branch} is a branch of {from}. Move it under {to}?'**
  String moveBranchConfirm(String branch, String from, String to);

  /// No description provided for @noLinkedClients.
  ///
  /// In en, this message translates to:
  /// **'No linked clients. Link a branch from the client page.'**
  String get noLinkedClients;

  /// No description provided for @branchCount.
  ///
  /// In en, this message translates to:
  /// **'{n} branches'**
  String branchCount(int n);

  /// No description provided for @addCompany.
  ///
  /// In en, this message translates to:
  /// **'Add company'**
  String get addCompany;

  /// No description provided for @addWorkSite.
  ///
  /// In en, this message translates to:
  /// **'Add work site'**
  String get addWorkSite;

  /// No description provided for @allow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get allow;

  /// No description provided for @allowAlwaysForAttendance.
  ///
  /// In en, this message translates to:
  /// **'Allow location \"Always\" so you\'re checked in automatically when you arrive'**
  String get allowAlwaysForAttendance;

  /// No description provided for @atTheSite.
  ///
  /// In en, this message translates to:
  /// **'At the work site'**
  String get atTheSite;

  /// No description provided for @attendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get attendance;

  /// No description provided for @autoCheckInHelp.
  ///
  /// In en, this message translates to:
  /// **'You\'re checked in automatically when you arrive at your work site.'**
  String get autoCheckInHelp;

  /// No description provided for @checkIn.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get checkIn;

  /// No description provided for @checkInAgain.
  ///
  /// In en, this message translates to:
  /// **'Check in again'**
  String get checkInAgain;

  /// No description provided for @checkOut.
  ///
  /// In en, this message translates to:
  /// **'Check out'**
  String get checkOut;

  /// No description provided for @checkOutAuto.
  ///
  /// In en, this message translates to:
  /// **'closed automatically (no exit seen)'**
  String get checkOutAuto;

  /// No description provided for @checkOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Check out now? Your day ends at this time.'**
  String get checkOutConfirm;

  /// No description provided for @checkOutEndOfDay.
  ///
  /// In en, this message translates to:
  /// **'end of the work day'**
  String get checkOutEndOfDay;

  /// No description provided for @checkOutLeft.
  ///
  /// In en, this message translates to:
  /// **'left the site'**
  String get checkOutLeft;

  /// No description provided for @checkOutLeftEarly.
  ///
  /// In en, this message translates to:
  /// **'left early'**
  String get checkOutLeftEarly;

  /// No description provided for @checkOutManual.
  ///
  /// In en, this message translates to:
  /// **'checked out by hand'**
  String get checkOutManual;

  /// No description provided for @companies.
  ///
  /// In en, this message translates to:
  /// **'Companies'**
  String get companies;

  /// No description provided for @company.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get company;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @editWorkSite.
  ///
  /// In en, this message translates to:
  /// **'Edit work site'**
  String get editWorkSite;

  /// No description provided for @noCompanies.
  ///
  /// In en, this message translates to:
  /// **'No companies yet. Add the companies people can choose when they register.'**
  String get noCompanies;

  /// No description provided for @noOneAssignedToSites.
  ///
  /// In en, this message translates to:
  /// **'Nobody is assigned to a work site yet. Assign people at More → Work sites or on their user page.'**
  String get noOneAssignedToSites;

  /// No description provided for @noWorkSiteAssigned.
  ///
  /// In en, this message translates to:
  /// **'You\'re not assigned to a work site.'**
  String get noWorkSiteAssigned;

  /// No description provided for @noWorkSites.
  ///
  /// In en, this message translates to:
  /// **'No work sites yet.'**
  String get noWorkSites;

  /// No description provided for @notCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'Not checked in'**
  String get notCheckedIn;

  /// No description provided for @overtimeAllowed.
  ///
  /// In en, this message translates to:
  /// **'Overtime allowed'**
  String get overtimeAllowed;

  /// No description provided for @overtimeMax.
  ///
  /// In en, this message translates to:
  /// **'Most overtime a day'**
  String get overtimeMax;

  /// No description provided for @overtimeMaxHelp.
  ///
  /// In en, this message translates to:
  /// **'Overtime beyond this isn\'t counted (recorded as time stayed after hours). Standard: 3 hours.'**
  String get overtimeMaxHelp;

  /// No description provided for @hoursCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 hour} other{{n} hours}}'**
  String hoursCount(int n);

  /// No description provided for @notifOvertimeStarted.
  ///
  /// In en, this message translates to:
  /// **'{name} is still at {site} after the end of the shift ({time}) – overtime is counting'**
  String notifOvertimeStarted(String name, String site, String time);

  /// No description provided for @notifOvertimeStartedSelf.
  ///
  /// In en, this message translates to:
  /// **'Your shift ended at {time} and you\'re still at {site} – overtime is counting. Press Check out when you leave.'**
  String notifOvertimeStartedSelf(String site, String time);

  /// No description provided for @overtimeAllowedHelp.
  ///
  /// In en, this message translates to:
  /// **'Overtime counts once it\'s started: site staff are asked 10 min after the end of their work day; drivers still on the road then start it automatically. A manager approves it later.'**
  String get overtimeAllowedHelp;

  /// No description provided for @attendanceRequired.
  ///
  /// In en, this message translates to:
  /// **'Attendance required'**
  String get attendanceRequired;

  /// No description provided for @attendanceRequiredHelp.
  ///
  /// In en, this message translates to:
  /// **'Checks in and out at their work sites. Off: no attendance (usually the sales team).'**
  String get attendanceRequiredHelp;

  /// No description provided for @position.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get position;

  /// No description provided for @positionHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Accountant, Driver, Site engineer'**
  String get positionHint;

  /// No description provided for @radiusHelp.
  ///
  /// In en, this message translates to:
  /// **'How close counts as \"at the site\". Phones need at least 100 m to notice arriving and leaving reliably.'**
  String get radiusHelp;

  /// No description provided for @registerEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'This email already has an account. Sign in, or use \"Forgot password?\".'**
  String get registerEmailInUse;

  /// No description provided for @registerHelp.
  ///
  /// In en, this message translates to:
  /// **'For people without a company account. After you register, the sales manager or GM approves your account.'**
  String get registerHelp;

  /// No description provided for @registrationPendingBanner.
  ///
  /// In en, this message translates to:
  /// **'Registered account – waiting for approval'**
  String get registrationPendingBanner;

  /// No description provided for @registrationPendingHelp.
  ///
  /// In en, this message translates to:
  /// **'Check the details, choose the role, company and work sites, then approve.'**
  String get registrationPendingHelp;

  /// No description provided for @registrationRejected.
  ///
  /// In en, this message translates to:
  /// **'Registration turned down'**
  String get registrationRejected;

  /// No description provided for @registrationRejectedBody.
  ///
  /// In en, this message translates to:
  /// **'Your registration was not approved. Contact your manager if this is a mistake.'**
  String get registrationRejectedBody;

  /// No description provided for @registrationRejectedShort.
  ///
  /// In en, this message translates to:
  /// **'Not approved'**
  String get registrationRejectedShort;

  /// No description provided for @registrationRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Registration not approved'**
  String get registrationRejectedTitle;

  /// No description provided for @renameCompany.
  ///
  /// In en, this message translates to:
  /// **'Rename company'**
  String get renameCompany;

  /// No description provided for @roleDriver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get roleDriver;

  /// No description provided for @roleEngineer.
  ///
  /// In en, this message translates to:
  /// **'Engineer'**
  String get roleEngineer;

  /// No description provided for @roleWorker.
  ///
  /// In en, this message translates to:
  /// **'Worker'**
  String get roleWorker;

  /// No description provided for @waitingForApprovalTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval'**
  String get waitingForApprovalTitle;

  /// No description provided for @workSiteNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Head office, Warehouse'**
  String get workSiteNameHint;

  /// No description provided for @workSiteNeedsNameAndPlace.
  ///
  /// In en, this message translates to:
  /// **'Give the work site a name and pick its place on the map.'**
  String get workSiteNeedsNameAndPlace;

  /// No description provided for @workSiteNoPlace.
  ///
  /// In en, this message translates to:
  /// **'No place picked yet'**
  String get workSiteNoPlace;

  /// No description provided for @workSites.
  ///
  /// In en, this message translates to:
  /// **'Work sites'**
  String get workSites;

  /// No description provided for @attendanceAbsent.
  ///
  /// In en, this message translates to:
  /// **'Not in: {n}'**
  String attendanceAbsent(int n);

  /// No description provided for @attendanceIn.
  ///
  /// In en, this message translates to:
  /// **'In: {n}'**
  String attendanceIn(int n);

  /// No description provided for @attendanceOut.
  ///
  /// In en, this message translates to:
  /// **'Checked out: {n}'**
  String attendanceOut(int n);

  /// No description provided for @checkedInAt.
  ///
  /// In en, this message translates to:
  /// **'Checked in at {site}'**
  String checkedInAt(String site);

  /// No description provided for @checkedInSince.
  ///
  /// In en, this message translates to:
  /// **'Checked in at {time} · {site}'**
  String checkedInSince(String time, String site);

  /// No description provided for @checkedOutAt.
  ///
  /// In en, this message translates to:
  /// **'Checked out at {time}'**
  String checkedOutAt(String time);

  /// No description provided for @deleteWorkSiteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}? People assigned to it are unassigned.'**
  String deleteWorkSiteConfirm(String name);

  /// No description provided for @inSince.
  ///
  /// In en, this message translates to:
  /// **'In since {time}'**
  String inSince(String time);

  /// No description provided for @leftSiteAt.
  ///
  /// In en, this message translates to:
  /// **'Left the site at {time}'**
  String leftSiteAt(String time);

  /// No description provided for @notAtWorkSite.
  ///
  /// In en, this message translates to:
  /// **'You\'re not at your work site ({distance} away).'**
  String notAtWorkSite(String distance);

  /// No description provided for @notifRegistrationRequested.
  ///
  /// In en, this message translates to:
  /// **'{name} registered an account – waiting for your approval'**
  String notifRegistrationRequested(String name);

  /// No description provided for @overtimeTime.
  ///
  /// In en, this message translates to:
  /// **'overtime {time}'**
  String overtimeTime(String time);

  /// No description provided for @peopleAtSite.
  ///
  /// In en, this message translates to:
  /// **'People working here ({n})'**
  String peopleAtSite(int n);

  /// No description provided for @peopleCount.
  ///
  /// In en, this message translates to:
  /// **'{n} people'**
  String peopleCount(int n);

  /// No description provided for @radiusMeters.
  ///
  /// In en, this message translates to:
  /// **'Radius {m} m'**
  String radiusMeters(int m);

  /// No description provided for @rejectRegistrationConfirm.
  ///
  /// In en, this message translates to:
  /// **'Turn down {name}\'s registration? They can\'t use the app.'**
  String rejectRegistrationConfirm(String name);

  /// No description provided for @waitingForApprovalBody.
  ///
  /// In en, this message translates to:
  /// **'Thanks {name}. Your account was created; the sales manager or GM will approve it. You\'ll be able to use the app then.'**
  String waitingForApprovalBody(String name);

  /// No description provided for @workedTime.
  ///
  /// In en, this message translates to:
  /// **'worked {time}'**
  String workedTime(String time);

  /// No description provided for @positions.
  ///
  /// In en, this message translates to:
  /// **'Positions'**
  String get positions;

  /// No description provided for @positionsHelp.
  ///
  /// In en, this message translates to:
  /// **'Job positions people choose when they register or that you set on their user page.'**
  String get positionsHelp;

  /// No description provided for @addPosition.
  ///
  /// In en, this message translates to:
  /// **'Add position'**
  String get addPosition;

  /// No description provided for @deletePositionBody.
  ///
  /// In en, this message translates to:
  /// **'{count} people have this position; it will show as removed. This cannot be undone.'**
  String deletePositionBody(int count);

  /// No description provided for @moreSectionSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get moreSectionSales;

  /// No description provided for @moreSectionPeople.
  ///
  /// In en, this message translates to:
  /// **'People & attendance'**
  String get moreSectionPeople;

  /// No description provided for @moreSectionSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get moreSectionSettings;

  /// No description provided for @searchUsers.
  ///
  /// In en, this message translates to:
  /// **'Search name, email, phone, position'**
  String get searchUsers;

  /// No description provided for @olderAppVersion.
  ///
  /// In en, this message translates to:
  /// **'Older app'**
  String get olderAppVersion;

  /// No description provided for @usersShown.
  ///
  /// In en, this message translates to:
  /// **'{shown} of {total} users'**
  String usersShown(int shown, int total);

  /// No description provided for @noUsersMatch.
  ///
  /// In en, this message translates to:
  /// **'No users match the search or filters.'**
  String get noUsersMatch;

  /// No description provided for @dayMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed – no check-in'**
  String get dayMissed;

  /// No description provided for @dayOnLeave.
  ///
  /// In en, this message translates to:
  /// **'On leave'**
  String get dayOnLeave;

  /// No description provided for @dayOff.
  ///
  /// In en, this message translates to:
  /// **'Day off or holiday'**
  String get dayOff;

  /// No description provided for @daysAttended.
  ///
  /// In en, this message translates to:
  /// **'Attended {n}'**
  String daysAttended(int n);

  /// No description provided for @daysMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed {n}'**
  String daysMissed(int n);

  /// No description provided for @leaveLegend.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leaveLegend;

  /// No description provided for @monthHours.
  ///
  /// In en, this message translates to:
  /// **'{time} this month'**
  String monthHours(String time);

  /// No description provided for @checkedInFor.
  ///
  /// In en, this message translates to:
  /// **'{time} so far'**
  String checkedInFor(String time);

  /// No description provided for @noWorkSiteYet.
  ///
  /// In en, this message translates to:
  /// **'You\'re not assigned to a work site yet. Ask your manager to add you to one.'**
  String get noWorkSiteYet;

  /// No description provided for @sendGap.
  ///
  /// In en, this message translates to:
  /// **'Your location wasn\'t sent from {from} to {to} today – your phone paused the app. Check the settings below.'**
  String sendGap(String from, String to);

  /// No description provided for @issueBackgroundRestricted.
  ///
  /// In en, this message translates to:
  /// **'Battery use for WPC CRM is set to “Restricted”: set it to “Unrestricted”'**
  String get issueBackgroundRestricted;

  /// No description provided for @issueAppSleeping.
  ///
  /// In en, this message translates to:
  /// **'Android has put WPC CRM to sleep – allow it to run in the background'**
  String get issueAppSleeping;

  /// No description provided for @phoneSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'One more setting on this phone'**
  String get phoneSetupTitle;

  /// No description provided for @phoneSetupXiaomi.
  ///
  /// In en, this message translates to:
  /// **'Xiaomi / Redmi / POCO pause apps on their own. Turn on Autostart for WPC CRM, and set Battery saver to “No restrictions”.'**
  String get phoneSetupXiaomi;

  /// No description provided for @phoneSetupSamsung.
  ///
  /// In en, this message translates to:
  /// **'Samsung puts unused apps to sleep. In Settings → Battery → Background usage limits, remove WPC CRM from “Sleeping apps” and “Deep sleeping apps”, and add it to “Never sleeping apps”.'**
  String get phoneSetupSamsung;

  /// No description provided for @phoneSetupHuawei.
  ///
  /// In en, this message translates to:
  /// **'Huawei / Honor stop apps in the background. In Settings → Battery → App launch, set WPC CRM to manage manually and turn on Auto-launch, Secondary launch and Run in background.'**
  String get phoneSetupHuawei;

  /// No description provided for @phoneSetupOppo.
  ///
  /// In en, this message translates to:
  /// **'Oppo / Realme stop apps in the background. Allow Auto launch for WPC CRM, and in its Battery settings allow background activity.'**
  String get phoneSetupOppo;

  /// No description provided for @phoneSetupVivo.
  ///
  /// In en, this message translates to:
  /// **'Vivo stops apps in the background. Allow Auto start and “High background power consumption” for WPC CRM.'**
  String get phoneSetupVivo;

  /// No description provided for @phoneSetupOneplus.
  ///
  /// In en, this message translates to:
  /// **'OnePlus stops apps in the background. Set Battery optimization for WPC CRM to “Don\'t optimize” and allow Auto-launch.'**
  String get phoneSetupOneplus;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @phoneSetupDone.
  ///
  /// In en, this message translates to:
  /// **'I\'ve done this'**
  String get phoneSetupDone;

  /// No description provided for @pickWorkDays.
  ///
  /// In en, this message translates to:
  /// **'Pick at least one work day'**
  String get pickWorkDays;

  /// No description provided for @ownWorkSchedule.
  ///
  /// In en, this message translates to:
  /// **'Own work schedule'**
  String get ownWorkSchedule;

  /// No description provided for @ownWorkScheduleHelp.
  ///
  /// In en, this message translates to:
  /// **'Attendance, lateness and the end of their day use these days and hours.'**
  String get ownWorkScheduleHelp;

  /// No description provided for @companyWorkHoursNote.
  ///
  /// In en, this message translates to:
  /// **'Off: company work hours ({hours})'**
  String companyWorkHoursNote(String hours);

  /// No description provided for @stayedAfterTime.
  ///
  /// In en, this message translates to:
  /// **'stayed after hours {time} (not counted)'**
  String stayedAfterTime(String time);

  /// No description provided for @lateBy.
  ///
  /// In en, this message translates to:
  /// **'late {time}'**
  String lateBy(String time);

  /// No description provided for @lateDays.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 late day} other{{n} late days}}'**
  String lateDays(int n);

  /// No description provided for @notifCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'{name} checked in at {time}'**
  String notifCheckedIn(String name, String time);

  /// No description provided for @notifCheckedInSelf.
  ///
  /// In en, this message translates to:
  /// **'You\'re checked in at {time}'**
  String notifCheckedInSelf(String time);

  /// No description provided for @notifMinutesLate.
  ///
  /// In en, this message translates to:
  /// **'{n} min late'**
  String notifMinutesLate(int n);

  /// No description provided for @notifAttendanceLate.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t checked in yet – your work day started at {time}. Please be at work soon.'**
  String notifAttendanceLate(String time);

  /// No description provided for @attendanceReport.
  ///
  /// In en, this message translates to:
  /// **'Monthly report'**
  String get attendanceReport;

  /// No description provided for @attendanceReportEmpty.
  ///
  /// In en, this message translates to:
  /// **'No one needs attendance yet. Turn on \"Attendance required\" and pick a work site on the user form.'**
  String get attendanceReportEmpty;

  /// No description provided for @reportEmployee.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get reportEmployee;

  /// No description provided for @reportSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get reportSchedule;

  /// No description provided for @reportWorkDays.
  ///
  /// In en, this message translates to:
  /// **'Work days'**
  String get reportWorkDays;

  /// No description provided for @reportMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get reportMissed;

  /// No description provided for @reportLateDays.
  ///
  /// In en, this message translates to:
  /// **'Late days'**
  String get reportLateDays;

  /// No description provided for @reportLateHours.
  ///
  /// In en, this message translates to:
  /// **'Late (hours)'**
  String get reportLateHours;

  /// No description provided for @reportLateMinutes.
  ///
  /// In en, this message translates to:
  /// **'Late (minutes)'**
  String get reportLateMinutes;

  /// No description provided for @reportWorkedHours.
  ///
  /// In en, this message translates to:
  /// **'Hours worked'**
  String get reportWorkedHours;

  /// No description provided for @reportOvertimeApprovedHours.
  ///
  /// In en, this message translates to:
  /// **'Overtime approved (hours)'**
  String get reportOvertimeApprovedHours;

  /// No description provided for @reportOvertimeHours.
  ///
  /// In en, this message translates to:
  /// **'Overtime (hours)'**
  String get reportOvertimeHours;

  /// No description provided for @reportStayedAfterHours.
  ///
  /// In en, this message translates to:
  /// **'Stayed after hours, no overtime (hours)'**
  String get reportStayedAfterHours;

  /// No description provided for @reportDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get reportDate;

  /// No description provided for @reportStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get reportStatus;

  /// No description provided for @reportSite.
  ///
  /// In en, this message translates to:
  /// **'Work site'**
  String get reportSite;

  /// No description provided for @reportCheckOutType.
  ///
  /// In en, this message translates to:
  /// **'How the day ended'**
  String get reportCheckOutType;

  /// No description provided for @dayAttended.
  ///
  /// In en, this message translates to:
  /// **'Attended'**
  String get dayAttended;

  /// No description provided for @reportSummaryLine.
  ///
  /// In en, this message translates to:
  /// **'Attended {attended} of {workDays} · missed {missed} · leave {leave}'**
  String reportSummaryLine(int attended, int workDays, int missed, int leave);

  /// No description provided for @reportLateLine.
  ///
  /// In en, this message translates to:
  /// **'late {days}× ({time})'**
  String reportLateLine(int days, String time);

  /// No description provided for @reportStayedLine.
  ///
  /// In en, this message translates to:
  /// **'stayed after {time}'**
  String reportStayedLine(String time);

  /// No description provided for @noClientsFound.
  ///
  /// In en, this message translates to:
  /// **'No clients found'**
  String get noClientsFound;

  /// No description provided for @searchContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get searchContact;

  /// No description provided for @searchOtherName.
  ///
  /// In en, this message translates to:
  /// **'Other name'**
  String get searchOtherName;

  /// No description provided for @salesTeam.
  ///
  /// In en, this message translates to:
  /// **'Sales team'**
  String get salesTeam;

  /// No description provided for @drivers.
  ///
  /// In en, this message translates to:
  /// **'Drivers'**
  String get drivers;

  /// No description provided for @salesTeamCount.
  ///
  /// In en, this message translates to:
  /// **'Sales team ({n})'**
  String salesTeamCount(int n);

  /// No description provided for @driversCount.
  ///
  /// In en, this message translates to:
  /// **'Drivers ({n})'**
  String driversCount(int n);

  /// No description provided for @searchClientsHint.
  ///
  /// In en, this message translates to:
  /// **'Search name, contact, phone, VAT, CR, salesperson'**
  String get searchClientsHint;

  /// No description provided for @searchResultsOnMap.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 client} other{{n} clients}}'**
  String searchResultsOnMap(int n);

  /// No description provided for @noDriversYet.
  ///
  /// In en, this message translates to:
  /// **'No drivers yet. Give a user the Driver role on the Users page; they appear here once their phone has the latest app.'**
  String get noDriversYet;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{n} min'**
  String minutesShort(int n);

  /// No description provided for @kmPerHour.
  ///
  /// In en, this message translates to:
  /// **'{n} km/h'**
  String kmPerHour(int n);

  /// No description provided for @reportBenchmarkDefault.
  ///
  /// In en, this message translates to:
  /// **'Team benchmark (fixed guesses until there are enough GPS days)'**
  String get reportBenchmarkDefault;

  /// No description provided for @reportBenchmarkTitle.
  ///
  /// In en, this message translates to:
  /// **'Team benchmark · median of {n} salespeople'**
  String reportBenchmarkTitle(int n);

  /// No description provided for @reportBenchVisit.
  ///
  /// In en, this message translates to:
  /// **'Time per visit'**
  String get reportBenchVisit;

  /// No description provided for @reportBenchSpeed.
  ///
  /// In en, this message translates to:
  /// **'Driving speed'**
  String get reportBenchSpeed;

  /// No description provided for @reportBenchRoad.
  ///
  /// In en, this message translates to:
  /// **'Roads vs straight line'**
  String get reportBenchRoad;

  /// No description provided for @reportBenchExample.
  ///
  /// In en, this message translates to:
  /// **'10 visits with 30 km (straight line) between them ≈ {time}'**
  String reportBenchExample(String time);

  /// No description provided for @reportBenchPartly.
  ///
  /// In en, this message translates to:
  /// **'Some values are still the fixed guesses (30 min a visit, 40 km/h, roads 1.4×) until at least two salespeople have two GPS days each.'**
  String get reportBenchPartly;

  /// No description provided for @reportTimeSplit.
  ///
  /// In en, this message translates to:
  /// **'Where the work day went'**
  String get reportTimeSplit;

  /// No description provided for @deliveries.
  ///
  /// In en, this message translates to:
  /// **'Deliveries'**
  String get deliveries;

  /// No description provided for @deliveryStopsNote.
  ///
  /// In en, this message translates to:
  /// **'Stops of 5 min or more within 200 m of a client\'s location. Times are from the driver\'s GPS: arrival to departure.'**
  String get deliveryStopsNote;

  /// No description provided for @deliveryFromPin.
  ///
  /// In en, this message translates to:
  /// **'{meters} m from the pin'**
  String deliveryFromPin(int meters);

  /// No description provided for @noDeliveriesFound.
  ///
  /// In en, this message translates to:
  /// **'No stops at a client\'s location found for this day.'**
  String get noDeliveriesFound;

  /// No description provided for @deliveryLocationOther.
  ///
  /// In en, this message translates to:
  /// **'other location'**
  String get deliveryLocationOther;

  /// No description provided for @timeAtClients.
  ///
  /// In en, this message translates to:
  /// **'At clients'**
  String get timeAtClients;

  /// No description provided for @timeDriving.
  ///
  /// In en, this message translates to:
  /// **'Driving'**
  String get timeDriving;

  /// No description provided for @timeOffice.
  ///
  /// In en, this message translates to:
  /// **'Office'**
  String get timeOffice;

  /// No description provided for @timeLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get timeLunch;

  /// No description provided for @timeStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped elsewhere'**
  String get timeStopped;

  /// No description provided for @timeNoData.
  ///
  /// In en, this message translates to:
  /// **'No GPS data'**
  String get timeNoData;

  /// No description provided for @reportNoGpsDay.
  ///
  /// In en, this message translates to:
  /// **'no GPS – from check-in times'**
  String get reportNoGpsDay;

  /// No description provided for @efficiencyDetailNoGps.
  ///
  /// In en, this message translates to:
  /// **'Needed about {needed} at the team\'s pace, took {took} (no GPS timeline: first to last check-in plus one visit)'**
  String efficiencyDetailNoGps(String needed, String took);

  /// No description provided for @roleLogisticsManager.
  ///
  /// In en, this message translates to:
  /// **'Logistics manager'**
  String get roleLogisticsManager;

  /// No description provided for @roleWarehouseSupervisor.
  ///
  /// In en, this message translates to:
  /// **'Warehouse supervisor'**
  String get roleWarehouseSupervisor;

  /// No description provided for @roleFactoryManager.
  ///
  /// In en, this message translates to:
  /// **'Factory manager'**
  String get roleFactoryManager;

  /// No description provided for @roleOperator.
  ///
  /// In en, this message translates to:
  /// **'Operator'**
  String get roleOperator;

  /// No description provided for @driversPage.
  ///
  /// In en, this message translates to:
  /// **'Drivers'**
  String get driversPage;

  /// No description provided for @routeHistoryToday.
  ///
  /// In en, this message translates to:
  /// **'Route history'**
  String get routeHistoryToday;

  /// No description provided for @checkInNeedsLocation.
  ///
  /// In en, this message translates to:
  /// **'To check in, turn on:'**
  String get checkInNeedsLocation;

  /// No description provided for @checkInGpsOff.
  ///
  /// In en, this message translates to:
  /// **'Location (GPS) on the phone'**
  String get checkInGpsOff;

  /// No description provided for @checkInNoPermission.
  ///
  /// In en, this message translates to:
  /// **'Location permission for the app'**
  String get checkInNoPermission;

  /// No description provided for @checkInNotAlways.
  ///
  /// In en, this message translates to:
  /// **'Location access set to \"Allow all the time\"'**
  String get checkInNotAlways;

  /// No description provided for @mapView.
  ///
  /// In en, this message translates to:
  /// **'Map view'**
  String get mapView;

  /// No description provided for @mapViewMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get mapViewMap;

  /// No description provided for @mapViewSatellite.
  ///
  /// In en, this message translates to:
  /// **'Satellite'**
  String get mapViewSatellite;

  /// No description provided for @mapViewHybrid.
  ///
  /// In en, this message translates to:
  /// **'Hybrid (satellite + labels)'**
  String get mapViewHybrid;

  /// No description provided for @settingsSectionTracking.
  ///
  /// In en, this message translates to:
  /// **'Tracking & work hours'**
  String get settingsSectionTracking;

  /// No description provided for @settingsSectionClients.
  ///
  /// In en, this message translates to:
  /// **'Clients & visits'**
  String get settingsSectionClients;

  /// No description provided for @settingsSectionPeople.
  ///
  /// In en, this message translates to:
  /// **'People & attendance'**
  String get settingsSectionPeople;

  /// No description provided for @trackingSchedules.
  ///
  /// In en, this message translates to:
  /// **'Tracking schedules'**
  String get trackingSchedules;

  /// No description provided for @trackingSchedulesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Everyone follows the company work hours} =1{1 person has their own schedule} other{{count} people have their own schedule}}'**
  String trackingSchedulesCount(int count);

  /// No description provided for @trackingSchedulesHelp.
  ///
  /// In en, this message translates to:
  /// **'When each person\'s location is shared. By default the sales team follows the company work hours ({hours}) and drivers are tracked all day. Tap a person to give them their own days and hours, or all day.'**
  String trackingSchedulesHelp(String hours);

  /// No description provided for @noTrackedPeople.
  ///
  /// In en, this message translates to:
  /// **'Nobody is tracked yet.'**
  String get noTrackedPeople;

  /// No description provided for @trackingAllDay.
  ///
  /// In en, this message translates to:
  /// **'All day, every day'**
  String get trackingAllDay;

  /// No description provided for @trackingAllDayDriver.
  ///
  /// In en, this message translates to:
  /// **'All day (driver)'**
  String get trackingAllDayDriver;

  /// No description provided for @trackingCompanyHours.
  ///
  /// In en, this message translates to:
  /// **'Company work hours'**
  String get trackingCompanyHours;

  /// No description provided for @trackingScheduleOf.
  ///
  /// In en, this message translates to:
  /// **'Tracking hours · {name}'**
  String trackingScheduleOf(String name);

  /// No description provided for @trackingModeStandard.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get trackingModeStandard;

  /// No description provided for @trackingModeOwn.
  ///
  /// In en, this message translates to:
  /// **'Own hours'**
  String get trackingModeOwn;

  /// No description provided for @trackingModeAllDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get trackingModeAllDay;

  /// No description provided for @trackingStandardDriverHelp.
  ///
  /// In en, this message translates to:
  /// **'Drivers keep the company car, so their location is shared all day.'**
  String get trackingStandardDriverHelp;

  /// No description provided for @trackingStandardHelp.
  ///
  /// In en, this message translates to:
  /// **'Location shared during the company work hours: {hours}.'**
  String trackingStandardHelp(String hours);

  /// No description provided for @trackingAllDayHelp.
  ///
  /// In en, this message translates to:
  /// **'Location shared at all times, also on days off. Tracking alerts are still sent only during the company work hours.'**
  String get trackingAllDayHelp;

  /// No description provided for @trackingOwnHelp.
  ///
  /// In en, this message translates to:
  /// **'Location shared only on these days and hours. Tracking and offline alerts follow them too.'**
  String get trackingOwnHelp;

  /// No description provided for @trackingHours.
  ///
  /// In en, this message translates to:
  /// **'Tracking hours'**
  String get trackingHours;

  /// No description provided for @settingTrackingInterval.
  ///
  /// In en, this message translates to:
  /// **'Location sending interval'**
  String get settingTrackingInterval;

  /// No description provided for @settingTrackingIntervalHelp.
  ///
  /// In en, this message translates to:
  /// **'How often a tracked phone sends its position. Shorter = more detailed routes, more battery use.'**
  String get settingTrackingIntervalHelp;

  /// No description provided for @settingOfflineAlert.
  ///
  /// In en, this message translates to:
  /// **'Offline alert after'**
  String get settingOfflineAlert;

  /// No description provided for @settingOfflineAlertHelp.
  ///
  /// In en, this message translates to:
  /// **'A tracked phone offline this long during work time is reported to the KAM or managers.'**
  String get settingOfflineAlertHelp;

  /// No description provided for @settingVisitRadius.
  ///
  /// In en, this message translates to:
  /// **'Check-in distance limit'**
  String get settingVisitRadius;

  /// No description provided for @settingVisitRadiusHelp.
  ///
  /// In en, this message translates to:
  /// **'Visits checked in farther than this from the client are flagged as far.'**
  String get settingVisitRadiusHelp;

  /// No description provided for @settingLateGrace.
  ///
  /// In en, this message translates to:
  /// **'Late check-in grace'**
  String get settingLateGrace;

  /// No description provided for @settingLateGraceHelp.
  ///
  /// In en, this message translates to:
  /// **'Attendance check-ins up to this long after the start of the day count as on time.'**
  String get settingLateGraceHelp;

  /// No description provided for @settingGivenDueSoon.
  ///
  /// In en, this message translates to:
  /// **'Catalog \"due soon\" warning'**
  String get settingGivenDueSoon;

  /// No description provided for @settingGivenDueSoonHelp.
  ///
  /// In en, this message translates to:
  /// **'Catalogs and stands show \"due soon\" this many days before a new one is due.'**
  String get settingGivenDueSoonHelp;

  /// No description provided for @valueSeconds.
  ///
  /// In en, this message translates to:
  /// **'{count} s'**
  String valueSeconds(int count);

  /// No description provided for @valueMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String valueMinutes(int count);

  /// No description provided for @valueMeters.
  ///
  /// In en, this message translates to:
  /// **'{count} m'**
  String valueMeters(int count);

  /// No description provided for @valueDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String valueDays(int count);

  /// No description provided for @settingRange.
  ///
  /// In en, this message translates to:
  /// **'Enter a value from {min} to {max}'**
  String settingRange(String min, String max);

  /// No description provided for @settingDefault.
  ///
  /// In en, this message translates to:
  /// **'Default: {value}'**
  String settingDefault(String value);

  /// No description provided for @resetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get resetToDefault;

  /// No description provided for @deleteUser.
  ///
  /// In en, this message translates to:
  /// **'Delete user'**
  String get deleteUser;

  /// No description provided for @checkInBatteryOptimized.
  ///
  /// In en, this message translates to:
  /// **'Let WPC CRM run in the background (battery optimization off)'**
  String get checkInBatteryOptimized;

  /// No description provided for @checkInAutostartOff.
  ///
  /// In en, this message translates to:
  /// **'Autostart is off for WPC CRM'**
  String get checkInAutostartOff;

  /// No description provided for @allowBackgroundForAttendance.
  ///
  /// In en, this message translates to:
  /// **'Let the app run in the background, so arriving at your site checks you in'**
  String get allowBackgroundForAttendance;

  /// No description provided for @openAutostart.
  ///
  /// In en, this message translates to:
  /// **'Autostart'**
  String get openAutostart;

  /// No description provided for @openBatterySaver.
  ///
  /// In en, this message translates to:
  /// **'Battery saver'**
  String get openBatterySaver;

  /// No description provided for @locationDisclosureTitle.
  ///
  /// In en, this message translates to:
  /// **'Location use in the background'**
  String get locationDisclosureTitle;

  /// No description provided for @locationDisclosureTracking.
  ///
  /// In en, this message translates to:
  /// **'WPC CRM collects location data to show your position to your managers on the live team map, to save your daily route history and to confirm that client visits happen at the client, during your work hours, even when the app is closed or not in use.'**
  String get locationDisclosureTracking;

  /// No description provided for @locationDisclosureAttendance.
  ///
  /// In en, this message translates to:
  /// **'WPC CRM collects location data to check you in automatically when you arrive at your work site and to record when you leave it, even when the app is closed or not in use. For office staff the app also records your location from 08:00 to 18:00 on your work days, so your arrival and check-in times are correct; it is not shown on any live map.'**
  String get locationDisclosureAttendance;

  /// No description provided for @locationDisclosureNext.
  ///
  /// In en, this message translates to:
  /// **'Your location is used only for your work with the company and is not used for advertising. On the next screen, choose \"Allow all the time\".'**
  String get locationDisclosureNext;

  /// No description provided for @locationDisclosureNo.
  ///
  /// In en, this message translates to:
  /// **'No thanks'**
  String get locationDisclosureNo;

  /// No description provided for @locationDisclosureContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get locationDisclosureContinue;

  /// No description provided for @addToWhosePlan.
  ///
  /// In en, this message translates to:
  /// **'Add to whose plan today?'**
  String get addToWhosePlan;

  /// No description provided for @personsPlan.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s plan'**
  String personsPlan(String name);

  /// No description provided for @addToPersonsPlanToday.
  ///
  /// In en, this message translates to:
  /// **'Add to {name}\'s plan today'**
  String addToPersonsPlanToday(String name);

  /// No description provided for @onPersonsPlanToday.
  ///
  /// In en, this message translates to:
  /// **'On {name}\'s plan today'**
  String onPersonsPlanToday(String name);

  /// No description provided for @addedToPersonsPlan.
  ///
  /// In en, this message translates to:
  /// **'Added to {name}\'s plan for today'**
  String addedToPersonsPlan(String name);

  /// No description provided for @dayView.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get dayView;

  /// No description provided for @weekView.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get weekView;

  /// No description provided for @monthView.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get monthView;

  /// No description provided for @clearAllFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear all filters'**
  String get clearAllFilters;

  /// No description provided for @workedOf.
  ///
  /// In en, this message translates to:
  /// **'{worked} of {scheduled}'**
  String workedOf(String worked, String scheduled);

  /// No description provided for @stillIn.
  ///
  /// In en, this message translates to:
  /// **'still in'**
  String get stillIn;

  /// No description provided for @startAt.
  ///
  /// In en, this message translates to:
  /// **'Start {time}'**
  String startAt(String time);

  /// No description provided for @notInYet.
  ///
  /// In en, this message translates to:
  /// **'Not in yet'**
  String get notInYet;

  /// No description provided for @checkedInAtTime.
  ///
  /// In en, this message translates to:
  /// **'Checked in {time}'**
  String checkedInAtTime(String time);

  /// No description provided for @onSite.
  ///
  /// In en, this message translates to:
  /// **'On site'**
  String get onSite;

  /// No description provided for @notOnSite.
  ///
  /// In en, this message translates to:
  /// **'Not on site'**
  String get notOnSite;

  /// No description provided for @leftTheSite.
  ///
  /// In en, this message translates to:
  /// **'Left the site'**
  String get leftTheSite;

  /// No description provided for @checkedOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Checked out'**
  String get checkedOutTitle;

  /// No description provided for @workedSoFar.
  ///
  /// In en, this message translates to:
  /// **'Worked so far'**
  String get workedSoFar;

  /// No description provided for @delaysCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Delays} =1{1 late} other{{count} late}}'**
  String delaysCount(int count);

  /// No description provided for @noDelays.
  ///
  /// In en, this message translates to:
  /// **'No one was late'**
  String get noDelays;

  /// No description provided for @searchByName.
  ///
  /// In en, this message translates to:
  /// **'Search name'**
  String get searchByName;

  /// No description provided for @viewStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get viewStatus;

  /// No description provided for @viewWorkedHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get viewWorkedHours;

  /// No description provided for @viewDelays.
  ///
  /// In en, this message translates to:
  /// **'Delays'**
  String get viewDelays;

  /// No description provided for @noOneMatches.
  ///
  /// In en, this message translates to:
  /// **'No one matches'**
  String get noOneMatches;

  /// No description provided for @mrScore.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get mrScore;

  /// No description provided for @mrHowScored.
  ///
  /// In en, this message translates to:
  /// **'Score out of 100: target {target} points (share reached, up to 100%; without a target compared with the busiest person), efficiency {efficiency}, clients visited {clients}, new clients {newClients} and first visits {first} (each compared with the team\'s best).'**
  String mrHowScored(
    int target,
    int efficiency,
    int clients,
    int newClients,
    int first,
  );

  /// No description provided for @mrTargetAchieved.
  ///
  /// In en, this message translates to:
  /// **'Target achieved'**
  String get mrTargetAchieved;

  /// No description provided for @mrTargetMissed.
  ///
  /// In en, this message translates to:
  /// **'Target not reached'**
  String get mrTargetMissed;

  /// No description provided for @mrNoTarget.
  ///
  /// In en, this message translates to:
  /// **'No target set'**
  String get mrNoTarget;

  /// No description provided for @mrWorkDays.
  ///
  /// In en, this message translates to:
  /// **'Days in the field'**
  String get mrWorkDays;

  /// No description provided for @mrVisitsPerDay.
  ///
  /// In en, this message translates to:
  /// **'Visits a day'**
  String get mrVisitsPerDay;

  /// No description provided for @mrClientsVisited.
  ///
  /// In en, this message translates to:
  /// **'Clients visited'**
  String get mrClientsVisited;

  /// No description provided for @mrFirstVisits.
  ///
  /// In en, this message translates to:
  /// **'First visits'**
  String get mrFirstVisits;

  /// No description provided for @mrRevisited.
  ///
  /// In en, this message translates to:
  /// **'Re-visited'**
  String get mrRevisited;

  /// No description provided for @mrNewClients.
  ///
  /// In en, this message translates to:
  /// **'New clients'**
  String get mrNewClients;

  /// No description provided for @mrEfficiencyHint.
  ///
  /// In en, this message translates to:
  /// **'Time the visits should take at the team\'s pace ÷ time they took, average of {days} days with 2+ visits'**
  String mrEfficiencyHint(int days);

  /// No description provided for @mrDrivingKmColumn.
  ///
  /// In en, this message translates to:
  /// **'Km driven a day'**
  String get mrDrivingKmColumn;

  /// No description provided for @mrClientType.
  ///
  /// In en, this message translates to:
  /// **'Client type'**
  String get mrClientType;

  /// No description provided for @mrClient.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get mrClient;

  /// No description provided for @mrNoVisits.
  ///
  /// In en, this message translates to:
  /// **'No visits in this period'**
  String get mrNoVisits;

  /// No description provided for @mrClientTypes.
  ///
  /// In en, this message translates to:
  /// **'Client types visited'**
  String get mrClientTypes;

  /// No description provided for @mrTypesHint.
  ///
  /// In en, this message translates to:
  /// **'clients · visits'**
  String get mrTypesHint;

  /// No description provided for @mrNoTag.
  ///
  /// In en, this message translates to:
  /// **'No type'**
  String get mrNoTag;

  /// No description provided for @mrAverageDay.
  ///
  /// In en, this message translates to:
  /// **'Average day'**
  String get mrAverageDay;

  /// No description provided for @mrAverageDayHint.
  ///
  /// In en, this message translates to:
  /// **'From {days} days with a GPS timeline'**
  String mrAverageDayHint(int days);

  /// No description provided for @mrNoGps.
  ///
  /// In en, this message translates to:
  /// **'No GPS day timelines in this period'**
  String get mrNoGps;

  /// No description provided for @mrTimePerClient.
  ///
  /// In en, this message translates to:
  /// **'Time at each client'**
  String get mrTimePerClient;

  /// No description provided for @mrAtClientsDay.
  ///
  /// In en, this message translates to:
  /// **'At clients a day'**
  String get mrAtClientsDay;

  /// No description provided for @mrDrivingDay.
  ///
  /// In en, this message translates to:
  /// **'Driving a day'**
  String get mrDrivingDay;

  /// No description provided for @mrDayStartEnd.
  ///
  /// In en, this message translates to:
  /// **'{start} – {end}'**
  String mrDayStartEnd(String start, String end);

  /// No description provided for @mrFirstToLast.
  ///
  /// In en, this message translates to:
  /// **'First to last client'**
  String get mrFirstToLast;

  /// No description provided for @mrKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String mrKm(String km);

  /// No description provided for @mrDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance travelled'**
  String get mrDistance;

  /// No description provided for @mrGpsDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days with GPS'**
  String mrGpsDays(int days);

  /// No description provided for @transfersShowMap.
  ///
  /// In en, this message translates to:
  /// **'Show on a map'**
  String get transfersShowMap;

  /// No description provided for @transfersShowList.
  ///
  /// In en, this message translates to:
  /// **'Show as a list'**
  String get transfersShowList;

  /// No description provided for @transfersNoLocation.
  ///
  /// In en, this message translates to:
  /// **'{count} of these clients have no location and are not on the map'**
  String transfersNoLocation(int count);

  /// No description provided for @transferLegendVisited.
  ///
  /// In en, this message translates to:
  /// **'Visited'**
  String get transferLegendVisited;

  /// No description provided for @transferLegendCalled.
  ///
  /// In en, this message translates to:
  /// **'Called'**
  String get transferLegendCalled;

  /// No description provided for @transferLegendWaiting.
  ///
  /// In en, this message translates to:
  /// **'Not visited yet'**
  String get transferLegendWaiting;

  /// No description provided for @transferLegendLate.
  ///
  /// In en, this message translates to:
  /// **'Not visited, 14+ days'**
  String get transferLegendLate;

  /// No description provided for @transferPinHelp.
  ///
  /// In en, this message translates to:
  /// **'Pins: the new salesperson\'s colour and initials; the ring shows whether they visited.'**
  String get transferPinHelp;

  /// No description provided for @mrFirstVisitList.
  ///
  /// In en, this message translates to:
  /// **'Visited for the first time ({count})'**
  String mrFirstVisitList(int count);

  /// No description provided for @mrRevisitedList.
  ///
  /// In en, this message translates to:
  /// **'Re-visited ({count})'**
  String mrRevisitedList(int count);

  /// No description provided for @mrFirstVisitsHint.
  ///
  /// In en, this message translates to:
  /// **'First visit = nobody had visited the client before in the app. Re-visited = visited before this period, or by a colleague earlier in it.'**
  String get mrFirstVisitsHint;

  /// No description provided for @mrPoints.
  ///
  /// In en, this message translates to:
  /// **'{points} / 100'**
  String mrPoints(String points);

  /// No description provided for @reportPdfTitle.
  ///
  /// In en, this message translates to:
  /// **'Sales report'**
  String get reportPdfTitle;

  /// No description provided for @rankOfTeam.
  ///
  /// In en, this message translates to:
  /// **'Rank {rank} of {count}'**
  String rankOfTeam(int rank, int count);

  /// No description provided for @keyNumbers.
  ///
  /// In en, this message translates to:
  /// **'Key numbers'**
  String get keyNumbers;

  /// No description provided for @scoreBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Score breakdown'**
  String get scoreBreakdown;

  /// No description provided for @pdfCreated.
  ///
  /// In en, this message translates to:
  /// **'Created {date}'**
  String pdfCreated(String date);

  /// No description provided for @pdfPage.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {pages}'**
  String pdfPage(int page, int pages);

  /// No description provided for @downloadPdfs.
  ///
  /// In en, this message translates to:
  /// **'Download PDF reports'**
  String get downloadPdfs;

  /// No description provided for @pdfChoosePeople.
  ///
  /// In en, this message translates to:
  /// **'One PDF file per salesperson'**
  String get pdfChoosePeople;

  /// No description provided for @pdfDownloadCount.
  ///
  /// In en, this message translates to:
  /// **'Download ({count})'**
  String pdfDownloadCount(int count);

  /// No description provided for @pdfOne.
  ///
  /// In en, this message translates to:
  /// **'PDF report'**
  String get pdfOne;

  /// No description provided for @mrFirstAndRevisited.
  ///
  /// In en, this message translates to:
  /// **'First visits and re-visits'**
  String get mrFirstAndRevisited;

  /// No description provided for @scoreInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'How the score is calculated'**
  String get scoreInfoTitle;

  /// No description provided for @scoreInfoIntro.
  ///
  /// In en, this message translates to:
  /// **'Each sales executive gets up to 100 points from five parts. The ranking is by score, and equal scores share a rank. KAMs are not ranked.'**
  String get scoreInfoIntro;

  /// No description provided for @scoreInfoPart.
  ///
  /// In en, this message translates to:
  /// **'Part'**
  String get scoreInfoPart;

  /// No description provided for @scoreInfoMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get scoreInfoMax;

  /// No description provided for @scoreInfoHow.
  ///
  /// In en, this message translates to:
  /// **'How it is measured'**
  String get scoreInfoHow;

  /// No description provided for @scoreInfoPoints.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get scoreInfoPoints;

  /// No description provided for @scorePartTargetHow.
  ///
  /// In en, this message translates to:
  /// **'(Visits + calls) ÷ target, up to 100%. Without a target: compared with the busiest sales executive.'**
  String get scorePartTargetHow;

  /// No description provided for @scorePartEfficiencyHow.
  ///
  /// In en, this message translates to:
  /// **'Average efficiency of the days with 2 or more visits (see Routing).'**
  String get scorePartEfficiencyHow;

  /// No description provided for @scorePartClientsHow.
  ///
  /// In en, this message translates to:
  /// **'Clients visited or called, compared with the sales executive who reached the most.'**
  String get scorePartClientsHow;

  /// No description provided for @scorePartNewHow.
  ///
  /// In en, this message translates to:
  /// **'New clients they added or that were imported for them, compared with the most.'**
  String get scorePartNewHow;

  /// No description provided for @scorePartFirstHow.
  ///
  /// In en, this message translates to:
  /// **'Clients visited for the first time, compared with the most.'**
  String get scorePartFirstHow;

  /// No description provided for @scoreInfoExample.
  ///
  /// In en, this message translates to:
  /// **'Example: 54 visits + calls with a target of 60 = 90%, so 0.9 × 35 = 31.5 points. With 10 first visits when the best did 20: 0.5 × 10 = 5 points.'**
  String get scoreInfoExample;

  /// No description provided for @scoreFor.
  ///
  /// In en, this message translates to:
  /// **'Score of {name}: {points} / 100'**
  String scoreFor(String name, String points);

  /// No description provided for @salesExecutivesSection.
  ///
  /// In en, this message translates to:
  /// **'Sales executives'**
  String get salesExecutivesSection;

  /// No description provided for @kamSection.
  ///
  /// In en, this message translates to:
  /// **'Key account managers'**
  String get kamSection;

  /// No description provided for @kamSectionNote.
  ///
  /// In en, this message translates to:
  /// **'How KAMs are measured is not decided yet. These are their own numbers, without a score or ranking.'**
  String get kamSectionNote;

  /// No description provided for @kamVisitsWithTeam.
  ///
  /// In en, this message translates to:
  /// **'Visits with their team'**
  String get kamVisitsWithTeam;

  /// No description provided for @kamTeamSize.
  ///
  /// In en, this message translates to:
  /// **'Team members'**
  String get kamTeamSize;

  /// No description provided for @kamTeamVisits.
  ///
  /// In en, this message translates to:
  /// **'Team visits + calls'**
  String get kamTeamVisits;

  /// No description provided for @firstAndRevisitedShort.
  ///
  /// In en, this message translates to:
  /// **'{first} first · {revisited} re-visited'**
  String firstAndRevisitedShort(int first, int revisited);

  /// No description provided for @onScheduleShort.
  ///
  /// In en, this message translates to:
  /// **'On schedule {value}'**
  String onScheduleShort(String value);

  /// No description provided for @moreActions.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreActions;

  /// No description provided for @settingAwayGrace.
  ///
  /// In en, this message translates to:
  /// **'Away from the site before check-out'**
  String get settingAwayGrace;

  /// No description provided for @settingAwayGraceHelp.
  ///
  /// In en, this message translates to:
  /// **'People not allowed to leave their work site who stay away longer than this are checked out at the time they left. Coming back checks them in again.'**
  String get settingAwayGraceHelp;

  /// No description provided for @leaveSiteAllowed.
  ///
  /// In en, this message translates to:
  /// **'Allowed to leave the site'**
  String get leaveSiteAllowed;

  /// No description provided for @leaveSiteAllowedHelp.
  ///
  /// In en, this message translates to:
  /// **'Leaving the site during the work day doesn\'t check them out (usually the sales team and drivers).'**
  String get leaveSiteAllowedHelp;

  /// No description provided for @leaveSiteNotAllowedHelp.
  ///
  /// In en, this message translates to:
  /// **'Away from the site for more than {minutes} min → checked out at the time they left. Coming back checks them in again; the time away doesn\'t count.'**
  String leaveSiteNotAllowedHelp(int minutes);

  /// No description provided for @checkOutLeftSite.
  ///
  /// In en, this message translates to:
  /// **'left the site'**
  String get checkOutLeftSite;

  /// No description provided for @absenceSick.
  ///
  /// In en, this message translates to:
  /// **'Sick'**
  String get absenceSick;

  /// No description provided for @absenceTired.
  ///
  /// In en, this message translates to:
  /// **'Tired'**
  String get absenceTired;

  /// No description provided for @absenceCantCome.
  ///
  /// In en, this message translates to:
  /// **'Can\'t come'**
  String get absenceCantCome;

  /// No description provided for @absencePickReason.
  ///
  /// In en, this message translates to:
  /// **'Pick a reason'**
  String get absencePickReason;

  /// No description provided for @absenceWriteReason.
  ///
  /// In en, this message translates to:
  /// **'Write the reason'**
  String get absenceWriteReason;

  /// No description provided for @absenceSent.
  ///
  /// In en, this message translates to:
  /// **'Sent. HR and your manager have been told.'**
  String get absenceSent;

  /// No description provided for @absenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Not coming to work'**
  String get absenceTitle;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @absenceReasonField.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get absenceReasonField;

  /// No description provided for @absenceSickHelp.
  ///
  /// In en, this message translates to:
  /// **'Attach your medical report (now or later). HR accepts the day as sick leave only with the report.'**
  String get absenceSickHelp;

  /// No description provided for @absenceSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get absenceSend;

  /// No description provided for @absentToday.
  ///
  /// In en, this message translates to:
  /// **'Not coming today · {reason}'**
  String absentToday(String reason);

  /// No description provided for @absentOn.
  ///
  /// In en, this message translates to:
  /// **'Not coming on {date} · {reason}'**
  String absentOn(String date, String reason);

  /// No description provided for @absenceUndoConfirm.
  ///
  /// In en, this message translates to:
  /// **'Take back this absence?'**
  String get absenceUndoConfirm;

  /// No description provided for @absenceUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get absenceUndo;

  /// No description provided for @sickReportMissing.
  ///
  /// In en, this message translates to:
  /// **'Medical report not attached yet – needed to approve the sick leave'**
  String get sickReportMissing;

  /// No description provided for @attachSickReport.
  ///
  /// In en, this message translates to:
  /// **'Attach medical report'**
  String get attachSickReport;

  /// No description provided for @openRequest.
  ///
  /// In en, this message translates to:
  /// **'Open request'**
  String get openRequest;

  /// No description provided for @absenceButton.
  ///
  /// In en, this message translates to:
  /// **'Not coming to work?'**
  String get absenceButton;

  /// No description provided for @dayReportedAbsent.
  ///
  /// In en, this message translates to:
  /// **'Reported absent: {reason}'**
  String dayReportedAbsent(String reason);

  /// No description provided for @daysReportedAbsent.
  ///
  /// In en, this message translates to:
  /// **'{count} reported absent'**
  String daysReportedAbsent(int count);

  /// No description provided for @reportedAbsent.
  ///
  /// In en, this message translates to:
  /// **'Reported absent'**
  String get reportedAbsent;

  /// No description provided for @leaveDocumentMissingMine.
  ///
  /// In en, this message translates to:
  /// **'Attach the {document} – the request can be approved only with it.'**
  String leaveDocumentMissingMine(String document);

  /// No description provided for @leaveDocumentMissing.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the {document} – it can be approved once it is attached.'**
  String leaveDocumentMissing(String document);

  /// No description provided for @notifAbsenceReported.
  ///
  /// In en, this message translates to:
  /// **'{name} won\'t be at work on {day} – {reason}'**
  String notifAbsenceReported(String name, String day, String reason);

  /// No description provided for @checkOutHr.
  ///
  /// In en, this message translates to:
  /// **'corrected by HR'**
  String get checkOutHr;

  /// No description provided for @asSickLeave.
  ///
  /// In en, this message translates to:
  /// **'sick leave'**
  String get asSickLeave;

  /// No description provided for @asAnnualLeave.
  ///
  /// In en, this message translates to:
  /// **'annual leave'**
  String get asAnnualLeave;

  /// No description provided for @absenceWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for HR'**
  String get absenceWaiting;

  /// No description provided for @absenceAcceptedAs.
  ///
  /// In en, this message translates to:
  /// **'Accepted as {leave}'**
  String absenceAcceptedAs(String leave);

  /// No description provided for @absenceRejectedText.
  ///
  /// In en, this message translates to:
  /// **'Not accepted – counts as an absence day'**
  String get absenceRejectedText;

  /// No description provided for @attachDocument.
  ///
  /// In en, this message translates to:
  /// **'Attach document'**
  String get attachDocument;

  /// No description provided for @documentsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} document(s)'**
  String documentsCount(int count);

  /// No description provided for @rejectAbsence.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get rejectAbsence;

  /// No description provided for @acceptAbsenceAs.
  ///
  /// In en, this message translates to:
  /// **'Accept as {leave}'**
  String acceptAbsenceAs(String leave);

  /// No description provided for @rejectAbsenceHelp.
  ///
  /// In en, this message translates to:
  /// **'The day counts as an absence day.'**
  String get rejectAbsenceHelp;

  /// No description provided for @acceptAbsenceHelp.
  ///
  /// In en, this message translates to:
  /// **'An approved leave request is saved for this day and taken from their balance. Their direct manager is told.'**
  String get acceptAbsenceHelp;

  /// No description provided for @absenceNotFound.
  ///
  /// In en, this message translates to:
  /// **'This absence was taken back.'**
  String get absenceNotFound;

  /// No description provided for @sickReportMissingMine.
  ///
  /// In en, this message translates to:
  /// **'Attach your medical report – the day can be accepted as sick leave only with it.'**
  String get sickReportMissingMine;

  /// No description provided for @decideAbsence.
  ///
  /// In en, this message translates to:
  /// **'Decision'**
  String get decideAbsence;

  /// No description provided for @sickNeedsDocument.
  ///
  /// In en, this message translates to:
  /// **'Sick leave needs a document (medical report) attached.'**
  String get sickNeedsDocument;

  /// No description provided for @annualLeaveLeft.
  ///
  /// In en, this message translates to:
  /// **'Annual leave left: {days} days'**
  String annualLeaveLeft(String days);

  /// No description provided for @absencesWaiting.
  ///
  /// In en, this message translates to:
  /// **'Absences to decide ({count})'**
  String absencesWaiting(int count);

  /// No description provided for @notifAbsenceAccepted.
  ///
  /// In en, this message translates to:
  /// **'{name} accepted your absence on {day} as {leave}'**
  String notifAbsenceAccepted(String name, String day, String leave);

  /// No description provided for @notifAbsenceRejected.
  ///
  /// In en, this message translates to:
  /// **'{name} didn\'t accept your absence on {day} – it counts as an absence day'**
  String notifAbsenceRejected(String name, String day);

  /// No description provided for @notifTeamOnLeave.
  ///
  /// In en, this message translates to:
  /// **'{name} is on leave: {dates}'**
  String notifTeamOnLeave(String name, String dates);

  /// No description provided for @correctedByHr.
  ///
  /// In en, this message translates to:
  /// **'Corrected by HR'**
  String get correctedByHr;

  /// No description provided for @overtimeEndUnknown.
  ///
  /// In en, this message translates to:
  /// **'Overtime end not confirmed · last seen {time}'**
  String overtimeEndUnknown(String time);

  /// No description provided for @overtimeEndUnknownHelp.
  ///
  /// In en, this message translates to:
  /// **'No exit or arrival was seen and the phone didn\'t confirm where they were after that, so overtime stops there. If they worked longer, correct this day.'**
  String get overtimeEndUnknownHelp;

  /// No description provided for @awayTime.
  ///
  /// In en, this message translates to:
  /// **'Away {time} (not counted)'**
  String awayTime(String time);

  /// No description provided for @correctedBy.
  ///
  /// In en, this message translates to:
  /// **'Corrected by {name}'**
  String correctedBy(String name);

  /// No description provided for @correctDay.
  ///
  /// In en, this message translates to:
  /// **'Correct this day'**
  String get correctDay;

  /// No description provided for @removeCorrection.
  ///
  /// In en, this message translates to:
  /// **'Remove correction'**
  String get removeCorrection;

  /// No description provided for @openAbsence.
  ///
  /// In en, this message translates to:
  /// **'Open absence'**
  String get openAbsence;

  /// No description provided for @openUser.
  ///
  /// In en, this message translates to:
  /// **'Open user'**
  String get openUser;

  /// No description provided for @correctionNoteNeeded.
  ///
  /// In en, this message translates to:
  /// **'Write why the day is corrected'**
  String get correctionNoteNeeded;

  /// No description provided for @correctDayOf.
  ///
  /// In en, this message translates to:
  /// **'Correct {name}\'s day'**
  String correctDayOf(String name);

  /// No description provided for @correctDayHelp.
  ///
  /// In en, this message translates to:
  /// **'Replaces what the phone recorded. Without a check-out, the phone\'s later events still count.'**
  String get correctDayHelp;

  /// No description provided for @checkOutFromPhone.
  ///
  /// In en, this message translates to:
  /// **'From the phone'**
  String get checkOutFromPhone;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @correctionNote.
  ///
  /// In en, this message translates to:
  /// **'Reason for the correction'**
  String get correctionNote;

  /// No description provided for @identityReason.
  ///
  /// In en, this message translates to:
  /// **'Confirm it\'s you to check in or out'**
  String get identityReason;

  /// No description provided for @identityLocked.
  ///
  /// In en, this message translates to:
  /// **'Too many tries – unlock the phone with your PIN and try again.'**
  String get identityLocked;

  /// No description provided for @absencesTab.
  ///
  /// In en, this message translates to:
  /// **'Absences'**
  String get absencesTab;

  /// No description provided for @absenceAcceptedFilter.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get absenceAcceptedFilter;

  /// No description provided for @absenceRejectedFilter.
  ///
  /// In en, this message translates to:
  /// **'Not accepted'**
  String get absenceRejectedFilter;

  /// No description provided for @noAbsences.
  ///
  /// In en, this message translates to:
  /// **'No absences here.'**
  String get noAbsences;

  /// No description provided for @transfersWaiting.
  ///
  /// In en, this message translates to:
  /// **'Not visited yet ({count})'**
  String transfersWaiting(int count);

  /// No description provided for @transfersArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived ({count})'**
  String transfersArchived(int count);

  /// No description provided for @transfersAllVisited.
  ///
  /// In en, this message translates to:
  /// **'Every moved client has been visited – see Archived.'**
  String get transfersAllVisited;

  /// No description provided for @transfersNoneArchived.
  ///
  /// In en, this message translates to:
  /// **'Nothing archived yet. Clients go here once the new salesperson visits or calls them, or when they\'re moved again.'**
  String get transfersNoneArchived;

  /// No description provided for @deletedUser.
  ///
  /// In en, this message translates to:
  /// **'Deleted user'**
  String get deletedUser;

  /// No description provided for @emailOrUsername.
  ///
  /// In en, this message translates to:
  /// **'Email or username'**
  String get emailOrUsername;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @signInWith.
  ///
  /// In en, this message translates to:
  /// **'Signs in with'**
  String get signInWith;

  /// No description provided for @usernameHelp.
  ///
  /// In en, this message translates to:
  /// **'Letters, numbers, . _ - (3–30). They sign in with this; no email is needed.'**
  String get usernameHelp;

  /// No description provided for @invalidUsername.
  ///
  /// In en, this message translates to:
  /// **'3–30 letters (a–z), numbers, . _ or -'**
  String get invalidUsername;

  /// No description provided for @usernameInUse.
  ///
  /// In en, this message translates to:
  /// **'This username is taken. Choose another one.'**
  String get usernameInUse;

  /// No description provided for @setPassword.
  ///
  /// In en, this message translates to:
  /// **'Set password'**
  String get setPassword;

  /// No description provided for @setPasswordFor.
  ///
  /// In en, this message translates to:
  /// **'New password for {name}'**
  String setPasswordFor(String name);

  /// No description provided for @passwordSetFor.
  ///
  /// In en, this message translates to:
  /// **'Password changed for {name}. Tell them the new one.'**
  String passwordSetFor(String name);

  /// No description provided for @usernameResetByManager.
  ///
  /// In en, this message translates to:
  /// **'Accounts with a username can\'t get a reset email. Ask your manager to set a new password.'**
  String get usernameResetByManager;

  /// No description provided for @usernameAccountInfo.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password? Ask your manager to set a new one.'**
  String get usernameAccountInfo;

  /// No description provided for @reservedEmail.
  ///
  /// In en, this message translates to:
  /// **'This address can\'t be used. Enter your own email.'**
  String get reservedEmail;

  /// No description provided for @selectRole.
  ///
  /// In en, this message translates to:
  /// **'Select a role'**
  String get selectRole;

  /// No description provided for @usernameAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get usernameAvailable;

  /// No description provided for @usernameTaken.
  ///
  /// In en, this message translates to:
  /// **'Already used by another account'**
  String get usernameTaken;

  /// No description provided for @isManager.
  ///
  /// In en, this message translates to:
  /// **'Is a manager'**
  String get isManager;

  /// No description provided for @isManagerHelp.
  ///
  /// In en, this message translates to:
  /// **'Can be chosen as someone\'s direct manager, e.g. the accounting manager.'**
  String get isManagerHelp;

  /// No description provided for @directManager.
  ///
  /// In en, this message translates to:
  /// **'Direct manager'**
  String get directManager;

  /// No description provided for @directManagerAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic ({names})'**
  String directManagerAuto(String names);

  /// No description provided for @directManagerHelp.
  ///
  /// In en, this message translates to:
  /// **'Approves leaving early and is told when they\'re on leave or absent.'**
  String get directManagerHelp;

  /// No description provided for @askLeaveEarly.
  ///
  /// In en, this message translates to:
  /// **'Ask to leave early'**
  String get askLeaveEarly;

  /// No description provided for @askLeaveEarlyHelp.
  ///
  /// In en, this message translates to:
  /// **'Your work day ends at {time}. {names} must approve before you can check out.'**
  String askLeaveEarlyHelp(String time, String names);

  /// No description provided for @earlyRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent to {names}'**
  String earlyRequestSent(String names);

  /// No description provided for @earlyWaiting.
  ///
  /// In en, this message translates to:
  /// **'Asked to leave early – waiting for {names}'**
  String earlyWaiting(String names);

  /// No description provided for @earlyApproved.
  ///
  /// In en, this message translates to:
  /// **'{name} approved – you can check out'**
  String earlyApproved(String name);

  /// No description provided for @earlyRejected.
  ///
  /// In en, this message translates to:
  /// **'{name} didn\'t approve leaving early'**
  String earlyRejected(String name);

  /// No description provided for @earlyAskAgain.
  ///
  /// In en, this message translates to:
  /// **'Ask again'**
  String get earlyAskAgain;

  /// No description provided for @earlyRequestsWaiting.
  ///
  /// In en, this message translates to:
  /// **'Asking to leave early ({count})'**
  String earlyRequestsWaiting(int count);

  /// No description provided for @notifEarlyCheckoutRequested.
  ///
  /// In en, this message translates to:
  /// **'{name} asks to leave early today'**
  String notifEarlyCheckoutRequested(String name);

  /// No description provided for @notifEarlyCheckoutApproved.
  ///
  /// In en, this message translates to:
  /// **'{name} approved your early check-out – you can check out now'**
  String notifEarlyCheckoutApproved(String name);

  /// No description provided for @notifEarlyCheckoutRejected.
  ///
  /// In en, this message translates to:
  /// **'{name} didn\'t approve your early check-out'**
  String notifEarlyCheckoutRejected(String name);

  /// No description provided for @balanceColType.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get balanceColType;

  /// No description provided for @balanceColEntitled.
  ///
  /// In en, this message translates to:
  /// **'Entitled'**
  String get balanceColEntitled;

  /// No description provided for @balanceColUsed.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get balanceColUsed;

  /// No description provided for @balanceColWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get balanceColWaiting;

  /// No description provided for @balanceColLeft.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get balanceColLeft;

  /// No description provided for @pageAccess.
  ///
  /// In en, this message translates to:
  /// **'Page access'**
  String get pageAccess;

  /// No description provided for @pageAccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Which roles may open each page'**
  String get pageAccessSubtitle;

  /// No description provided for @pageAccessHelp.
  ///
  /// In en, this message translates to:
  /// **'Highlighted pages are open to the role; tap a page to allow or remove it (saved right away). Greyed pages with a lock can\'t be given to that role, because the data they show is protected for it (e.g. drivers can\'t see clients).'**
  String get pageAccessHelp;

  /// No description provided for @pageAccessLocked.
  ///
  /// In en, this message translates to:
  /// **'Always on for sales managers and GMs, so nobody is locked out of the settings.'**
  String get pageAccessLocked;

  /// No description provided for @pageAccessMarkedManagers.
  ///
  /// In en, this message translates to:
  /// **'People marked \"Is a manager\" always see their team\'s attendance.'**
  String get pageAccessMarkedManagers;

  /// No description provided for @settingsSectionAccess.
  ///
  /// In en, this message translates to:
  /// **'Access'**
  String get settingsSectionAccess;

  /// No description provided for @pageNotForRole.
  ///
  /// In en, this message translates to:
  /// **'Not available for this role: the data this page shows is protected for it.'**
  String get pageNotForRole;

  /// No description provided for @showSalespeople.
  ///
  /// In en, this message translates to:
  /// **'Show salespeople'**
  String get showSalespeople;

  /// No description provided for @hideSalespeople.
  ///
  /// In en, this message translates to:
  /// **'Hide salespeople'**
  String get hideSalespeople;

  /// No description provided for @searchAreaHint.
  ///
  /// In en, this message translates to:
  /// **'Area, e.g. Riyadh, Al Salam'**
  String get searchAreaHint;

  /// No description provided for @searchAreaHelp.
  ///
  /// In en, this message translates to:
  /// **'Press Enter to go there'**
  String get searchAreaHelp;

  /// No description provided for @searchAreaGo.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get searchAreaGo;

  /// No description provided for @areaNotFound.
  ///
  /// In en, this message translates to:
  /// **'No place found for \"{query}\"'**
  String areaNotFound(String query);

  /// No description provided for @areaSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t search the place. Check the internet and try again.'**
  String get areaSearchFailed;

  /// No description provided for @searchArea.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get searchArea;

  /// No description provided for @searchAsArea.
  ///
  /// In en, this message translates to:
  /// **'Search \"{text}\" as an area'**
  String searchAsArea(String text);

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @vehicles.
  ///
  /// In en, this message translates to:
  /// **'Vehicles'**
  String get vehicles;

  /// No description provided for @addVehicle.
  ///
  /// In en, this message translates to:
  /// **'Add vehicle'**
  String get addVehicle;

  /// No description provided for @editVehicle.
  ///
  /// In en, this message translates to:
  /// **'Edit vehicle'**
  String get editVehicle;

  /// No description provided for @noVehicles.
  ///
  /// In en, this message translates to:
  /// **'No vehicles yet. Add the company\'s vehicles with their drivers and renewal dates.'**
  String get noVehicles;

  /// No description provided for @vehiclePlate.
  ///
  /// In en, this message translates to:
  /// **'Plate number'**
  String get vehiclePlate;

  /// No description provided for @vehiclePlateRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the plate number'**
  String get vehiclePlateRequired;

  /// No description provided for @vehicleMake.
  ///
  /// In en, this message translates to:
  /// **'Make'**
  String get vehicleMake;

  /// No description provided for @vehicleModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get vehicleModel;

  /// No description provided for @vehicleYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get vehicleYear;

  /// No description provided for @vehicleColor.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get vehicleColor;

  /// No description provided for @vehicleVin.
  ///
  /// In en, this message translates to:
  /// **'Chassis number (VIN)'**
  String get vehicleVin;

  /// No description provided for @vehicleFirstReading.
  ///
  /// In en, this message translates to:
  /// **'Odometer now (km, optional)'**
  String get vehicleFirstReading;

  /// No description provided for @renewals.
  ///
  /// In en, this message translates to:
  /// **'Renewals'**
  String get renewals;

  /// No description provided for @renewalRegistration.
  ///
  /// In en, this message translates to:
  /// **'Registration (Istimara)'**
  String get renewalRegistration;

  /// No description provided for @renewalInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get renewalInsurance;

  /// No description provided for @renewalInspection.
  ///
  /// In en, this message translates to:
  /// **'Periodic inspection (Fahas)'**
  String get renewalInspection;

  /// No description provided for @renewalNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get renewalNotSet;

  /// No description provided for @renewalDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{days} days left'**
  String renewalDaysLeft(int days);

  /// No description provided for @renewalExpiresToday.
  ///
  /// In en, this message translates to:
  /// **'Expires today'**
  String get renewalExpiresToday;

  /// No description provided for @renewalExpiredAgo.
  ///
  /// In en, this message translates to:
  /// **'Expired {days} days ago'**
  String renewalExpiredAgo(int days);

  /// No description provided for @renewalUntil.
  ///
  /// In en, this message translates to:
  /// **'Until {date}'**
  String renewalUntil(String date);

  /// No description provided for @renewalExpiry.
  ///
  /// In en, this message translates to:
  /// **'Expiry date'**
  String get renewalExpiry;

  /// No description provided for @markRenewed.
  ///
  /// In en, this message translates to:
  /// **'Renewed'**
  String get markRenewed;

  /// No description provided for @renewDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Renew {item}'**
  String renewDialogTitle(String item);

  /// No description provided for @renewDialogHint.
  ///
  /// In en, this message translates to:
  /// **'New expiry date'**
  String get renewDialogHint;

  /// No description provided for @changeDate.
  ///
  /// In en, this message translates to:
  /// **'Change date'**
  String get changeDate;

  /// No description provided for @setDate.
  ///
  /// In en, this message translates to:
  /// **'Set date'**
  String get setDate;

  /// No description provided for @renewalHistory.
  ///
  /// In en, this message translates to:
  /// **'Renewal history'**
  String get renewalHistory;

  /// No description provided for @renewalHistoryRow.
  ///
  /// In en, this message translates to:
  /// **'{item} renewed until {date}'**
  String renewalHistoryRow(String item, String date);

  /// No description provided for @needsRenewalFilter.
  ///
  /// In en, this message translates to:
  /// **'Renewal or oil due ({count})'**
  String needsRenewalFilter(int count);

  /// No description provided for @showInactiveVehicles.
  ///
  /// In en, this message translates to:
  /// **'Show inactive'**
  String get showInactiveVehicles;

  /// No description provided for @mileage.
  ///
  /// In en, this message translates to:
  /// **'Mileage'**
  String get mileage;

  /// No description provided for @kmValue.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String kmValue(String km);

  /// No description provided for @odometerEstimate.
  ///
  /// In en, this message translates to:
  /// **'≈ {km} km now'**
  String odometerEstimate(String km);

  /// No description provided for @lastReading.
  ///
  /// In en, this message translates to:
  /// **'Last reading {km} km on {date}'**
  String lastReading(String km, String date);

  /// No description provided for @gpsKmSince.
  ///
  /// In en, this message translates to:
  /// **'+ {km} km driven since then (drivers\' GPS)'**
  String gpsKmSince(String km);

  /// No description provided for @gpsKmNoReading.
  ///
  /// In en, this message translates to:
  /// **'{km} km driven by its drivers (GPS) since they were assigned'**
  String gpsKmNoReading(String km);

  /// No description provided for @noReadingYet.
  ///
  /// In en, this message translates to:
  /// **'No odometer reading yet – record one so the app can estimate the mileage.'**
  String get noReadingYet;

  /// No description provided for @gpsKmHelp.
  ///
  /// In en, this message translates to:
  /// **'GPS km are straight lines between the drivers\' location fixes, counted from the day after the last reading, so they read a little under the odometer. Record a reading now and then to correct it.'**
  String get gpsKmHelp;

  /// No description provided for @recordReading.
  ///
  /// In en, this message translates to:
  /// **'Record reading'**
  String get recordReading;

  /// No description provided for @odometerKm.
  ///
  /// In en, this message translates to:
  /// **'Odometer (km)'**
  String get odometerKm;

  /// No description provided for @readingNote.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get readingNote;

  /// No description provided for @readingLower.
  ///
  /// In en, this message translates to:
  /// **'This is lower than the reading before it ({km} km). Save anyway?'**
  String readingLower(String km);

  /// No description provided for @readings.
  ///
  /// In en, this message translates to:
  /// **'Readings'**
  String get readings;

  /// No description provided for @deleteReadingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete the reading {km} km?'**
  String deleteReadingConfirm(String km);

  /// No description provided for @noDriverAssigned.
  ///
  /// In en, this message translates to:
  /// **'No driver'**
  String get noDriverAssigned;

  /// No description provided for @changeDrivers.
  ///
  /// In en, this message translates to:
  /// **'Change drivers'**
  String get changeDrivers;

  /// No description provided for @driverOnOtherVehicle.
  ///
  /// In en, this message translates to:
  /// **'Now on {plate} – moves to this vehicle'**
  String driverOnOtherVehicle(String plate);

  /// No description provided for @noDriverUsers.
  ///
  /// In en, this message translates to:
  /// **'No drivers yet – add users with the Driver role.'**
  String get noDriverUsers;

  /// No description provided for @deleteVehicleConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete the vehicle {plate}? Its readings and renewal history are deleted too.'**
  String deleteVehicleConfirm(String plate);

  /// No description provided for @vehicleRenewalsDue.
  ///
  /// In en, this message translates to:
  /// **'Vehicle renewals and oil changes due ({count})'**
  String vehicleRenewalsDue(int count);

  /// No description provided for @notifVehicleRenewalDue.
  ///
  /// In en, this message translates to:
  /// **'{vehicle}: {item} expires in {days} days ({date})'**
  String notifVehicleRenewalDue(
    String vehicle,
    String item,
    int days,
    String date,
  );

  /// No description provided for @notifVehicleRenewalExpired.
  ///
  /// In en, this message translates to:
  /// **'{vehicle}: {item} has expired ({date})'**
  String notifVehicleRenewalExpired(String vehicle, String item, String date);

  /// No description provided for @settingVehicleRenewal.
  ///
  /// In en, this message translates to:
  /// **'Vehicle renewal reminder'**
  String get settingVehicleRenewal;

  /// No description provided for @settingVehicleRenewalHelp.
  ///
  /// In en, this message translates to:
  /// **'The GM, sales manager and logistics manager are reminded this many days before a vehicle\'s registration, insurance, periodic inspection or operating card expires; it stays on their Home until the new date is entered.'**
  String get settingVehicleRenewalHelp;

  /// No description provided for @settingsSectionHr.
  ///
  /// In en, this message translates to:
  /// **'HR'**
  String get settingsSectionHr;

  /// No description provided for @department.
  ///
  /// In en, this message translates to:
  /// **'Department'**
  String get department;

  /// No description provided for @departments.
  ///
  /// In en, this message translates to:
  /// **'Departments'**
  String get departments;

  /// No description provided for @departmentAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic ({name})'**
  String departmentAutomatic(String name);

  /// No description provided for @noDepartment.
  ///
  /// In en, this message translates to:
  /// **'No department'**
  String get noDepartment;

  /// No description provided for @addDepartment.
  ///
  /// In en, this message translates to:
  /// **'Add department'**
  String get addDepartment;

  /// No description provided for @departmentsHelp.
  ///
  /// In en, this message translates to:
  /// **'Departments people belong to. HR filters employees by them; until one is chosen, people get the department of their role.'**
  String get departmentsHelp;

  /// No description provided for @deleteDepartmentBody.
  ///
  /// In en, this message translates to:
  /// **'{count} people are in this department; it will show as removed. This cannot be undone.'**
  String deleteDepartmentBody(int count);

  /// No description provided for @joiningDate.
  ///
  /// In en, this message translates to:
  /// **'Joining date'**
  String get joiningDate;

  /// No description provided for @joiningDateNotSet.
  ///
  /// In en, this message translates to:
  /// **'Joining date not set'**
  String get joiningDateNotSet;

  /// No description provided for @joinedOn.
  ///
  /// In en, this message translates to:
  /// **'Joined {date}'**
  String joinedOn(String date);

  /// No description provided for @leaveYearCalendarHint.
  ///
  /// In en, this message translates to:
  /// **'No joining date: leave balances run by calendar year (1 January – 31 December).'**
  String get leaveYearCalendarHint;

  /// No description provided for @leaveYearJoiningHint.
  ///
  /// In en, this message translates to:
  /// **'Leave balances start again every year on the joining date. Annual days overdrawn are taken from the next year; days left carry over only if HR allows it.'**
  String get leaveYearJoiningHint;

  /// No description provided for @leaveBalancePeriod.
  ///
  /// In en, this message translates to:
  /// **'Leave balance {period}'**
  String leaveBalancePeriod(String period);

  /// No description provided for @balanceColCarried.
  ///
  /// In en, this message translates to:
  /// **'Carried'**
  String get balanceColCarried;

  /// No description provided for @leaveCarriedDays.
  ///
  /// In en, this message translates to:
  /// **'{days} from last year'**
  String leaveCarriedDays(String days);

  /// No description provided for @pastLeaveYears.
  ///
  /// In en, this message translates to:
  /// **'Past leave years'**
  String get pastLeaveYears;

  /// No description provided for @annualTaken.
  ///
  /// In en, this message translates to:
  /// **'Annual: {used} of {of} days taken'**
  String annualTaken(String used, String of);

  /// No description provided for @carriedToNextYear.
  ///
  /// In en, this message translates to:
  /// **'{days} to the next year'**
  String carriedToNextYear(String days);

  /// No description provided for @pastYearRow.
  ///
  /// In en, this message translates to:
  /// **'{used} of {of} · {left} left'**
  String pastYearRow(String used, String of, String left);

  /// No description provided for @annualCarryOver.
  ///
  /// In en, this message translates to:
  /// **'Annual leave carries over'**
  String get annualCarryOver;

  /// No description provided for @annualCarryOverOn.
  ///
  /// In en, this message translates to:
  /// **'Days left at the end of a leave year move to the next year. Overdrawn days are always taken from the next year.'**
  String get annualCarryOverOn;

  /// No description provided for @annualCarryOverOff.
  ///
  /// In en, this message translates to:
  /// **'Days left at the end of a leave year are lost (the balance resets). Overdrawn days are always taken from the next year.'**
  String get annualCarryOverOff;

  /// No description provided for @overtimeQuestion.
  ///
  /// In en, this message translates to:
  /// **'Your shift ended at {time}. Working overtime?'**
  String overtimeQuestion(String time);

  /// No description provided for @overtimeQuestionHelp.
  ///
  /// In en, this message translates to:
  /// **'Overtime counts from {time} once you start it, while you\'re at the work site.'**
  String overtimeQuestionHelp(String time);

  /// No description provided for @overtimeDeclinedText.
  ///
  /// In en, this message translates to:
  /// **'No overtime today – changed your mind?'**
  String get overtimeDeclinedText;

  /// No description provided for @startOvertime.
  ///
  /// In en, this message translates to:
  /// **'Start overtime'**
  String get startOvertime;

  /// No description provided for @notToday.
  ///
  /// In en, this message translates to:
  /// **'Not today'**
  String get notToday;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @overtimeNotAtSite.
  ///
  /// In en, this message translates to:
  /// **'You\'re not at the work site – overtime can only be started there.'**
  String get overtimeNotAtSite;

  /// No description provided for @overtimeStartedToast.
  ///
  /// In en, this message translates to:
  /// **'Overtime started – it counts from {time}'**
  String overtimeStartedToast(String time);

  /// No description provided for @overtimeSince.
  ///
  /// In en, this message translates to:
  /// **'Overtime since {time} · {duration}'**
  String overtimeSince(String time, String duration);

  /// No description provided for @driveOvertimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Overtime started'**
  String get driveOvertimeTitle;

  /// No description provided for @driveOvertimeRunning.
  ///
  /// In en, this message translates to:
  /// **'Overtime since {time} – it ends when you arrive home or at the work site.'**
  String driveOvertimeRunning(String time);

  /// No description provided for @overtimeWaiting.
  ///
  /// In en, this message translates to:
  /// **'Overtime {duration} · waiting for approval'**
  String overtimeWaiting(String duration);

  /// No description provided for @overtimeApprovedText.
  ///
  /// In en, this message translates to:
  /// **'Overtime approved: {duration}'**
  String overtimeApprovedText(String duration);

  /// No description provided for @overtimeApprovedBy.
  ///
  /// In en, this message translates to:
  /// **'Approved {duration} by {name}'**
  String overtimeApprovedBy(String duration, String name);

  /// No description provided for @approveOvertime.
  ///
  /// In en, this message translates to:
  /// **'Approve overtime'**
  String get approveOvertime;

  /// No description provided for @overtimeRecorded.
  ///
  /// In en, this message translates to:
  /// **'Recorded: {duration} ({from} – {to})'**
  String overtimeRecorded(String duration, String from, String to);

  /// No description provided for @overtimeToApprove.
  ///
  /// In en, this message translates to:
  /// **'Overtime to approve ({count})'**
  String overtimeToApprove(int count);

  /// No description provided for @overtimeApprovedMinutes.
  ///
  /// In en, this message translates to:
  /// **'Approved overtime'**
  String get overtimeApprovedMinutes;

  /// No description provided for @rejectOvertime.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get rejectOvertime;

  /// No description provided for @overtimeRejectedText.
  ///
  /// In en, this message translates to:
  /// **'Overtime not approved'**
  String get overtimeRejectedText;

  /// No description provided for @overtimeRejectedBy.
  ///
  /// In en, this message translates to:
  /// **'Not approved by {name}'**
  String overtimeRejectedBy(String name);

  /// No description provided for @overtimeRejectHelp.
  ///
  /// In en, this message translates to:
  /// **'Rejecting counts none of this overtime. To count part of it, change the time and approve instead.'**
  String get overtimeRejectHelp;

  /// No description provided for @settingDriveHomeGrace.
  ///
  /// In en, this message translates to:
  /// **'Drive home after work (drivers)'**
  String get settingDriveHomeGrace;

  /// No description provided for @settingDriveHomeGraceHelp.
  ///
  /// In en, this message translates to:
  /// **'A driver still driving when the work day ends who gets home within this time is driving home: no overtime. At a work site or home at the end: no overtime. Arriving at a work site after the end, or home later than this, counts as overtime from the end.'**
  String get settingDriveHomeGraceHelp;

  /// No description provided for @setHomeLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Set your home location'**
  String get setHomeLocationTitle;

  /// No description provided for @setHomeLocationText.
  ///
  /// In en, this message translates to:
  /// **'Needed for your overtime: the drive home after work isn\'t overtime. At home, tap \"Use my location\", or pick it on the map. Once saved, only your manager can change it.'**
  String get setHomeLocationText;

  /// No description provided for @homeLocationSaved.
  ///
  /// In en, this message translates to:
  /// **'Home location saved'**
  String get homeLocationSaved;

  /// No description provided for @checkOutArrivedHome.
  ///
  /// In en, this message translates to:
  /// **'arrived home (driving overtime)'**
  String get checkOutArrivedHome;

  /// No description provided for @checkOutArrivedSite.
  ///
  /// In en, this message translates to:
  /// **'arrived at the work site (driving overtime)'**
  String get checkOutArrivedSite;

  /// No description provided for @checkOutOvertimeCap.
  ///
  /// In en, this message translates to:
  /// **'overtime limit reached'**
  String get checkOutOvertimeCap;

  /// No description provided for @homeLocation.
  ///
  /// In en, this message translates to:
  /// **'Home location'**
  String get homeLocation;

  /// No description provided for @homeLocationHelp.
  ///
  /// In en, this message translates to:
  /// **'A driver\'s overtime ends when they arrive here or at a work site; getting home soon after the end of the work day is the drive home, not overtime.'**
  String get homeLocationHelp;

  /// No description provided for @homeLocationNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get homeLocationNotSet;

  /// No description provided for @notifOvertimeAsk.
  ///
  /// In en, this message translates to:
  /// **'Your shift ended at {time} and you\'re still at {site}. Working overtime? Tap to start it.'**
  String notifOvertimeAsk(String time, String site);

  /// No description provided for @notifOvertimeAskReminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder: your shift ended at {time}. Working overtime? Tap to start it.'**
  String notifOvertimeAskReminder(String time);

  /// No description provided for @notifOvertimeConfirmed.
  ///
  /// In en, this message translates to:
  /// **'{name} started overtime{site} (from {time}) – approve it on the Attendance page'**
  String notifOvertimeConfirmed(String name, String site, String time);

  /// No description provided for @notifDriveOvertime.
  ///
  /// In en, this message translates to:
  /// **'{name} is still driving after the end of the shift ({time}) – overtime started'**
  String notifDriveOvertime(String name, String time);

  /// No description provided for @notifDriveOvertimeSelf.
  ///
  /// In en, this message translates to:
  /// **'Your shift ended at {time} while you\'re on the road – overtime started. It ends when you arrive home or at the work site.'**
  String notifDriveOvertimeSelf(String time);

  /// No description provided for @renewalOperatingCard.
  ///
  /// In en, this message translates to:
  /// **'Operating card (work permit)'**
  String get renewalOperatingCard;

  /// No description provided for @oilChange.
  ///
  /// In en, this message translates to:
  /// **'Oil change'**
  String get oilChange;

  /// No description provided for @oilIntervalKm.
  ///
  /// In en, this message translates to:
  /// **'Oil change every (km, optional)'**
  String get oilIntervalKm;

  /// No description provided for @oilEvery.
  ///
  /// In en, this message translates to:
  /// **'Every {km} km'**
  String oilEvery(String km);

  /// No description provided for @oilNextAt.
  ///
  /// In en, this message translates to:
  /// **'Next at {km} km'**
  String oilNextAt(String km);

  /// No description provided for @oilLastChange.
  ///
  /// In en, this message translates to:
  /// **'Last changed at {km} km on {date}'**
  String oilLastChange(String km, String date);

  /// No description provided for @oilKmLeft.
  ///
  /// In en, this message translates to:
  /// **'{km} km left'**
  String oilKmLeft(String km);

  /// No description provided for @oilOverdue.
  ///
  /// In en, this message translates to:
  /// **'Due – {km} km over'**
  String oilOverdue(String km);

  /// No description provided for @oilNoChangeYet.
  ///
  /// In en, this message translates to:
  /// **'No oil change recorded'**
  String get oilNoChangeYet;

  /// No description provided for @oilNotTracked.
  ///
  /// In en, this message translates to:
  /// **'Set how often the oil is changed (in km) and the GM, sales manager and logistics manager are reminded before it\'s due.'**
  String get oilNotTracked;

  /// No description provided for @setOilInterval.
  ///
  /// In en, this message translates to:
  /// **'Set interval'**
  String get setOilInterval;

  /// No description provided for @recordOilChange.
  ///
  /// In en, this message translates to:
  /// **'Oil changed'**
  String get recordOilChange;

  /// No description provided for @recordOilChangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Record oil change'**
  String get recordOilChangeTitle;

  /// No description provided for @deleteOilChangeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove the oil change at {km} km? Its odometer reading stays.'**
  String deleteOilChangeConfirm(String km);

  /// No description provided for @notifVehicleOilDueSoon.
  ///
  /// In en, this message translates to:
  /// **'{vehicle}: oil change due in {km} km (at {at} km)'**
  String notifVehicleOilDueSoon(String vehicle, int km, String at);

  /// No description provided for @notifVehicleOilDue.
  ///
  /// In en, this message translates to:
  /// **'{vehicle}: oil change is due (was due at {at} km)'**
  String notifVehicleOilDue(String vehicle, String at);

  /// No description provided for @settingOilDueSoon.
  ///
  /// In en, this message translates to:
  /// **'Oil change reminder'**
  String get settingOilDueSoon;

  /// No description provided for @settingOilDueSoonHelp.
  ///
  /// In en, this message translates to:
  /// **'The GM, sales manager and logistics manager are reminded this many km before a vehicle\'s oil change is due (estimated from the last reading and its drivers\' GPS km), and again when it\'s due; it stays on their Home until the change is recorded.'**
  String get settingOilDueSoonHelp;

  /// No description provided for @lastOilChangeKm.
  ///
  /// In en, this message translates to:
  /// **'Last oil change at (km, optional)'**
  String get lastOilChangeKm;

  /// No description provided for @lastOilChangeDay.
  ///
  /// In en, this message translates to:
  /// **'Day of the last oil change'**
  String get lastOilChangeDay;

  /// No description provided for @oilOdometerHelp.
  ///
  /// In en, this message translates to:
  /// **'The app estimates ≈ {km} km now. Enter what the odometer shows: if it\'s different, your number becomes the car\'s km.'**
  String oilOdometerHelp(String km);

  /// No description provided for @oilOdometerHelpNoEstimate.
  ///
  /// In en, this message translates to:
  /// **'Enter what the odometer shows; it also becomes the car\'s km.'**
  String get oilOdometerHelpNoEstimate;

  /// No description provided for @oilMileageCorrected.
  ///
  /// In en, this message translates to:
  /// **'Mileage corrected to {km} km (the estimate was {estimate} km)'**
  String oilMileageCorrected(String km, String estimate);

  /// No description provided for @arrivedByGps.
  ///
  /// In en, this message translates to:
  /// **'Counted from the arrival at the site (GPS) · Check in pressed at {time}'**
  String arrivedByGps(String time);

  /// No description provided for @atSiteNotCheckedInTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re at the work site'**
  String get atSiteNotCheckedInTitle;

  /// No description provided for @atSiteNotCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'You\'re at {site} but not checked in. Check in now.'**
  String atSiteNotCheckedIn(String site);

  /// No description provided for @notifAtSite.
  ///
  /// In en, this message translates to:
  /// **'You\'re at {site} since {time} but not checked in – check in'**
  String notifAtSite(String site, String time);

  /// No description provided for @earlyCheckoutsTab.
  ///
  /// In en, this message translates to:
  /// **'Leaving early'**
  String get earlyCheckoutsTab;

  /// No description provided for @noEarlyCheckouts.
  ///
  /// In en, this message translates to:
  /// **'No requests to leave early'**
  String get noEarlyCheckouts;

  /// No description provided for @approvedByName.
  ///
  /// In en, this message translates to:
  /// **'Approved by {name}'**
  String approvedByName(String name);

  /// No description provided for @rejectedByName.
  ///
  /// In en, this message translates to:
  /// **'Rejected by {name}'**
  String rejectedByName(String name);

  /// No description provided for @yourTurn.
  ///
  /// In en, this message translates to:
  /// **'Your turn'**
  String get yourTurn;

  /// No description provided for @calIn.
  ///
  /// In en, this message translates to:
  /// **'In'**
  String get calIn;

  /// No description provided for @calOut.
  ///
  /// In en, this message translates to:
  /// **'Out'**
  String get calOut;

  /// No description provided for @calWorked.
  ///
  /// In en, this message translates to:
  /// **'Worked'**
  String get calWorked;

  /// No description provided for @calAway.
  ///
  /// In en, this message translates to:
  /// **'Away'**
  String get calAway;

  /// No description provided for @calLate.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get calLate;

  /// No description provided for @calOvertime.
  ///
  /// In en, this message translates to:
  /// **'Overtime'**
  String get calOvertime;

  /// No description provided for @calAfterHours.
  ///
  /// In en, this message translates to:
  /// **'After hours'**
  String get calAfterHours;

  /// No description provided for @calMore.
  ///
  /// In en, this message translates to:
  /// **'+{n} more'**
  String calMore(int n);

  /// No description provided for @calOvertimeWaiting.
  ///
  /// In en, this message translates to:
  /// **'waiting'**
  String get calOvertimeWaiting;

  /// No description provided for @calOvertimeApproved.
  ///
  /// In en, this message translates to:
  /// **'approved {time}'**
  String calOvertimeApproved(String time);

  /// No description provided for @personMonthEmpty.
  ///
  /// In en, this message translates to:
  /// **'No attendance for this person in this month.'**
  String get personMonthEmpty;

  /// No description provided for @leaveDocumentLater.
  ///
  /// In en, this message translates to:
  /// **'{document} – attach it now or later'**
  String leaveDocumentLater(String document);

  /// No description provided for @leaveTicketMissingMine.
  ///
  /// In en, this message translates to:
  /// **'Attach your {document} when you have it.'**
  String leaveTicketMissingMine(String document);

  /// No description provided for @leaveTicketMissing.
  ///
  /// In en, this message translates to:
  /// **'{document} not attached yet.'**
  String leaveTicketMissing(String document);

  /// No description provided for @documentCanComeLater.
  ///
  /// In en, this message translates to:
  /// **'Can be attached later (not needed to send or approve)'**
  String get documentCanComeLater;

  /// No description provided for @departureTimeOn.
  ///
  /// In en, this message translates to:
  /// **'Departure time on {day}'**
  String departureTimeOn(String day);

  /// No description provided for @setTime.
  ///
  /// In en, this message translates to:
  /// **'Set time'**
  String get setTime;

  /// No description provided for @departureHelp.
  ///
  /// In en, this message translates to:
  /// **'Leaving after work ({end}) on {day}? That day isn\'t counted.'**
  String departureHelp(String end, String day);

  /// No description provided for @departureAfterWork.
  ///
  /// In en, this message translates to:
  /// **'After working hours – the leave counts from {start}'**
  String departureAfterWork(String start);

  /// No description provided for @departureDuringWork.
  ///
  /// In en, this message translates to:
  /// **'During working hours – {day} counts as a leave day'**
  String departureDuringWork(String day);

  /// No description provided for @travelAfterWorkOn.
  ///
  /// In en, this message translates to:
  /// **'Departs {day} at {time}'**
  String travelAfterWorkOn(String day, String time);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
