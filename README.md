# QuranX

**QuranX** is an offline-first Quran application built with Flutter. The Android package identifier remains `com.all.bibz` so existing installations can receive updates, while the installable app label and release APK filenames are **QuranX**. The app reads locally cached, validated surah datasets first and contacts the Bibz Islamic API only when the requested surah is not available locally.

> **Current baseline:** the repository contains a buildable application foundation with a 114-surah catalog, verified surah API integration, Quran integrity validation, local persistence for opened surahs/bookmarks/last-read state, reader UI, Arabic/transliteration/Indonesian translation display, local-first search with online fallback, copy, bookmark, and persisted Light/Dark/System theme selection.

## Repository and release links

The public repository is [XbibzOfficial777/Bibz-Islamic-App](https://github.com/XbibzOfficial777/Bibz-Islamic-App). GitHub normalizes repository names to URL-safe slugs, so the repository slug is `Bibz-Islamic-App` while the app label is **QuranX**.

## Toolchain

The build is pinned to the following stable and mutually compatible versions:

| Component | Version | Reason |
|---|---:|---|
| Flutter | 3.47.0 stable | Latest stable release identified in the official Flutter release index on 22 August 2026. |
| Dart | 3.13.0 | Bundled with Flutter 3.47.0. |
| Android Gradle Plugin | 9.3.0 | Current stable AGP line researched for this build. |
| Gradle wrapper | 9.5.0 | Official AGP 9.3 compatibility requirement/default. |
| Java | 17 | Official AGP 9.3 minimum/default. |
| Android Build Tools | 36.0.0 | Official AGP 9.3 default. |
| Release runner | `ubuntu-24.04` | Reproducible GitHub-hosted Linux runner. |

The workflow uses `subosito/flutter-action@v2`, `actions/checkout@v5`, `actions/setup-java@v5`, `actions/upload-artifact@v7`, `actions/download-artifact@v8`, and `softprops/action-gh-release@v3`.

## Local development

Install Flutter 3.47.0, then run:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter run
```

The API contract currently used by the app is:

```text
Base: https://bibzislamicc.vercel.app/api/v1
Surah: GET /quran/surah?surah=<1..114>
Search: GET /quran/search?q=<query>
```

The Android manifest explicitly includes `android.permission.INTERNET`, which is required for the released app to reach the HTTPS API. The client validates the response envelope, surah number, expected ayah count, ayah ordering, duplicate-free sequence, Arabic text, and Indonesian translation before caching. API descriptions are sanitized before display because the observed API response contains HTML tags.

## Theme selection

The Settings screen provides three choices: **Sistem**, which follows the device preference; **Light**, which always uses the light palette; and **Dark**, which always uses the dark palette. The selection is persisted locally using `SharedPreferences` and is applied through Flutter’s root `ThemeMode`.

## GitHub Actions and release APKs

The workflow at `.github/workflows/android-release.yml` runs on pull requests, pushes to `main`, version tags matching `v*`, and manual dispatch. It first runs formatting, static analysis, and tests. A successful release build creates four QuranX APK assets:

| Asset | Intended devices |
|---|---|
| `quranx-armv7-release.apk` | 32-bit ARM devices (`armeabi-v7a`) |
| `quranx-arm64-release.apk` | 64-bit ARM devices (`arm64-v8a`) |
| `quranx-x86_64-release.apk` | x86_64 Android devices/emulators |
| `quranx-universal-release.apk` | Universal APK containing all supported ABIs |

Each APK is explicitly signed with **APK Signature Scheme V2, V3, and V4** using `apksigner`. V4 produces a companion `.idsig` file where the Android Build Tools emit it; the workflow requires all three ABI split `.idsig` files and includes any emitted universal `.idsig` alongside `SHA256SUMS.txt` in the workflow artifact and GitHub Release. This preserves the V4 artifact behavior without failing the release solely because the current Build Tools do not emit a universal-APK companion file.

### Required encrypted repository secrets

The private keystore must never be committed. The release workflow expects these encrypted GitHub Actions secrets:

| Secret | Value |
|---|---|
| `KEYSTORE_BASE64` | Base64 contents of the `.jks` file |
| `KEYSTORE_PASSWORD` | Keystore password |
| `KEY_PASSWORD` | Private-key password |
| `KEY_ALIAS` | Keystore alias |

The uploaded keystore was not committed to the repository. The current GitHub integration token returned HTTP 403 when attempting to write Actions secrets, so the four secrets still need to be added by an account/session with repository Actions-secret write permission. The workflow intentionally fails early when any required secret is missing rather than silently publishing debug-key APKs.

For a local shell with suitable repository administration permission, the safe setup pattern is:

```bash
REPO=XbibzOfficial777/Bibz-Islamic-App
gh secret set KEYSTORE_BASE64 --repo "$REPO" < <(base64 -w0 path/to/xbibzofcv1.jks)
printf '%s' '<keystore-password>' | gh secret set KEYSTORE_PASSWORD --repo "$REPO"
printf '%s' '<private-key-password>' | gh secret set KEY_PASSWORD --repo "$REPO"
printf '%s' '<key-alias>' | gh secret set KEY_ALIAS --repo "$REPO"
```

Do not paste passwords into shell history on a shared machine. Android’s guidance also recommends separating a Play App Signing key from an upload key when distributing through Google Play; the keystore used by this repository should be treated as sensitive signing material.[1]

To publish a signed QuranX release after the secrets are present:

```bash
git tag v1.0.2
git push origin v1.0.2
```

The release job requires the repository’s automatic `GITHUB_TOKEN` to have `contents: write`, which is declared in the workflow. No long-lived personal token is stored in the repository.

## Important scope notes

The verified Bibz API currently returns a fixed Alafasy audio URL in the observed Quran response and does not expose a verified dedicated reciter endpoint. The repository therefore does not present a fake multi-Qari selector. Audio download, background playback, and reciter selection must be added only after an approved and verified audio contract is available.

The implementation follows the atomic data rule: a dataset is either validated and committed or treated as unavailable; partially downloaded data must never be reported as completed.

## References

1. [Sign your app | Android Developers](https://developer.android.com/studio/publish/app-signing)
2. [apksigner | Android Developers](https://developer.android.com/tools/apksigner)
3. [Flutter release notes](https://docs.flutter.dev/release/release-notes)
4. [Flutter 3.47.0 release notes](https://docs.flutter.dev/release/release-notes/release-notes-3.47.0)
5. [Android Gradle Plugin 9.3.0 release notes](https://developer.android.com/build/releases/agp-9-3-0-release-notes)
6. [Flutter GitHub Action](https://github.com/subosito/flutter-action)
7. [GitHub upload-artifact action](https://github.com/actions/upload-artifact)
8. [GitHub download-artifact action](https://github.com/actions/download-artifact)
9. [GitHub release action](https://github.com/softprops/action-gh-release/releases)

## Production feature implementation

The current branch now includes explicit handling for surahs that are not loaded. The reader shows a non-blocking loading state, a clear unavailable state, a retry action, and a full selectable diagnostic detail. Flutter framework errors and uncaught Dart-zone errors are retained in a bounded local diagnostic history, which is visible from the hamburger menu and can be copied as plain text.

The Settings surface includes persisted theme, accent color, interface font, text scale, translation/transliteration visibility, and Tajwid Mode controls. Color tokens are derived from the selected Material 3 seed color rather than remaining fixed to the original green palette.

The reader includes per-ayah audio playback. It prefers a previously downloaded local surah audio file and otherwise streams the API-provided HTTPS ayah URL. The hamburger menu and Settings tab both open the selective offline download screen, where users can select surahs and choose Quran data or full-surah audio. Audio is downloaded as a stream to a temporary `.part` file, checked for a valid audio content type and minimum size, and atomically renamed only after validation. Prior valid data is preserved when a later download fails.

Search now has separate **Surah** and **Juz** modes. Surah search covers the canonical catalog. Juz search uses explicit API Juz fields when available and a canonical boundary fallback over locally validated ayahs when the API omits those fields; it reports an empty/unavailable state when the required local surah data has not been downloaded. Tajwid Mode calls the verified `/quran/tajwid` endpoint and labels its result as the API’s available analysis. The currently observed endpoint returns generic basmalah analysis and ignores Surah/Ayah selectors, so the app does not claim per-ayah rule highlighting that the API does not provide.

The repository’s automated coverage now includes validator rejection, appearance persistence, Juz indexing, durable diagnostics, and the QuranX home smoke test. The hosted Android workflow remains the authoritative APK build because the local sandbox does not include an Android SDK; the CI runner installs the required Android components and continues to publish split ABI and universal outputs.

### Production limitations that remain explicit

The current API does not expose a verified reciter catalog, so QuranX uses the audio URLs returned by the API and does not display a fake Qari selector. Background media notification, lock-screen controls, pause/resume range downloads, local database migrations, and full-device integration tests require additional platform work beyond the current verified scope. These are intentionally not represented as completed functionality.

The `/quran/juz` route did not produce a usable response during verification. Juz search is therefore local-data-driven and must not be presented as a server-backed Juz index until the API provides a validated contract.

## Error reporting and GitHub issues

Every full error surface presents two primary actions: **Copy Full Error Log** and **Report Issue**. The first copies the complete selectable diagnostic text, including timestamp, context, exception type, message, and stack trace. The second opens the repository’s GitHub `issues/new` page with a prefilled bug title, `bug` label, and encoded diagnostic body.

Each captured crash or error is also written as a separate UTF-8 TXT file with a collision-safe timestamped name such as `QuranX_Log_20260822_134500_123001.txt`. QuranX creates the log directory automatically when the Android storage API allows it. On Android 9 and older, the preferred location is `/sdcard/QuranX/Logs`. On Android 10 and newer, scoped storage prevents an app from reliably creating an arbitrary root-level directory, so QuranX uses the user-visible Downloads collection at `Download/QuranX/Logs`; if that storage operation is unavailable, it falls back to the app support directory and keeps the diagnostic history in `SharedPreferences` as a recovery copy. The Diagnostics screen displays the actual resolved location instead of claiming that a hard-coded path always exists.

The Diagnostics screen lists saved TXT files and includes **refresh**, **delete one**, and **delete all** controls. All destructive deletion actions require an explicit confirmation where appropriate. Selecting **Copy Full Error Log** copies the complete detail and then removes the associated TXT log when the copy operation succeeds. Selecting **Report Issue** does not delete immediately merely because GitHub opened: QuranX first asks the user to confirm that the issue was submitted, preventing accidental loss when the form is abandoned. If the user chooses to keep it, the file remains available for another attempt.

The Report Issue action deliberately does not embed a GitHub personal access token in the APK. A mobile binary containing such a token could expose repository write access. The safe production behavior is therefore a prefilled issue form that the authenticated repository owner reviews and submits. Fully silent issue creation would require a backend or GitHub App with a server-side secret and rate limiting.

The attached field report showed duplicate entries for the same audio failure: `AudioController.playUrl` recorded `PlayerInterruptedException`, then `_ReaderScreenState._playAyah` recorded the same exception again. QuranX now records the user-facing playback failure once, prevents overlapping player loads, stops the previous source before loading a new one, and still retains the full stack trace for the report flow.

The v1.1.1 CI build exposed an Android Lint parser failure inside `url_launcher_android` 6.3.32 (`JavaDocParser`/`List.removeLast`). This was a tooling/library lint crash, not an application source error. QuranX pins `url_launcher_android` to 6.3.31 until the newer patch is compatible with the pinned AGP/runner toolchain; the pin is covered by CI analysis and Android build verification.


## QuranX v1.3 feature foundation

QuranX now keeps Surah and Juz search synchronized with the current query. Results update locally while typing, network searches are debounced, and stale responses are ignored when the query or mode has changed. The existing API-backed Surah search uses `q`, while Juz search remains local-first because the API does not expose a verified Juz index.

Quran and audio downloads are now owned by an application-scoped `background_downloader` coordinator rather than a screen-scoped HTTP client. Tasks are enqueued with persistent tracking, retries, pause/resume support, progress updates, and Android notification-bar progress. Quran JSON responses are parsed and validated before being saved to local storage. Audio files are size-checked before their path is persisted. Android cannot guarantee survival after a user force-stops the app or an OEM battery manager terminates it; QuranX preserves retryable state and exposes cancellation and retry behavior where the platform permits it.

Completed Quran and audio downloads can be removed from the download manager. Every removal requires an explicit confirmation dialog and removes only the selected asset. A Quran deletion removes the persisted validated Surah record and its downloaded file; audio deletion removes the audio file and its metadata.

Tajwid Mode now presents detected API rule groups using distinct color markers and an accessible text legend. The current QuranX API response does not provide verified per-character ranges, so QuranX does not color arbitrary Arabic letters. The UI states this limitation rather than presenting false character-level Tajwid highlighting.

The same API provides live city and prayer schedule routes. City search uses `GET /api/v1/falak/cities?q=<text>`, and a schedule uses `GET /api/v1/falak/prayer-times?cityId=<id>&date=YYYY-MM-DD`. The schedule parser requires `isLiveDataFromInternet`, matching city ID/date, Kemenag source, and all required time fields. The API can return an astronomical fallback for an invalid city while still setting `success: true`; QuranX rejects that fallback as an invalid selected-city schedule.

The Jadwal Sholat screen can search cities in realtime, display the verified daily schedule, and schedule seven days of named notifications for Subuh, Dzuhur, Ashar, Maghrib, and Isya using timezone-aware Android local notifications. Notifications are scheduled inexactly to avoid claiming exact-alarm privileges that may not be appropriate for every distribution channel, and Android/OEM restrictions may still affect delivery.

The current same API does not advertise or expose a verified adzan/muadzin audio catalog. QuranX therefore does not show fake voice choices and does not download Surah recitations as if they were adzan recordings. Selectable offline adzan voices will be added only when the API provides a real catalog and stable audio URLs, or after an explicit user-approved audio asset source is supplied.
