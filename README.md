# Progress Meter

The student Progress Meter Flutter application is in **[`apps/progress_meter/`](apps/progress_meter/)**. Version 1.8.0 includes academic and career progress, AI-only assessments, Testing Lab, goals, researched benchmark paths, routines, daily tasks, document imports, and personal AI provider connections.

The existing NestJS backend remains at the repository root (`src/`, `package.json`, and database migrations). It is a separate codebase. The Flutter app currently uses local device storage, direct personal AI connections, or its own optional AI gateway in `apps/progress_meter/backend/`; it is not connected to the root NestJS service.

## Run the Flutter app

Use Flutter with Dart 3.13 or newer within Dart 3.x. macOS development also requires Xcode and CocoaPods.

```sh
cd apps/progress_meter
flutter pub get
flutter run -d macos
```

For iPhone setup, feature details, and current platform limits, see the [app README](apps/progress_meter/README.md). Android runner files are included; Android device behavior has not been verified.

The app also includes a small standalone C helper under [`apps/progress_meter/native/`](apps/progress_meter/native/). It calculates deterministic benchmark roadmap readiness from milestone completion fractions and has a C ABI suitable for future Dart FFI integration. It does not judge the four AI-only progress dimensions. Run `make test` in that directory to verify it.

## Configure AI

In the app, open **Settings → Your AI model → Connect my AI** and select your provider, model ID, and API key. Personal keys stay in memory for the current app session and are excluded from saved data and backups.

To use the app's optional Node.js AI gateway instead, follow its [backend setup instructions](apps/progress_meter/backend/README.md). Create a local `.env` from `.env.example`; API keys and local environment files are excluded from version control.

## Verify the app

```sh
cd apps/progress_meter
flutter analyze
flutter test
cd backend
npm test
```

The 1.8.0 release passed 233 Flutter tests and 53 AI gateway tests, plus a live OpenAI check with synthetic data. See the [architecture notes](apps/progress_meter/docs/ARCHITECTURE.md) for implementation details.
