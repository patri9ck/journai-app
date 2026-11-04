# Journai App

To clone and run locally:

```bash
git clone https://github.com/patri9ck/journai-app.git
cd journai-app
flutter pub get
flutter gen-l10n
cp config.dev.json config.json  # fill in your values
flutter run --dart-define-from-file=config.json
```

`flutter gen-l10n` generates the `lib/messages/app_localizations*.dart` files from the ARB sources. These generated files are not committed - run the command whenever you add or change strings in `lib/messages/*.arb`.

To build a release AAB for Google Play:

```bash
flutter build appbundle --release --dart-define-from-file=config.json
```

To upload to Google Play:

```bash
bundle install
bundle exec fastlane google_play_store json_key:key.json track:alpha aab:true
```

## License

Copyright (C) 2026 Patrick Zwick

Journai is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. See [COPYING](COPYING) for the full text.

## Name and Logo

The license covers the source code only. The name "Journai" and the Journai logo are not licensed under the GPL and may not be used for forks or other apps without permission. If you publish a modified version, please give it a different name and logo.

## Contributing and Security

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to contribute, including the Contributor License Agreement, and [SECURITY.md](SECURITY.md) for how to report security issues.

