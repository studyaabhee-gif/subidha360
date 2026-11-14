# Putting Subidha360 online

This folder runs the website and API on one Linux server with Docker. MongoDB
stays on Atlas and Redis on Upstash, so the server holds no data and can be
replaced in minutes.

```
visitor ──HTTPS──> Caddy ──/v1──> API ──> Atlas (MongoDB)
                     │                └─> Upstash (Redis)
                     └── website files (Flutter web build)
```

## Before you start

You need to buy or set up:

1. **A domain**, such as `subidha360.com`, from any registrar. `.com.np`
   domains are free for Nepali companies through Mercantile, but need company
   papers.
2. **A Linux server** with Docker: 2 GB of memory is enough to start. Pick a
   region close to Nepal, such as Mumbai or Singapore, so pages load fast.
3. **A paid Atlas tier.** The free tier has no backups. A paid cluster gives
   daily snapshots and point-in-time restore, in the same region as the server.
4. **Uptime alerts**: any free uptime checker that calls
   `https://YOUR-DOMAIN/healthz` every minute and emails or texts you when it
   fails.

## First deploy

1. Point the domain's `A` record (and `www`) at the server's IP address.
2. On the server, install Docker and copy this repository there.
3. Build the website on any machine with Flutter, then copy `mobile/build/web`
   to the same place on the server:
   ```bash
   cd mobile
   flutter build web --release --dart-define=API_BASE_URL=https://YOUR-DOMAIN
   ```
4. In `deploy/`, copy `.env.example` to `.env` and fill it in. Generate the
   JWT secret with `openssl rand -base64 48`.
5. Add the server's IP address to Atlas: Security > Database & Network Access
   > IP Access List.
6. Start everything:
   ```bash
   cd deploy
   docker compose up -d --build
   ```
   Caddy fetches the HTTPS certificate on its own within a minute.
7. Make yourself an admin:
   ```bash
   docker compose exec api /app/admin -phone +9779812345678
   ```

## Updating

```bash
git pull
(cd ../mobile && flutter build web --release --dart-define=API_BASE_URL=https://YOUR-DOMAIN)
docker compose up -d --build
```

The API stops gracefully, finishing requests already in progress.

## Backups

Atlas paid tiers back up on their own; turn on daily snapshots with at least 7
days kept. On top of that, take a copy you control, for example weekly:

```bash
docker compose run --rm -v /var/backups/subidha360:/backups api \
  /app/backup -out /backups/$(date +%F)
```

Each backup holds names, phone numbers and identity documents. Encrypt the
folder, keep a copy off the server, and delete copies older than your privacy
policy allows.

**Test a restore** every month, into a separate database, so you know backups
work before you need one:

```bash
docker compose run --rm -v /var/backups/subidha360:/backups api \
  /app/backup -restore /backups/2026-11-13 -db subidha360_restore_test
```

## Errors and monitoring

- Every response carries an `X-Request-ID`. Each request is logged as one JSON
  line with that ID, its status and its time taken, so a person's complaint
  can be traced to the exact log line.
- Server errors are logged at level `ERROR`, with a stack trace for crashes.
  A crash in one request never stops the server.
- See recent errors: `docker compose logs api | grep '"level":"ERROR"'`.
- For alerts on errors, send these logs to a hosted log service; most read
  Docker logs directly. Until then, check the logs daily.

## Not safe to launch publicly yet

The server refuses to start outside development mode until real payments
replace the test top-up. Run this setup as a private test with invited people
until then. Caddy already blocks the test top-up from the internet.
