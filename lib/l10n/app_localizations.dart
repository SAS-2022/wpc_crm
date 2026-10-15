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
  /// **'They will lose access to the app immediately. Their clients become unassigned, and their past visits are kept. To reuse the same email later, also delete the account in Firebase Console → Authentication.'**
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
  /// **'Open client'**
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

  /// No description provided for @routeHistory.
  ///
  /// In en, this message translates to:
  /// **'Route history'**
  String get routeHistory;

  /// No description provided for @teamPerformance.
  ///
  /// In en, this message translates to:
  /// **'Team performance'**
  String get teamPerformance;

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
