# Subidha360 backend

Go modular monolith for the Subidha360 services marketplace: OTP login, jobs, bids and an escrow wallet.

## Run locally

You need Go, MongoDB running as a replica set, and Redis. `docker-compose.yml` starts both services.

```powershell
docker compose up -d
$env:APP_ENV = "development"
$env:JWT_SECRET = "replace-with-at-least-32-random-characters"
go run ./cmd/api
```

Check it with `GET http://localhost:8080/healthz`. See `.env.example` for all settings.

In development, OTP codes are written to the server log.

## Test

Unit tests need nothing extra. Integration tests in `internal/app` run only when `TEST_MONGO_URI` points at a replica set, and are skipped otherwise. Redis is simulated in-process.

```powershell
$env:TEST_MONGO_URI = "mongodb://localhost:27017/?replicaSet=rs0"
go test ./...
```

To check that `MONGO_URI` supports everything the app needs (replica set, indexes, transactions, geo searches), run this. It uses a temporary database and drops it afterwards:

```powershell
$env:MONGO_LIVE_TEST = "1"
go test ./internal/platform/mongodb/ -run TestLiveDatabase -v
```

## Layout

| Path | Purpose |
| --- | --- |
| `cmd/api` | Server entry point |
| `internal/app` | Wires modules together; end-to-end tests |
| `internal/auth` | OTP, JWT sessions, profile endpoints |
| `internal/user` | User storage and provider geo-matching |
| `internal/job` | Job state machine, cancellation, bid-window timeouts |
| `internal/bid` | Placing and accepting bids |
| `internal/wallet` | Double-entry ledger and escrow |
| `internal/notify` | Notification outbox, FCM push, SMS fallback, inbox |
| `internal/sms` | Sparrow SMS client |
| `internal/catalog` | Service catalogue and guide prices |
| `internal/review` | Ratings and provider profiles |
| `internal/chat` | Messages on a job |
| `internal/geo` | GeoJSON shapes |
| `internal/platform` | MongoDB and HTTP helpers |

## API

Send `Authorization: Bearer <access_token>` on everything except the first three routes and `/healthz`. Money is always integer paisa.

| Method and path | Purpose |
| --- | --- |
| `POST /v1/auth/otp/request` | Send a login code |
| `POST /v1/auth/otp/verify` | Log in, creating the user on first use |
| `POST /v1/auth/refresh` | Swap a refresh token for a new pair (each works once) |
| `POST /v1/auth/logout` | Revoke the access and refresh tokens |
| `GET /v1/me` | Current user |
| `PUT /v1/me/provider-profile` | Set categories and a `radius` or `polygon` service area |
| `PUT /v1/me/online` | Toggle receiving broadcasts |
| `GET /v1/wallet` | Balance and recent transactions |
| `POST /v1/dev/wallet/top-up` | Add test funds (development only) |
| `POST /v1/jobs` | Create a job and broadcast it |
| `GET /v1/jobs` | Jobs you created |
| `GET /v1/jobs/feed` | Open jobs broadcast to you |
| `GET /v1/jobs/{id}` | One job |
| `POST /v1/jobs/{id}/bids` | Place your bid |
| `GET /v1/jobs/{id}/bids` | All bids (seeker) or your own (provider) |
| `POST /v1/jobs/{id}/bids/{bidID}/accept` | Pick a winner and move funds to escrow |
| `POST /v1/jobs/{id}/start` | Provider begins work |
| `POST /v1/jobs/{id}/confirm` | Confirm completion; the second party's confirmation settles escrow |
| `POST /v1/jobs/{id}/cancel` | Cancel with a required `reason` |
| `POST /v1/jobs/{id}/dispute` | Stop auto-release and send the job to an admin |
| `GET /v1/catalog` | Public service catalogue with guide prices |
| `PUT /v1/me` | Set `display_name` |
| `GET /v1/jobs/assigned` | Jobs you won as a provider |
| `POST /v1/jobs/{id}/review` | Rate a completed job, once |
| `POST /v1/jobs/{id}/warranty-claim` | Claim on the guarantee within 30 days |
| `GET` and `POST /v1/jobs/{id}/messages` | Chat between the seeker and assigned provider |
| `POST /v1/jobs/{id}/photos` | Add a photo of the problem (raw image body, up to 4 per job, 5 MB each) |
| `GET` and `DELETE /v1/jobs/{id}/photos/{photoID}` | Read a photo, or let the seeker remove it |
| `POST /v1/jobs/{id}/reschedule` | Move the time, up to 3 times, until work starts |
| `PUT`, `GET` and `DELETE /v1/jobs/{id}/tracking` | Share, read or stop the assigned provider's live position |
| `GET /v1/me/favorites` | Your favourite providers |
| `PUT` and `DELETE /v1/me/favorites/{id}` | Add or remove a favourite |
| `GET /v1/providers/{id}` | A provider's public profile and reviews |
| `PUT /v1/me/devices` | Register a push `token` and `platform` (`android` or `ios`) |
| `DELETE /v1/me/devices` | Remove a push `token`; call before logout |
| `GET /v1/notifications` | Your latest notifications |

## Admin

The app has a back office at `/admin` (Profile > Admin dashboard). No API can
make someone an admin, so a stolen admin session can't create more. Grant it
from the command line, after the person has logged in once:

```powershell
go run ./cmd/admin -phone +9779812345678          # grant
go run ./cmd/admin -phone +9779812345678 -remove  # remove
go run ./cmd/admin -list
```

Every admin route checks the flag in the database on each request, so removing
an admin takes effect at once. Every change an admin makes is written to the
`admin_actions` audit log in the same transaction as the change itself.

Suspending an account logs the person out everywhere within one request, blocks
login and token refresh, withdraws their waiting bids and stops new jobs being
offered to them. Jobs they are already on stay open for an admin to settle.
Admins cannot be suspended; remove admin access first.

| Endpoint (all admin only) | Purpose |
| --- | --- |
| `GET /v1/admin/overview` | Counts, money, what needs attention, last 14 days |
| `GET /v1/admin/users?q=&filter=&page=` | Search people. Filters: `providers`, `unverified`, `seekers`, `suspended`, `admins` |
| `GET /v1/admin/users/{id}` | One person: profile, wallet, jobs, reviews, admin history |
| `POST /v1/admin/users/{id}/suspend` and `/unsuspend` | Lock or unlock an account, with a `reason` |
| `PUT /v1/admin/providers/{id}/verified` | Set the verified badge, with an optional `note` |
| `GET /v1/admin/jobs?q=&status=&page=` | Jobs. `status` is a job status, or `attention`, `open` or `active` |
| `GET /v1/admin/jobs/{id}` | The whole job: bids, chat, ledger, review, admin history |
| `POST /v1/admin/jobs/{id}/resolve-escrow` | Set `provider_percent` from 0 to 100, with a `note` |
| `POST /v1/admin/jobs/{id}/warranty-claim/close` | Close a claim with a `note` |
| `GET /v1/admin/escrow-reviews` and `/warranty-claims` | Older read-only queues, kept for scripts |
| `GET /v1/admin/payments?type=&q=&page=` | Ledger entries, newest first |
| `GET /v1/admin/money` | Where the money sits, and a check that the books balance |
| `GET /v1/admin/reports?from=&to=` | Daily activity, services and top providers (Nepal days, up to a year) |
| `GET /v1/admin/reports.csv?from=&to=` | The daily report as a spreadsheet |
| `GET /v1/admin/actions?target=&page=` | The audit log |

Admin pages show chat messages so staff can decide disputes. The privacy policy
must say so before launch.
## Provider tools

**Identity check.** A provider uploads photos of both sides of their
citizenship card, and optionally up to 5 skill certificates (photo or PDF),
then sends them for checking. An admin approves, which grants the Verified
badge, or rejects with a reason the provider sees. Documents can only be read
by their owner and admins. Changing a card photo after a decision clears the
check and the badge, so a badge can't outlive the documents behind it.

**Earnings and withdrawals.** Only verified providers can withdraw, at least
Rs 100, with one request waiting at a time. The money leaves the wallet at once
into a `payout:` ledger account. eSewa and Khalti merchant payouts aren't
connected, so an admin sends the money by hand and records the transfer
reference, or refuses and the money returns to the wallet.

**Working hours.** A provider can set weekly two-hour slots and days off. Jobs
booked for a set time are only offered to providers who work then; jobs wanted
as soon as possible reach everyone online. No schedule means any time.

**Past work.** Up to 12 photos with captions, shown on the provider's profile.

| Endpoint | Purpose |
| --- | --- |
| `GET`, `POST /v1/me/documents?kind=&label=` | List or upload a document (raw body, 5 MB). Kinds: `citizenship_front`, `citizenship_back`, `certificate` |
| `GET`, `DELETE /v1/me/documents/{id}` | Read or remove your document |
| `POST /v1/me/verification` | Send your documents for checking |
| `GET /v1/me/earnings` | Balance, money on hold, monthly totals, paid jobs and withdrawals |
| `POST /v1/me/withdrawals` | Ask to withdraw `amount_paisa` to a `destination` (`bank`, `esewa` or `khalti`) |
| `PUT`, `DELETE /v1/me/availability` | Set `weekly` slots and `days_off`, or clear them |
| `POST /v1/me/gallery?caption=`, `DELETE /v1/me/gallery/{id}` | Add or remove a past-work photo |
| `GET /v1/providers/{id}/gallery` and `/gallery/{photoID}` | A provider's photos |
| `GET /v1/admin/users/{id}/documents`, `GET /v1/admin/documents/{docID}` | Admins read documents |
| `POST /v1/admin/users/{id}/verification` | Admins `approve` a check, or reject it with a `reason` |
| `GET /v1/admin/withdrawals?status=` | Withdrawal requests |
| `POST /v1/admin/withdrawals/{id}/pay` and `/refuse` | Record as sent with the reference, or refuse with a reason, as `note` |

Identity documents are personal data. Before launch, the privacy policy must
say what is kept and for how long, and old documents need a deletion policy.

## Support, safety and the catalogue

**Support.** Anyone can write to the team from Help in the app, optionally
about one of their jobs. Admins answer from the Support inbox, and the person
gets a notification. Closing a conversation is audited; the person can still
reply, which reopens it. Each person can have 3 open conversations.

**Safety.** Either side of a job can report the other once per job. The chat
is scanned as messages are sent: a Nepali mobile number, or talk of cash,
eSewa or WhatsApp outside the app, raises an automatic flag once per sign,
sender and job. Messages are never blocked. Admins review flags on the Safety
page and record what they did. A person's admin page shows their flags,
disputes and cancellations.

**Catalogue and settings.** The service list lives in the `catalog` document,
saved from the built-in list on first run. Admins can edit, hide or add
services, change guide prices and category text, add Nepali names, and set
the helpline number. Each server reloads it every minute, so every instance
picks up edits. Categories are fixed in code, because each has its own icon
and photo in the app.

| Endpoint | Purpose |
| --- | --- |
| `GET /v1/settings` | Public site settings, such as the helpline |
| `GET`, `POST /v1/support/threads` | Your conversations, or start one (`topic`, `subject`, `body`, optional `job_id`) |
| `GET /v1/support/threads/{id}`, `POST .../messages` | Read or reply |
| `POST /v1/jobs/{id}/report` | Report the other party (`reason`, `details`) |
| `GET /v1/admin/support?status=`, `GET /v1/admin/support/{id}` | The inbox and one conversation |
| `POST /v1/admin/support/{id}/messages` and `/close` | Reply or close |
| `GET /v1/admin/flags?status=&person=`, `POST /v1/admin/flags/{id}/review` | Flags, and closing one with an `outcome` |
| `GET /v1/admin/catalog` | Every service, hidden ones too, and the settings |
| `PUT /v1/admin/catalog/services/{id}` | Add or change a service |
| `PUT /v1/admin/catalog/categories/{id}`, `PUT /v1/admin/settings` | Change category text, or the helpline |

## Running in production

`deploy/README.md` covers the server, HTTPS, backups and logs. Useful settings:
`LOG_FORMAT=json` for one JSON log line per event, `SITE_URL` for the sitemap,
and `TRUST_PROXY=1` only behind a proxy that sets `X-Forwarded-For`. Every
response carries an `X-Request-ID` that matches its log line. Back up with
`go run ./cmd/backup -out FOLDER`, and restore with `-restore FOLDER -db NAME`.

Page views are counted at `POST /v1/views` with only a day, a page and a
count; admins see them at `GET /v1/admin/traffic`. Logging in with
`terms_version` records which terms a person agreed to.

## Escrow rules

These fill gaps in the spec. The timings and commission are configurable (see `.env.example`); the 50% default split is `defaultProviderPercent` in `internal/job/service.go`.

| Situation | Outcome |
| --- | --- |
| Any completed payment | 10% commission on what the provider receives |
| Cancelled before work starts | Full refund to the seeker |
| Provider cancels mid-work | Full refund to the seeker |
| Seeker cancels mid-work | Held 72 hours for admin review, then split 50/50 if undecided |
| One party confirms completion | Auto-release to the provider after 72 hours |
| Dispute raised | Auto-release stops; the money waits for an admin, with no time limit |
| Cancelling after a confirmation | Refused; the remaining route is a dispute |
| Bids but no selection | `EXPIRED` 24 hours after the first bid; no money moves, no penalty review |

## Notifications

Messages are written to the `notifications` collection in the same transaction as the change they describe, then a worker delivers them every 5 seconds. Delivery is at-least-once, so the app should ignore a repeated `notification_id`.

- **Ordinary messages** (new bids, job broadcasts, work started) go by push. If that fails they stay in the inbox.
- **Critical messages** (bid won, completion warning, auto-release reminder, disputes, cancellations of assigned jobs, escrow decisions) fall back to SMS when the user has no working device, or after 4 failed push attempts.
- **Auto-release reminder:** a Seeker who hasn't confirmed gets a second warning 24 hours before release.

To enable real push, create a Firebase project, download a service account key, and set `FCM_PROJECT_ID` and `FCM_CREDENTIALS_FILE`.

To check those settings against real Firebase, run this with both variables set. It sends to a made-up token, so no device receives anything:

```powershell
$env:FCM_LIVE_TEST = "1"
go test ./internal/notify/ -run TestFCMLive -v
```

## SMS

Set `SPARROW_TOKEN` and `SPARROW_FROM` to send through Sparrow SMS. Without them, messages and login codes are only written to the log. On startup the server logs the remaining credit balance.

Sparrow's docs show `http://`, but this client uses `https://` to protect the token and login codes. Sparrow checks the caller's IP address (error 1001), so your server's IP may need approval on your Sparrow account.

To check against the real API without sending an SMS or spending credits:

```powershell
$env:SPARROW_LIVE_TEST = "1"
go test ./internal/sms/ -run TestSparrowLive -v
```

## Design notes

- **MongoDB replaces the spec's PostGIS and relational schema.** Locations use `2dsphere` indexes, and foreign keys are enforced in code.
- **Money is integer paisa** rather than the spec's `DECIMAL`, so rounding cannot occur.
- **The ledger is one row per leg.** Legs in a `group_key` sum to zero, and a unique index on `(group_key, leg)` stops a posting being applied twice.
- **Each job has its own escrow account**, `escrow:<jobID>`.
- **Radius service areas are stored as 32-sided polygons**, so one query matches both area types. The polygon sits slightly inside the true circle.
- **Providers have `category_ids`**, which the spec does not list but matching needs.

## Not built yet

- eSewa and Khalti top-ups, and automatic payouts (admins send withdrawals by hand)
- WebSockets for live bids and chat
- Free-text request parsing (clients send `category_id` directly)
- Google and Apple sign-in
- Tagging cancellations `VALID` or `INVALID`, the three-strike penalties and broadcast de-prioritization

The server refuses to start unless `APP_ENV=development`, because the stubs above are unsafe in production.
