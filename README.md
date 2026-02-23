# givelocally_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.



```bash


# For iOS (after Xcode setup)
flutter run -d ios

# For Android (after Android Studio setup)
flutter run -d android

```

### Set up 

```bash 




dart pub global activate flutterfire_cli


flutterfire --version


flutterfire configure


flutter pub add firebase_core firebase_auth cloud_firestore cloud_functions firebase_storage


# Clean build
flutter clean

# Get dependencies
flutter pub get

# Reinstall pods
cd ios
pod install
cd ..

# Run again
flutter run




# pubspec.yml : add dependecies and do following command
flutter pub get
```


### Run 
```bash

# Open iOS Simulator
open -a Simulator

# Wait for simulator to start, then run:
flutter run


```



### Project struture 

```bash 

lib/
├── main.dart                    ← App entry point
├── firebase_options.dart        ← Auto-generated
├── screens/
│   ├── auth/
│   │   ├── splash_screen.dart      ← WF-01 (part 1)
│   │   ├── phone_login_screen.dart ← WF-01 (part 2)
│   │   ├── otp_screen.dart         ← WF-02
│   │   └── profile_setup_screen.dart ← WF-03
│   ├── home/
│   └── profile/
├── services/
│   └── auth_service.dart        ← Firebase Auth logic
├── models/
│   └── user_model.dart          ← User data structure
├── widgets/
│   └── custom_button.dart       ← Reusable button
└── utils/
    └── constants.dart           ← Colors, strings, etc.


```
