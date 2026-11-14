# Subidha360 app

One Flutter app for both Seekers and Providers. Users switch sides from the Profile tab, and the choice is stored on the device.

## Run it

Start the backend first (see `../backend/README.md`), then:

```powershell
flutter pub get
.\run.ps1                    # in a browser, at http://localhost:5050
flutter run                  # on a connected phone or emulator
```

`flutter run -d edge` fails with Edge 157 ("Failed to launch browser"), so
`run.ps1` serves the app on port 5050 and opens the page when it's ready. If
scripts are blocked, use `powershell -ExecutionPolicy Bypass -File .\run.ps1`.

The app calls `http://10.0.2.2:8080` on the Android emulator and `http://localhost:8080` elsewhere. For a real phone, or a hosted server, pass your own address:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8080
```

In development, login codes appear in the backend's log until Sparrow SMS is configured.

## Generated code

Models and providers use `build_runner`. Run this after changing any `@freezed` or `@riverpod` code:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

Add `watch` in place of `build` to regenerate as you edit.

## Test

```powershell
flutter analyze
flutter test
```

To see every screen without running the app, render them to `test/previews/out` in light and dark. This also fails if any screen overflows on a small phone with large text:

```powershell
$env:PREVIEW = "1"
flutter test test/previews --update-goldens
```

`test/live_api_test.dart` runs a whole job through the real data layer. It's skipped unless a development server is running and these are set:

```powershell
$env:LIVE_API_URL = "http://127.0.0.1:8080"
$env:LIVE_API_LOG = "path\to\server.log"   # where OTP codes can be read
flutter test test/live_api_test.dart
```

## Layout

| Path | Purpose |
| --- | --- |
| `lib/core` | Shared code: config, networking, storage, router, theme, extensions, global providers |
| `lib/core/theme` | Design tokens: colours, type, spacing, and semantic tones |
| `lib/core/widgets` | Shared UI: cards, pills, banners, empty and loading states, sheets |
| `lib/features/auth` | Login, session, provider setup |
| `lib/features/home` | Tabs, profile, Seeker/Provider switch |
| `lib/features/jobs` | Posting, feed, bids, job lifecycle |
| `lib/features/wallet` | Balance and history |
| `lib/features/notifications` | Inbox |

Each feature keeps its own `data`, `domain`, `presentation` and `providers` folders as needed.

## Website

The web build is the public site as well as the app. Visitors can browse the landing page, services, guarantee and provider pages without an account. Logging in returns them to what they were booking.

Addresses are clean (`/services`, not `/#/services`), so a host must serve `index.html` for unknown paths. Flutter web draws to a canvas, so search engines see little of the page content. If search ranking matters, a separate HTML landing page is the usual fix.

## Photos

`assets/photos/` holds two kinds of photo:

- **Providers in Subidha360 uniform** (`cat_*.jpg`, `hero_home.jpg`,
  `band_team.jpg`, `auth_provider.jpg`, `provider_tools.jpg`): generated
  illustrations made from `docs/photo-brief.md`. Full-size originals are in
  `design/photos-original/`. They show how the service works. Never use them as
  a named provider's profile photo, next to a review, or as any real person.
- **Places in Nepal** (cities, Patan, the Himalaya band): openly licensed
  photos from Wikimedia Commons. Their licences require credit, so the
  `/photo-credits` page and its footer link must stay while they are used.
  `lib/features/info/domain/photo_credits.dart` lists each author, licence and
  source. Update it whenever one changes.

The link-preview image is `web/icons/share.jpg`, and the Google Play feature
graphic is `docs/store/play_feature.jpg`.

## Languages

The app runs in English and Nepali. Wrap any new visible text in `tr()`:
`tr('Post a job')`, or `tr('Asking {0}', [name])` for values. Then add the
Nepali to `lib/core/l10n/nepali.dart`. Text from the catalogue goes in
`nepali_catalog.dart`. Missing text falls back to English, and
`test/l10n_test.dart` fails until it has a translation.

Keep API values, such as review tags, in English and translate them only where
they are shown.

Nepali uses Noto Sans Devanagari (SIL Open Font License), because Plus Jakarta
Sans has no Devanagari letters. The translations still need review by a native
speaker.

## Maps

Maps use OpenStreetMap's public tile server, which needs no key but is not meant
for heavy commercial traffic. Before launch, point `urlTemplate` in
`lib/features/jobs/presentation/job_map.dart` at a paid tile provider. The
OpenStreetMap credit must stay on every map.

Providers share their location only while the job screen is open. Sharing in the
background on phones needs extra permissions and isn't built.

## Not built yet

- Push notifications (needs `firebase_messaging` and `flutterfire configure`)
- Live bid updates over WebSockets (pull down to refresh; chat polls every 5 seconds)
- Voice job requests
- Real wallet top-ups (debug builds have a test button)
- Deleting an account from inside the app (Apple requires it; people ask through Help today)
- A branded splash screen on phones (the web page shows a spinner)

## Logo and icons

The master logo is `assets/brand/logo.svg`. The app icons for Android, iOS
and the web were rendered from it; if the logo changes, render them again at
every size listed in `ios/Runner/Assets.xcassets/AppIcon.appiconset`,
`android/app/src/main/res/mipmap-*` and `web/icons`.

## Legal pages

`lib/features/legal/legal_text.dart` holds the draft terms, privacy and refund
policies. They need a Nepali lawyer's review before launch. When a change
matters, raise `termsVersion`: logging in records which version a person
agreed to.
