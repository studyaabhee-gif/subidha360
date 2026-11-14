# Releasing to Google Play and the App Store

The app is ready to be built for both stores: name, icons, app ID
(`com.subidha360.app`), permission texts and release signing are set. What is
left needs your accounts, a Mac for iOS, and a finished launch checklist.

## Before any store release

Do not publish until these are done; both stores reject or remove apps that
take payments or personal documents without them.

- [ ] Real payments connected (the test top-up must not be in a store build;
      it is already hidden in release builds and blocked by the server proxy).
- [ ] Terms, privacy and refund pages reviewed by a Nepali lawyer, and the
      `[square brackets]` filled in.
- [ ] Company name, registration number and PAN entered in Admin > Services >
      Helpline and company.
- [ ] Sparrow SMS connected, so login codes are texted.
- [ ] The server online at its final address (see `deploy/README.md`), and the
      app built with `--dart-define=API_BASE_URL=https://YOUR-DOMAIN`.
- [ ] Your own photos in place of stock photos of recognisable people.

## Android (Google Play)

You need: a Google Play developer account in the company's name, and Android
Studio's setup finished on this PC (`flutter doctor` must show no Android
problems: install the command-line tools and run
`flutter doctor --android-licenses`).

1. **Make the upload key, once.** Keep the file and passwords somewhere safe
   and backed up: losing them means asking Google to reset the key.
   ```powershell
   keytool -genkey -v -keystore $env:USERPROFILE\subidha360-upload.jks `
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Create `mobile/android/key.properties` (git ignores it):
   ```
   storePassword=...
   keyPassword=...
   keyAlias=upload
   storeFile=C:/Users/YOU/subidha360-upload.jks
   ```
3. Raise the build number after `+` in `pubspec.yaml` for every upload, then:
   ```powershell
   cd mobile
   flutter build appbundle --release --dart-define=API_BASE_URL=https://YOUR-DOMAIN
   ```
   Upload `build/app/outputs/bundle/release/app-release.aab`.
4. Start with **internal testing**, then closed testing with real providers,
   before production. New personal developer accounts must run a closed test
   with testers for some days before production is allowed.

### Play Console answers

**Data safety**, based on what the app actually does:

| Data | Collected | Shared | Why | Optional |
| --- | --- | --- | --- | --- |
| Phone number | Yes | No | Account, login codes | No |
| Name | Yes | With the other person on a job | Account | No |
| Precise location | Yes | With the provider you choose | Job address and pin; provider position while on a job | No for jobs |
| Photos | Yes | With providers on the job, or customers (past work) | Job photos, gallery | Yes |
| Government ID (provider identity check) | Yes | No | Fraud prevention | Yes |
| Messages | Yes | With the other person on the job | Chat, support | No |
| Financial info (bank or eWallet for withdrawals) | Yes | No | Payouts | Yes |
| App interactions | No | | Page views are counted with no identifier | |

Data is encrypted in transit, and people can ask for deletion through Help.

**Content rating**: no violence, gambling or adult content; users can chat
with each other, which the questionnaire asks about.

**Target audience**: 18 and over.

## iOS (App Store)

You need: an Apple Developer Program membership in the company's name, and a
Mac with Xcode. Flutter cannot build iOS apps on Windows.

1. On the Mac, open `mobile/ios/Runner.xcworkspace`, choose your team under
   Signing & Capabilities, and keep the bundle ID `com.subidha360.app`.
2. Build and upload:
   ```bash
   flutter build ipa --release --dart-define=API_BASE_URL=https://YOUR-DOMAIN
   ```
   then send `build/ios/ipa/*.ipa` with Apple's Transporter app.
3. Test with TestFlight before submitting for review.
4. Apple requires a way to **delete an account from inside the app**. That is
   not built yet; today people ask through Help. Build it before submitting.
5. The App Privacy answers match the Play table above.

## Store listing text

**Name**: Subidha360: Home Services

**Short description** (80 characters):
Fair quotes from local experts. Pay only when the job is done.

**Full description**:

> Need a plumber, electrician, cleaner or carpenter in Nepal? Describe the
> problem, add a photo, and nearby providers send you their price. Compare
> prices, ratings and verified badges, then choose.
>
> Your payment is held safely and released only when you confirm the work is
> done. If something goes wrong, raise a dispute and our team decides fairly.
> Every job has a 30-day guarantee.
>
> Providers: get jobs near you, set your own price and hours, show your past
> work, and withdraw your earnings to your bank or eSewa.
>
> Available in English and Nepali.

**Nepali** (needs a native speaker's review):

> प्लम्बर, इलेक्ट्रिसियन, सफाइकर्मी वा सिकर्मी चाहियो? समस्या लेख्नुहोस्, फोटो
> थप्नुहोस्, र नजिकका सेवा प्रदायकले आफ्नो मूल्य पठाउँछन्। मूल्य, रेटिङ र प्रमाणित
> ब्याज तुलना गरेर छान्नुहोस्। काम सकिएको पुष्टि गरेपछि मात्र भुक्तानी जान्छ।

**Screenshots** (phone, at least 4): the home page, comparing bids, the job
page with the payment on hold, and the provider earnings page. Use the preview
renders in `mobile/test/previews/out` as a guide, but take the final ones from
a real phone with real-looking, non-personal data.
