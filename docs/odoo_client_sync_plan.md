# Odoo ↔ app client sync — plan (agreed 2026-10-22, waiting for the Odoo setup)

Status: plan accepted by the user; nothing built. Start once the Odoo side (bot user, API key, test database, answers below) is ready.

## Known setup (2026-10-22)
- **Odoo Online** (SaaS), **18.0+e** (Enterprise), **Custom plan** (includes external API, Studio, multi-company).
- Database name `wood-panels-co`; addresses `https://wood-panels-co.odoo.com` and the custom domain `https://www.woodpanelsco.com/odoo` (behind Cloudflare). Server calls use the `odoo.com` address so Cloudflare bot protection can't block Cloud Functions; the webhook comes from Odoo itself.
- Confirmed from public, login-free endpoints only (`/web/webclient/version_info`, `/web/database/list`).
- API on 18.0: external JSON-RPC / XML-RPC with the bot user's API key (JSON-2 arrives with Odoo 19; the old API is removed in Odoo 22 — keep the Odoo client code in one module so switching is small). Odoo Online upgrades databases to newer versions over time, so expect that switch.
- Odoo Online: no custom Python modules, only Studio customisations; webhooks via Automation Rules → "Send Webhook Notification" (available in 18). Acceptable use ≈ 1 call/s, no parallel calls.

## Testing safety
- Developer mode (with or without assets) only changes the UI: safe.
- NEVER click "Load demo data" on the live database (fake records, no undo).
- Build and test on a **duplicate** of the database (odoo.com → My Databases → Duplicate, marked for testing so emails and scheduled actions are off). Duplicates are temporary: recreate when it expires.
- On the live database before go-live: only developer mode (to read field names), the bot user and its API key, and a read-only dry run. The live webhook rule is created on go-live day.
- The bot user has no delete right.

## Architecture
- Only Cloud Functions talk to Odoo (API key in Firebase Secret Manager). Phones / web never do.
- Odoo → app: automation rule on `res.partner` (create / edit) → "Send Webhook Notification" → HTTPS function `odooWebhook` (secret token in the URL, since the webhook UI sends no custom headers). The function re-reads the partner through the API (payload not trusted) and upserts the client by `odooId`.
- App → Odoo: Firestore trigger on client create (after the existing `findClientDuplicates` check, optionally after KAM/manager approval) → `pushClientToOdoo` creates the partner and writes `odooId` back.
- Nightly `odooReconcile`: `search_read` partners with `write_date` > last sync to catch missed webhooks.

## Step 0: link existing clients (before go-live)
Read all Odoo partners; match app clients by Tax ID → name/aliases → CR → phone; save `odooId` on confident matches; ambiguous / unmatched on both sides go to a manager review screen. Afterwards match only by `odooId`.

## Safeguards
- Duplicates from the app: app duplicate check + function searches Odoo (VAT / CR / name / phone) and links instead of creating.
- Duplicates from Odoo: a new partner matching an unlinked app client is linked; uncertain → held as "Possible match in Odoo" for a manager, not created.
- Stale overwrites: compare `write_date` / `updatedAt` with the last synced values before applying a change.
- Loops: automation rule domain excludes writes by the bot user; app trigger ignores writes with `syncSource: 'odoo'`.
- Rejected data: validate in the app first (VAT 15 digits 3…3, required fields); Odoo errors stored in `odooSync {state: pending|synced|error, error, at}`, shown on the client page with Retry + a managers' list of failed ones.
- Idempotent retries: `odooId` set → update, never create again.
- Rate limit: one queue, one call at a time (`maxInstances: 1`).
- Dry-run mode on production; on/off switch per direction in App settings; `odoo_sync_log` audit collection.

## Limitations
- Bot user likely takes a licence seat.
- API keys expire (≤3 months) → alert before expiry.
- Near-real-time (seconds), not guaranteed; offline phone creations sync when back online.
- Deletes, archives and merges are never mirrored automatically (user decision); they appear in a sync report.
- Child contacts: Odoo → app `contacts` in phase 1 only.
- Every app salesperson needs an Odoo user for the salesperson sync to work.

## Decisions (user, 2026-10-22)
1. **Edits: latest edit wins, both ways**, for every field both systems have (name, phone, address, VAT, …). Whoever edits pushes the change to the other side. Guard against stale overwrites: each side remembers the last synced `write_date` / `updatedAt`, and a late webhook or retry older than the other side's last change is ignored. Fields only one side has stay there (balances only in Odoo; category, tags, status, notes, extra locations only in the app; main location ↔ Google Pin).
2. **No approval step**: app clients go to Odoo right away. **Never create a duplicate**: before creating in Odoo the function searches Odoo (VAT, CR, name / alias, phone); a match → link (`odooId`) instead of creating. Same for Odoo → app: a new Odoo contact matching an unlinked app client is linked, not added. An uncertain match (similar name only) is NOT created on the other side: it waits as "Possible match in Odoo" for a manager to link or confirm as new.
3. **Salesperson syncs both ways**: app users get `odooUserId` (Odoo `res.users` id, replaces matching the `odooName` text); Odoo `user_id` ↔ app `assignedTo`. App transfer → Odoo salesperson updated; Odoo change → app transfer (logged in `transfers`, owners notified as usual). An Odoo salesperson with no app user → unassigned in the app; an app owner with no Odoo user → Odoo salesperson left unchanged and flagged.
4. **Wood Panels company only** (not the service center): sync only Odoo contacts of the Wood Panels company; app-created clients are created in it. Contacts shared between companies (no company set): see question 9.
5. **No automated deletes** in either direction. Deletes (rare) are done by hand on both sides. Archive in Odoo, deletes and merges on either side → listed in a sync report for a manager to act on; nothing is removed automatically. Client status (Closed / Not working) stays app-only.

## Build order
1. Connect to the test duplicate, read fields (`fields_get`). 2. Linking job + review report. 3. Odoo → app. 4. App → Odoo. 5. Dry run on production. 6. Switch on (Excel import stays as backup).

## Setup checklist — our Odoo admin can do these without Odoo (final, 2026-10-22)
1. odoo.com → My Databases → `wood-panels-co` → Duplicate, tick "for testing"; send the duplicate's address and database name.
2. Settings → Apps: check "Automation Rules" is installed (install it on the duplicate if not).
3. Check every sales exec / KAM in the app has an Odoo user (needed for the salesperson sync); list any who don't.
4. Create internal user "WPC CRM Sync" on the duplicate (and later on live): Contacts = User with create / edit, Sales = read; log in as that user → Preferences → Account Security → New API Key (3 months). Share the key only by typing it into the command I run (never in chat or email).
5. Developer mode on, open a contact, hover each custom field (Google Pin, Category, CR / Company ID, Area, …) and note the technical name — or I read them with `fields_get` once the key exists.

## Questions for Odoo / the implementation partner (final, 2026-10-22)
Already known, not asked: Odoo Online, 18.0+e, Custom plan, database `wood-panels-co`, webhooks available.

### Plan and limits
1. Does our Custom plan have any extra limit on external API calls beyond the acceptable-use policy (~1 call per second)?
2. When will our database be upgraded from 18.0 to a newer version (19+), and will we be told in advance?
3. Does the "WPC CRM Sync" internal user need a paid licence seat?

### Test database
4. How long does a duplicated test database stay available, and can we keep one longer while we build?
5. Does the duplicate keep all Studio customisations and automations, with emails, webhooks and scheduled actions switched off?

### Contacts customisations
6. Were Contacts customised with Studio or by a partner (extra fields, required fields, automations, server actions)? Please list the custom fields with technical names and the automations that run on create / edit.
7. Do any of those automations assign salespersons, send emails or create other records when a contact is created? Should they run for contacts created by the API?
8. Is VAT validation (VIES / format check) on for Saudi VAT numbers, and is unique VAT enforced?
9. We have two companies (Wood Panels and the service center) and will sync Wood Panels contacts only. Is the Company field set on every contact, or are some contacts shared (no company)? How do we tell which shared contacts are Wood Panels customers?
10. Can VAT and CR number be made required and unique for companies from now on?

### Webhook
11. Does "Send Webhook Notification" retry when our server is down, and where are failed calls logged?
12. Can one automation rule fire only when selected fields change and skip changes made by one user (our bot), or do we need a domain / trigger-fields setup? Any recommended setup?
13. Is there a limit on how many webhook calls Odoo Online sends (for example during a bulk edit of hundreds of contacts)?

### Contact
14. Who is our technical contact for API and webhook questions during testing, and how fast can they respond?
