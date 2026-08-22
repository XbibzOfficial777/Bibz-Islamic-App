# Bibz Islamic App

**Bibz Islamic** is an offline-first Quran application built with Flutter. The Android package identifier is `com.all.bibz`. The app reads locally cached, validated surah datasets first and only contacts the Bibz Islamic API when the requested surah is not available locally.

> **Current baseline:** this repository contains the first buildable application foundation: 114-surah catalog, verified surah API integration, Quran integrity validation, local persistence for opened surahs/bookmarks/last-read state, reader UI, Arabic/transliteration/Indonesian translation display, local-first search with online fallback, copy, and bookmark flows.

## Repository and release links

The public repository is [XbibzOfficial777/Bibz-Islamic-App](https://github.com/XbibzOfficial777/Bibz-Islamic-App). GitHub normalizes repository names to URL-safe slugs, so the repository slug is `Bibz-Islamic-App` while the application/repository display name is **Bibz Islamic App**.

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

The workflow uses `subosito/flutter-action@v2`, `actions/checkout@v5`, `actions/setup-java@v5`, `actions/upload-artifact@v4`, `actions/download-artifact@v8`, and `softprops/action-gh-release@v3`.

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

The client validates the response envelope, surah number, expected ayah count, ayah ordering, duplicate-free sequence, Arabic text, and Indonesian translation before caching. API descriptions are sanitized before display because the observed API response contains HTML tags.

## GitHub Actions

The workflow at `.github/workflows/android-release.yml` runs on pull requests, pushes to `main`, version tags matching `v*`, and manual dispatch. It first runs formatting, static analysis, and tests. A successful build then creates four APK assets:

| Asset | Intended devices |
|---|---|
| `bibz-islamic-armv7-release.apk` | 32-bit ARM devices (`armeabi-v7a`) |
| `bibz-islamic-arm64-release.apk` | 64-bit ARM devices (`arm64-v8a`) |
| `bibz-islamic-x86_64-release.apk` | x86_64 Android devices/emulators |
| `bibz-islamic-universal-release.apk` | Universal APK containing all supported ABIs |

The workflow also creates `SHA256SUMS.txt`. All files are uploaded as an immutable workflow artifact on every successful main/tag build. A GitHub Release is published automatically only when a version tag is pushed.

To publish a release:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The release job requires the repository’s automatic `GITHUB_TOKEN` to have `contents: write`, which is declared in the workflow. No long-lived personal token is stored in the repository.

## Important scope notes

The verified Bibz API currently returns a fixed Alafasy audio URL in the observed Quran response and does not expose a verified dedicated reciter endpoint. The repository therefore does not present a fake multi-Qari selector. Audio download, background playback, and reciter selection must be added only after an approved and verified audio contract is available.

The full workflow specification remains in the supplied `Bibz_Islamic_Workflow.md` reference outside this repository. The implementation must continue to follow its atomic data rule: a dataset is either validated and committed or treated as unavailable; partially downloaded data must never be reported as completed.

## References

1. [Flutter release notes](https://docs.flutter.dev/release/release-notes)
2. [Flutter 3.47.0 release notes](https://docs.flutter.dev/release/release-notes/release-notes-3.47.0)
3. [Android Gradle Plugin 9.3.0 release notes](https://developer.android.com/build/releases/agp-9-3-0-release-notes)
4. [Flutter GitHub Action](https://github.com/subosito/flutter-action)
5. [GitHub upload-artifact action](https://github.com/actions/upload-artifact)
6. [GitHub download-artifact action](https://github.com/actions/download-artifact)
7. [GitHub release action](https://github.com/softprops/action-gh-release/releases)
