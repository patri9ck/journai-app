# Journai App

Guidance for coding agents working in this repository.

## Commands

```bash
flutter pub get                                         # install dependencies
flutter gen-l10n                                        # generate localizations from the ARB files
flutter analyze                                         # static analysis
flutter test                                            # unit and widget tests
flutter run --dart-define-from-file=config.json         # run on a device or emulator
flutter test integration_test/app_test.dart             # integration test on a device or emulator
```

Copy `config.dev.json` to `config.json` before running the app.

## Structure

```
lib/
  main.dart     app entry point and theme
  messages/     ARB files and generated localizations
  model/        data models
  service/      business logic and network access
  util/         small helpers
  widget/       pages, sheets and shared widgets
```

## Conventions

**Localization.** All user-facing text lives in `lib/messages/messages_*.arb`, one file per language (12 in total). Add every new string to all of them and run `flutter gen-l10n`. Use `AppLocalizations.of(context)!` to read them.

**Theme.** Colors and fonts are defined in `main.dart`. Headings use Instrument Serif, body text uses Inter. Both fonts are bundled in `assets/google_fonts/` and never loaded at runtime.

**Backend.** The base URL comes from `BASE_URL` in `config.json` and is read in `lib/service/services.dart`. All requests go through `RequestService` to `api/v1/`.

**Data.** Everything a user stores is a `Data` entry with a `feature` and `fields`. It is end-to-end encrypted by `DataService`. Models such as `Trip` or `JournalEntry` convert from and to `Data`. Save with `ensureAndSave`.

**Results.** `Result<T>` is either `Success<T>` or `Failure<T>`. Call `show(localizations)` on a failure to display its localized message.

**Limits.** Plan limits come from `limitsService`. Open the paywall with `showPaywall(context)`.

**Sharing.** Share any widget as an image with `shareWidgetAsImage`.

## Code Style

**Braces.** Every `if` body goes on its own line inside braces.

```dart
if (result == null) {
  return;
}
```

**Blank lines.** Every logical step gets its own paragraph: after declarations, around guard checks and before every `return`.

```dart
final result = await loginService.verify(code);

if (result is Failure<Login>) {
  result.show(localizations);

  return;
}

Navigator.of(context).pop();
```

**Names.** Never abbreviate: `userId`, not `uid`, and `localizations`, not `l10n`.

**No comments.** Do not add code comments.

**No dead code.** Remove any import, function or variable your change leaves unused.

**License header.** Every new source file starts with:

```dart
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick
```
