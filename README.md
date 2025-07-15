# app001

A new Flutter project with firebase and firestore integration for audio call, video call and live message chat features.

## Getting Started

This project is a starting point for a Flutter application that follows the
[simple app state management
tutorial](https://flutter.dev/docs/development/data-and-backend/state-mgmt/simple).

For help getting started with Flutter development, view the
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Assets

The `assets` directory houses images, fonts, and any other files you want to
include with your application.

The `assets/images` directory contains [resolution-aware
images](https://flutter.dev/docs/development/ui/assets-and-images#resolution-aware).

## Localization

This project generates localized messages based on arb files found in
the `lib/src/localization` directory.


### Run Configuration in Android Studio
Add this code in additional run args to run specific flavors

## Release
--flavor dev --dart-define-from-file config/dev.json

## Development
--flavor dev --dart-define-from-file config/dev.json

### To Run App for iOS >>>
flutter run --flavor dev --dart-define-from-file=config/dev.json --release

### To Build App for Android >>>
flutter build apk --flavor dev --dart-define-from-file=config/dev.json --release --split-per-abi

### To Build App for iOS >>>
flutter build ios --flavor dev --dart-define-from-file=config/dev.json --release

### To Build App Bundle for Android >>>
flutter build appbundle --dart-define-from-file config/dev.json --flavor dev

### Project Structure

lib/
├── api/
│ └──
├── models/
│ └──
├── providers/
│ └──
├── screens/
│ └──


To support additional languages, please visit the tutorial on
[Internationalizing Flutter
apps](https://flutter.dev/docs/development/accessibility-and-localization/internationalization)
# app001
