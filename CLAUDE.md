# WPC CRM — field sales visit tracker

Flutter app (Android/iOS) + Flutter Web dashboard, one codebase. Logo: `assets/images/Regular.png` (wide WPC wordmark); app icon from its W mark in `assets/icon/`, regenerate with `dart run flutter_launcher_icons`. Localization: English + Arabic (RTL) only, via ARB files.

## Firebase project — WARNING
`business-manager-a8c65` belongs to a DIFFERENT app. Never deploy to it or write data there. It was picked by mistake in `flutterfire configure` (Oct 2026) and our Firestore rules were deployed over its rules once. This app's project is `wpc-crm-a9247` (has RTDB). App ID / bundle ID: `com.wisora.wpc` on Android and iOS.

## Decisions (do not re-research)
- Backend: Firebase — Auth (email/password), Firestore, Realtime Database (live locations only), Storage (attachments).
- Roles stored in `users/{uid}.role`: `sales_exec` | `kam` | `sales_manager` | `gm`. Enforced in security rules via `get()` on the user doc.
- KAM owns no clients; supervises sales execs where `users.kamId == kam uid`.
- State: Riverpod. Routing: go_router (role-based redirects). Maps: google_maps_flutter (switched from flutter_map/OSM 2026-10-13 for better Saudi business coverage). Markers drawn as images by `MarkerIcons` in `core/map_controls.dart`. API keys: Android `MAPS_API_KEY` in `android/local.properties`, iOS `GMSApiKey` in `ios/Runner/Info.plist`, web script tag in `web/index.html` (one restricted key per platform).
- Location: geolocator with Android foreground service + iOS "Always". Tracking is 24/7 (user decision). Send location every 2 minutes to RTDB (user decision; team is 7 now, max ~11). Keep RTDB (user decision) and use it for honest live data: onDisconnect presence (online/offline), updatedAt + accuracy shown on the live map, and flag mocked GPS (geolocator `Position.isMocked`).
- Client import: Excel/CSV parsed client-side on web dashboard, match by Tax ID (VAT), else normalized name; same-VAT rows merge into one client (other names kept as `aliases`). Preview diff before commit. Contacts without coordinates are imported too (lat/lng null, grey, "No location") and appear on the map once a location is set in-app or a later import resolves their pin. Logic in `lib/features/import/` (unit tested). Second importer `/import/locations`: sheet of name (or Tax ID) + location (link, "lat, lng" text, or Latitude/Longitude columns) updates locations of existing clients only; matches name or aliases; fills missing locations unless "replace existing" is ticked. Optional "add unmatched rows as new clients" (one per name; AREA column → city; pivot header salesperson → assignedTo via odooName; category B).
- Marker colour (`features/clients/visit_rules.dart`): client `category` A/B/C (default B) + days since last visit → green/yellow/red; never visited = red. Thresholds in Firestore `settings/visitRules` (defaults A 7/14, B 14/28, C 30/45), edited by GM/manager at More → Visit frequency. Blue = on today's plan (approved, not done). Markers show the category letter. Odoo import reads an optional "Category" column; otherwise new clients get the chosen default.

## Odoo export (Contact (res.partner).xlsx, ~2,540 rows)
Columns: Company Name, Complete Name, Is a Company, Google Pin, Total Payable, Total Receivable, Currency, Account Receivable, Account Payable, Contact Address Complete, Mobile, Activities, City, Tags, Company.
- Location is only a `Google Pin` short link (maps.app.goo.gl, ~606 rows). It redirects to a URL containing `!3d<lat>!4d<lng>` (use these, not the `@` viewport). Browsers can't follow it (CORS): on phones the app follows the redirects itself (`import_service._resolveOnDevice`); only the web dashboard needs the `resolvePins` Cloud Function.
- Export also has Phone, Salesperson, Street, State, Country, Tax ID. Odoo has no exportable ID; Tax ID is the key (~60% of pinned rows have one).
- Pin formats: maps.app.goo.gl / goo.gl / share.google short links (need `resolvePins` Cloud Function in `functions/`), or full URLs with coords (parsed in app). share.google links lead to a search page and can't be resolved.
- Salesperson → app user via `users.odooName` (exact Odoo text, e.g. "Sami Mansour @ Sales"). Import only fills an empty assignment. Saving a sales exec with an odooName also assigns their unassigned clients (`UsersRepository._assignOdooClients`).
- Odoo webhook / API connection: ON HOLD until management approves. Do not connect to Odoo. A webhook (Odoo automation rule → Cloud Function) is the planned live-sync path; its payload includes the record id.
- Rows with empty Company Name and Is a Company = 1 are companies; child contacts have Company Name set.

## Clients editing
Sales execs edit name/contact/address/location/notes of their own clients and add clients for themselves (`source: 'manual'`, duplicate warning by name/alias/VAT); category & assignment are KAM/manager only. Odoo import also stores Company Name (as legalName), Street, State, Country, Total Receivable/Payable, Currency, and optional "Email"/"Contact Person" columns. Odoo child contacts ("Parent, Person", Is a Company = false) attach to the parent as `contacts` [{name, phone, mobile}] instead of becoming clients. Excel gives booleans as "true"/"false".

## Rules and setup
- `firestore.rules`, `database.rules.json`, `storage.rules`. RTDB rules read roles from RTDB `roles/{uid}`, mirrored by `UsersRepository._save`.
- New users are created by admins in-app via a secondary FirebaseApp. The first GM is bootstrapped by hand in the console.

## Data model
- Firestore `users/{uid}`: name, email, phone, role, kamId, active, odooName, monthlyTarget
- `clients/{id}`: contactPerson, email, notes, legalName, street, state, country, receivable, payable, currency, contacts[], createdBy (manual), vat, nameKey, name, aliases, phone, mobile, address, city, tags, odooSalesperson, googlePin, lat, lng, assignedTo, category, lastVisitAt, createdAt, updatedAt, source ('import'|'manual'), importBatchId
- `clients/{id}/attachments/{id}` and `visits/{id}/attachments/{id}`: storagePath, url, fileName, contentType, size, uploadedBy, createdAt (files in Storage `{clients|visits}/{id}/{ts}_{name}`, `lib/features/attachments/`)
- `users/{uid}/devices/{fcmToken}`: platform, lang, updatedAt (push tokens, `features/notifications/push.dart`)
- `visits/{id}`: clientId, clientName, salesExecId (visitor: exec or KAM), checkedInAt, checkInLat/Lng, accuracy, mocked, distanceMeters, notes, status, kamId?, kamMarkedAt?
- `visits/{id}/comments/{id}`: authorId, body, createdAt
- `tasks/{id}`: ownerId, date ('yyyy-MM-dd'), month, clientId?, clientName?, title, createdBy, approval (pending|approved|rejected), approvedBy, done, doneAt, visitId
- `notifications/{id}`: toId, fromId, type (planSubmitted|planApproved|planRejected|planChanged), ownerId, date, count, read, createdAt
- `settings/visitRules`: {A|B|C: {green, yellow}}
- `import_batches/{id}`: fileName, importedBy, added, updated, unchanged, skipped, createdAt
- RTDB `live_locations/{uid}`: lat, lng, accuracy, speed, mocked, fixAt, updatedAt (overwritten); `presence/{uid}`: online, lastSeen, gpsOn, permission (onDisconnect sets offline); `location_history/{uid}/{day}/{push}`: lat, lng, accuracy, mocked, t

## Billing
Blaze since 2026-10-13. Cloud Functions (`functions/index.js`): `resolvePins` (web import short links), `sendPush` (Firestore `notifications` create → FCM to the recipient's devices, EN/AR text duplicated from the ARB files). Storage holds attachments.

## Status (end of day 2026-10-12)
Phases 1–4 built and tested on the Android emulator (KAM, sales exec and GM accounts); live tracking confirmed working by the user. 29 unit tests pass (`flutter test`), `flutter analyze` clean.

Built:
1. Foundation: login, roles, EN/AR + RTL, user management (GM-only delete), Firebase project `wpc-crm-a9247`.
2. Clients: Odoo import (VAT/name match, child contacts → `contacts`, legal name, address parts, balances, optional Category/Email/Contact Person columns), locations-only import (also Odoo pivot sheets), short Google links resolved on-device, list + map with A/B/C category colours (green/yellow/red, blue = planned today), client page with call/WhatsApp/directions, add/edit client (sales execs: own clients, contact/location/notes only).
3. Visits: GPS check-in with far/fake-GPS flags, visit list/detail, comments, KAM "I was there". Photos/files on clients and visits (also picked at check-in; supervisors delete).
4. Live tracking every 2 min (Android foreground service; iOS in-app), presence, live map.
4b. Home = statistics (`features/home/home_screen.dart`, `stats.dart`): period filter, KPI tiles, target bars / target-pace line (fl_chart), approvals, team plans, today's plan. Bottom tabs Home · Clients · Visits · More. Daily plans (`features/plan/`): multi-select, approval by KAM, KAM edits/clear, share, plan map; in-app notifications (`features/notifications/`). Monthly visit target per user; visit frequency per category in More → Visit frequency.

Pending / next:
- User must deploy latest rules: `firebase deploy --only firestore:rules --project wpc-crm-a9247` (client add/edit by execs, notifications, settings). Confirm before running it yourself.
- Re-import the Odoo file to fill new client fields (legal name, contacts, balances, address parts); 23 old child-contact clients remain as separate clients — offer cleanup.
- Open questions to the user: restrict account balances to KAM/managers? Remove the old child-contact clients?
- Blaze (2026-10-13): attachments + FCM push code done. Needs: Storage bucket created in console, deploy `firebase deploy --only functions,firestore:rules,storage --project wpc-crm-a9247`, iOS Push Notifications capability in Xcode + APNs key uploaded in Firebase console. Test on device.
- Field-test tracking on the Xiaomi for a full day (battery saver / autostart).
- Phase 5 web dashboard, Phase 6 hardening (offline visit notes, release builds, Odoo webhook when approved).
- Emulator testing: after larger changes do a full restart, not hot reload (stale objects caused false errors). Test data: 2 items in Eddy's plan for 2026-10-12.

## Phases
1. Foundation: Firebase setup, rules, auth, l10n/RTL, role routing
2. Clients: importer, list + filter by sales member, details, edit, map markers
3. Visits: DONE basic check-in (GPS + notes, `lib/features/visits/`; >300 m and fake GPS are flagged, not blocked; can set client location when missing). DONE: Visits list (`/visits`), visit detail with comments; KAM marks "I was there" after the fact (kamId + kamMarkedAt, shows hours late) — no planned visits (user decision); KAM can also visit alone. Attachments done (`features/attachments/`)
4. Live tracking: BUILT (`lib/features/tracking/`). Android = flutter_background_service foreground service (survives app close, restarts on boot), iOS = in-app background location (stops on force-quit). Tracks sales_exec + KAM. Home `TrackingCard` lists permission issues with Fix buttons. Live map `/live` (KAM sees own team). Also writes RTDB `location_history/{uid}/{yyyy-MM-dd}` for the dashboard. Needs field testing on Xiaomi.
4b. Home redesign: DONE. Bottom tabs Home · Clients · Visits · More (StatefulShellRoute in `core/router.dart`). Home = personal dashboard (`features/home/dashboard_cards.dart`): today's plan, month progress vs `users.monthlyTarget`, approvals + team cards for KAM/managers. Daily plans in Firestore `tasks` (`features/plan/`): client visit (auto-done when a visit to that client is saved that day) or free task; exec's own tasks `pending` until a KAM/manager approves; KAM-added tasks auto-approved. Visits now carry `month` ('yyyy-MM') for month queries without composite indexes. Plan add sheet multi-selects clients (batch save); saving notifies the reviewer (KAM, else sales manager + GM) via in-app `notifications` (bell on Home, `features/notifications/`); approve/reject/KAM edits notify the owner. Plan can be shared as text (share_plus, Google Maps links + route) and shown on a map (`/plan/:uid/map?date=`). Phone push: `sendPush` Cloud Function → FCM; tapping opens /notifications.
5. Web dashboard: visits per person, coverage %, unvisited, new clients per import
6. Hardening: offline notes, notifications, release builds, optional Odoo sync
